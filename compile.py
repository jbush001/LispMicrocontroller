#!/usr/bin/python
#
# Memory Map:
#
#  [ instructions ]
#  [ global data ]
#  [ free space ]
#  [ stack ]
#
# Each stack frame is (grows down, higher address is on top in this diagram):
#
#  paramn
#  ...
#  param1
#  param0
#  prev base ptr     <---- current base ptr ---
#  return address
#  local 0
#  local 1
#  ...
#

import sys, shlex, copy

TAG_INTEGER = 0		# Make this zero because types default to this when pushed
TAG_CONS = 1
TAG_FUNCTION = 2

OP_NOP = 0
OP_CALL = 1
OP_RETURN = 2
OP_POP = 3
OP_LOAD = 4
OP_STORE = 5
OP_ADD = 6
OP_SUB = 7
OP_REST = 8
OP_GTR = 9
OP_GTE = 10
OP_EQ = 11
OP_NEQ = 12
OP_DUP = 13
OP_GETTAG = 14
OP_SETTAG = 15
OP_AND = 16
OP_OR = 17
OP_XOR = 18
OP_LSHIFT = 19
OP_RSHIFT = 20
OP_GETBP = 21
OP_RESERVE = 24		# High bits indicates this has a parameter
OP_PUSH = 25
OP_GOTO = 26
OP_BFALSE = 27
OP_GETLOCAL = 29
OP_SETLOCAL = 30
OP_CLEANUP = 31

class Symbol:
	LOCAL_VARIABLE = 1
	GLOBAL_VARIABLE = 2
	FUNCTION = 3

	def __init__(self, type):
		self.type = type
		self.index = -1
		self.initialized = False	# For globals
		self.function = None

# Labels are only visible inside the functions they are defined in.
class Label:
	def __init__(self):
		self.defined = False
		self.address = 0

class Function:
	def __init__(self):
		self.localFixups = []
		self.baseAddress = 0
		self.numLocals = 0
		self.instructions = []		# Each entry is a word
		self.referenced = False		# Used to strip dead functions

		# Save a spot for an initial 'reserve' instruction
		self.emitInstruction(OP_RESERVE, 0)

	def generateLabel(self):
		return Label()
		
	def allocateLocal(self):
		index = -(self.numLocals + 2)	# Skip return address and base pointer
		self.numLocals += 1
		return index

	def getProgramAddress(self):
		return len(self.instructions)

	def emitLabel(self, label):
		assert not label.defined
		label.defined = True
		label.address = self.getProgramAddress()

	def emitBranchInstruction(self, op, label):
		self.emitInstruction(op, 0)
		self.localFixups += [( self.getProgramAddress() - 1, label)]

	def emitInstruction(self, op, param = 0):
		if param > 32767 or param < -32768:
			raise Exception('param out of range ' + str(param));
	
		# Convert to two's complement
		if param < 0:
			param = ((-param ^ 0xffff) + 1) & 0xffff

		self.instructions += [ (op << 16) | param]

	def patch(self, offset, value):
		self.instructions[offset] &= ~0xffff
		self.instructions[offset] |= (value & 0xffff)

	def performLocalFixups(self):
		self.instructions[0] = (OP_RESERVE << 16) | (self.numLocals + 1)
		for ip, label in self.localFixups:
			if not label.defined:
				raise Exception('undefined label')

			self.patch(ip, self.baseAddress + label.address)


#
# The parser just converts ASCII data into a a python list that represents
# the structure
#
class Parser:
	def __init__(self):
		self.lexer = None
		self.program = []

	def parseFile(self, filename):
		stream = open(filename, 'r')
		self.lexer = shlex.shlex(stream)
		self.lexer.commenters = ';'
		self.lexer.quotes = '"'
		self.lexer.wordchars += '+<>!@#$%^&*;:.=-_'

		while True:
			expr = self.parseExpr()
			if expr == '':
				break
				
			self.program += [ expr ]
			
		stream.close()

	def parseParenList(self):
		list = []
		while True:
			lookahead = self.lexer.get_token()
			if lookahead == '':
				print 'missing )'
				break
			elif lookahead == ')':
				break
	
			self.lexer.push_token(lookahead)			
			list += [ self.parseExpr() ]
			
		return list
	
	def parseExpr(self):
		token = self.lexer.get_token()
		if token == '':
			return ''
		
		if token == '\'':
			return [ 'quote', self.parseExpr() ]
		elif token == '`':
			return [ 'backquote', self.parseExpr() ]
		elif token == ',':
			return [ 'unquote', self.parseExpr() ]
		elif token == '(':
			return self.parseParenList()
		elif token.isdigit() or (token[0] == '-' and len(token) > 1):
			return int(token)
		else:
			return token
			
	def getProgram(self):
		return self.program

class Compiler:
	def __init__(self):
		# The environment is a stack of lambdas, each of which is a stack of 
		# scopes, each of which is a  dictionary of symbols.  Because closures 
		# are not currently supported, we cannot access variables from the outer 
		# function, but implementing them would simply be a matter of walking up
		# to the next lambda context.
		self.environmentStack = [[{}]]
		self.globals = {}
		self.currentFunction = Function()
		self.functionList = [ 0 ]		# We reserve a spot for 'main'
		self.loopStack = []	# Each entry is ( resultReg, exitLabel )

		# Can be a fixup for:
		#   - A global variable 
		#   - A function pointer
		# Each stores ( function, functionOffset, target )
		self.globalFixups = []	

	def enterScope(self):
		self.environmentStack[-1] += [{}]

	def exitScope(self):
		self.environmentStack[-1].pop()

	def enterLambda(self):
		self.environmentStack += [[{}]]
		self.enterScope()

	def exitLambda(self):
		self.environmentStack.pop()

	# 
	# Lookup a symbol, starting in the current scope and working backward
	# to enclosing scopes.  If the symbol doesn't exist, create one in the global
	# namespace.
	#
	def lookupSymbol(self, name):
		isUpval = False
		for lambdaContext in reversed(self.environmentStack):
			for scope in reversed(lambdaContext):
				if name in scope:
					sym = scope[name]
					if isUpval:
						raise Exception(str(name) + ' is referenced inside a lambda.  Not supported.')
						
					return sym
				
			isUpval = True

		if name in self.globals:
			return self.globals[name]

		# Here is where we could walk back up the environment stack to find 
		# closures if they were supported...

		sym = Symbol(Symbol.GLOBAL_VARIABLE)
		sym.index = len(self.globals)		# Allocate a storage slot for this
		self.globals[name] = sym
		return sym

	#
	# Allocate a new symbol, but make it in the local scope.  Use to create
	# parameters and for (let ...)
	#
	def createLocalVariable(self, name):
		sym = Symbol(Symbol.LOCAL_VARIABLE)
		self.environmentStack[-1][-1][name] = sym
		return sym

	#
	# Top level compile function.  All code not in lambda blocks will be 
	# emitted into an implicitly created dummy function 'main'
	#
	def compile(self, program):
		self.currentFunction = Function()
		self.currentFunction.referenced = True

		# create a built-in variable that indicates where the heap starts
		# (will be patched at the end of compilation with the proper address)
		heapstart = self.lookupSymbol('$heapstart')
		heapstart.initialized = True
		self.currentFunction.emitInstruction(OP_PUSH, 0)
		self.currentFunction.emitInstruction(OP_PUSH, 0)
		self.currentFunction.emitInstruction(OP_STORE);
		self.currentFunction.emitInstruction(OP_POP);

		for expr in program:
			if expr[0] == 'function':
				self.compileFunction(expr)
			else:
				self.compileExpression(expr)
				self.currentFunction.emitInstruction(OP_POP) # Clean up stack

		# Put an infinite loop at the end 
		forever = self.currentFunction.generateLabel()
		self.currentFunction.emitLabel(forever)
		self.currentFunction.emitBranchInstruction(OP_GOTO, forever)
		
		# The top level code (which looks like a function) is the first code
		# emitted, since that's where execution will start
		self.functionList[0] = self.currentFunction

		# Strip out functions that aren't called
		self.functionList = filter(lambda x: x.referenced, self.functionList)

		# Need to determine where functions are in memory
		self.codeLength = 0
		for func in self.functionList:
			func.baseAddress = self.codeLength
			self.codeLength += len(func.instructions)

		# Do fixups
		for function in self.functionList:
			function.performLocalFixups()		# Replace labels with offsets

		self.performGlobalFixups()

		# Fix up the global variable size table (we know it is the push right
		# after reserve)
		self.functionList[0].patch(1, len(self.globals))

		# For debugging: create a listing of the instructions used.
		listfile = open('program.lst', 'wb')

		# Write out table of global variables
		listfile.write('Globals:\n')
		for var in self.globals:
			sym = self.globals[var]
			if sym.type == Symbol.FUNCTION:
				listfile.write(' ' + var + ' function@' + str(sym.function.baseAddress) + '\n')
			else:
				listfile.write(' ' + var + ' var@' + str(sym.index) + '\n')

		for func in self.functionList:
			listfile.write('\nfunction @' + str(func.baseAddress) + '\n')
			disassemble(listfile, func.instructions, func.baseAddress)

		# Write out expanded expressions
		prettyPrintSExpr(listfile, program, 0)

		listfile.close()
		
		# Now consolidate the functions
		instructions = []
		for func in self.functionList:
			instructions += func.instructions		
		
		return instructions

	#
	# Compile function definition (function name (param param...) body)
	#
	def compileFunction(self, expr):
		function = self.compileFunctionBody(expr[2], expr[3])
		self.functionList += [ function ]
	
		if expr[1] in self.globals:
			# There was a forward reference to this function and it was 
			# assumed to be a global.  We're kind of stuck with that now,
			# because code was generated that can't be easily fixed up.
			# Emit code to stash it in the global table.
			sym = self.globals[expr[1]]
			if sym.initialized:
				raise Exception('Global variable ' + expr[1] + ' redefined as function')

			# Function address, to be fixed up
			self.currentFunction.emitInstruction(OP_PUSH, 0)
			self.globalFixups += [ ( self.currentFunction,
				self.currentFunction.getProgramAddress() - 1, function ) ]

			# Global variable offset, to be fixed up
			self.currentFunction.emitInstruction(OP_PUSH, 0)
			self.globalFixups += [ ( self.currentFunction,
				self.currentFunction.getProgramAddress() - 1, sym ) ]
			self.currentFunction.emitInstruction(OP_STORE);
			self.currentFunction.emitInstruction(OP_POP);
			sym.initialized = True
			function.referenced = True
		else:
			sym = Symbol(Symbol.FUNCTION)
			sym.initialized = True
			sym.function = function


		self.globals[expr[1]] = sym

	#
	# The mother compile function, from which all other things are compiled.
	# Compiles an arbitrary lisp expression.  Each expression must consume
	# all parameters, which will be pushed onto the stack from right to left,
	# and leave a value on the stack.  All expressions have values in LISP.
	#
	def compileExpression(self, expr):
		if isinstance(expr, list):
			if len(expr) == 0:
				# Empty expression
				self.currentFunction.emitInstruction(OP_PUSH, 0)
			else:
				self.compileCombination(expr)
		elif isinstance(expr, int):
			self.compileConstant(expr)
		elif expr[0] == '"':
			self.compileString(expr[1:-1])
		else:
			# This is a variable.
			self.compileAtom(expr)

	def compileConstant(self, expr):
		self.currentFunction.emitInstruction(OP_PUSH, expr)

	# 
	# compile atom reference (which will look up the variable in the current
	# environment)
	#
	def compileAtom(self, expr):
		variable = self.lookupSymbol(expr)
		if variable.type == Symbol.LOCAL_VARIABLE:
			self.currentFunction.emitInstruction(OP_GETLOCAL, 
				variable.index)
		elif variable.type == Symbol.GLOBAL_VARIABLE:
			self.currentFunction.emitInstruction(OP_PUSH, 0)
			self.globalFixups += [ ( self.currentFunction,
				self.currentFunction.getProgramAddress() - 1, variable ) ]
			self.currentFunction.emitInstruction(OP_LOAD);
		elif variable.type == Symbol.FUNCTION:
			variable.function.referenced = True
			self.currentFunction.emitInstruction(OP_PUSH, 0)
			self.globalFixups += [ ( self.currentFunction,
				self.currentFunction.getProgramAddress() - 1, variable ) ]
		else:
			raise Exception('internal error: symbol does not have a valid type', '')

	#
	# A combination is basically a list expresion (op param param...)
	# This may be a special form or a function call.
	# Anything that isn't an atom or a number is going to be compiled here.
	#
	def compileCombination(self, expr):
		functionName = expr[0]
		if functionName in self.ARITH_OPS:
			self.compileArithmetic(expr)
		elif functionName == 'lambda':
			self.compileLambda(expr)
		elif functionName == 'begin':
			self.compileSequence(expr[1:])
		elif functionName == 'while':
			self.compileWhile(expr)
		elif functionName == 'break':
			self.compileBreak(expr)
		elif functionName == 'if':		# Special forms handling starts here
			self.compileIf(expr)
		elif functionName == 'assign':
			self.compileAssign(expr)
		elif functionName == 'quote':
			self.compileQuote(expr[1])
		elif functionName == 'let':
			self.compileLet(expr)
		elif functionName == 'getbp':
			self.currentFunction.emitInstruction(OP_GETBP)
		else:
			# Anything that isn't a built in form falls through to here.
			self.compileFunctionCall(expr)

	def compileBasePointer(self, expr):
		self.currentFunction.emitInstruction(OP_GETLOCAL, 0)

	#
	# In order to handle quoted expressions, we need to set up a bunch of cons
	# calls.
	#
	def compileQuote(self, expr):
		if isinstance(expr, list):
			self.compileQuotedList(expr)
		elif isinstance(expr, int):
			self.compileConstant(expr)
		else:
			self.compileString(expr)

	def compileQuotedList(self, tail):
		if len(tail) == 1:
			self.compileConstant(0)
		else:
			# Do the tail first to avoid allocating too many temporaries
			self.compileQuotedList(tail[1:])

		self.compileQuote(tail[0])

		# Cons is not an instruction.  Emit a call to the library function
		self.compileAtom('cons')
		self.currentFunction.emitInstruction(OP_CALL)
		self.currentFunction.emitInstruction(OP_CLEANUP, 2)

	#
	# Strings just compile down to lists of characters, since there is not
	# a native string type.
	#
	def compileString(self, string):
		if len(string) == 1:
			self.compileConstant(0)
		else:
			self.compileString(string[1:])

		self.compileConstant(ord(string[0]))

		# Cons is not an instruction.  Emit a call to the library function
		self.compileAtom('cons')
		self.currentFunction.emitInstruction(OP_CALL)
		self.currentFunction.emitInstruction(OP_CLEANUP, 2)

	# 
	# Set a variable (assign variable value)
	# This will leave the value on the stack (the value of this expression),
	# which is why there is a DUP here.
	#
	def compileAssign(self, expr):
		variable = self.lookupSymbol(expr[1])
		if variable.type == Symbol.LOCAL_VARIABLE:
			self.compileExpression(expr[2])
			self.currentFunction.emitInstruction(OP_DUP)
			self.currentFunction.emitInstruction(OP_SETLOCAL, variable.index)
		elif variable.type == Symbol.GLOBAL_VARIABLE:
			self.compileExpression(expr[2])
			self.currentFunction.emitInstruction(OP_PUSH, 0)
			self.globalFixups += [ ( self.currentFunction,
				self.currentFunction.getProgramAddress() - 1, variable ) ]
			self.currentFunction.emitInstruction(OP_STORE);
			variable.initialized = True
		elif variable.type == Symbol.FUNCTION:
			raise Exception('Error: cannot assign function')
		else:
			raise Exception('Internal error: what kind of variable is ' + expr[1] + '?', '')

	#
	# Note that this won't alter the stack.  It instead sets up branches to the appropriate
	# targets, performing short circuit evaluation where possible.
	#
	def compileBooleanExpression(self, expr, falseTarget):
		if isinstance(expr, list):
			if expr[0] == 'and':
				# Note that we short circuit if the first condition is false and
				# jump directly to the false case
				self.compileBooleanExpression(expr[1], falseTarget)
				self.compileBooleanExpression(expr[2], falseTarget)
				return
			elif expr[0] == 'or':
				testSecond = self.currentFunction.generateLabel()
				trueTarget = self.currentFunction.generateLabel()

				self.compileBooleanExpression(expr[1], testSecond)
				self.currentFunction.emitBranchInstruction(OP_GOTO, trueTarget)
				self.currentFunction.emitLabel(testSecond)
				self.compileBooleanExpression(expr[2], falseTarget)
				self.currentFunction.emitLabel(trueTarget)
				return

		self.compileExpression(expr)
		self.currentFunction.emitBranchInstruction(OP_BFALSE, falseTarget)

	#
	# Conditional execution of the form
	# (if expr true [false])
	#
	def compileIf(self, expr):
		falseLabel = self.currentFunction.generateLabel()
		doneLabel = self.currentFunction.generateLabel()

		self.compileBooleanExpression(expr[1], falseLabel)
		self.compileExpression(expr[2])	# True part
		self.currentFunction.emitBranchInstruction(OP_GOTO, doneLabel);
		self.currentFunction.emitLabel(falseLabel)
		
		# False part
		if len(expr) > 3:
			self.compileExpression(expr[3])	
		else:
			self.currentFunction.emitInstruction(OP_PUSH, 0)
		
		self.currentFunction.emitLabel(doneLabel)


	#
	# (while condition body)
	# Note that body is implitly a (begin... and can use a sequence
	# Leaves a zero on the stack when it finishes
	#
	def compileWhile(self, expr):
		topOfLoop = self.currentFunction.generateLabel()
		exitLoop = self.currentFunction.generateLabel()
		self.loopStack += [ exitLoop ]
		self.currentFunction.emitLabel(topOfLoop)
		self.compileExpression(expr[1])
		self.currentFunction.emitBranchInstruction(OP_BFALSE, exitLoop)
		self.compileSequence(expr[2:])
		self.currentFunction.emitInstruction(OP_POP) # Clean up stack
		self.currentFunction.emitBranchInstruction(OP_GOTO, topOfLoop)
		self.currentFunction.emitLabel(exitLoop)
		self.loopStack.pop()

		self.currentFunction.emitInstruction(OP_PUSH, 0)

	# break out of a loop 
	# (break [value])
	# XXX value currently ignored
	def compileBreak(self, expr):
		label = self.loopStack[-1]
		# self.compileExpression(expr[1])	# Push value on stack
		self.currentFunction.emitBranchInstruction(OP_GOTO, label)

 	ARITH_OPS = {
		'+' 		: ( OP_ADD, 2),
		'-' 		: ( OP_SUB, 2),
		'>'			: ( OP_GTR, 2),
		'>='		: ( OP_GTE, 2),
		'<'			: (-1, 2),	# These are handled by switching operand order
		'<='		: (-1, 2),
		'='			: (OP_EQ, 2),
		'<>'		: (OP_NEQ, 2),
		'load' 		: (OP_LOAD, 1),
		'store'		: (OP_STORE, 2),
		'first'		: (OP_LOAD, 1),
		'rest' 		: (OP_REST, 1),
		'settag'	: (OP_SETTAG, 2),
		'gettag'	: (OP_GETTAG, 1),
		'and'		: (OP_AND, 2),
		'or'		: (OP_OR, 2),
		'xor'		: (OP_XOR, 2),
		'rshift'	: (OP_RSHIFT, 2),
		'lshift'	: (OP_LSHIFT, 2)
 	}

	def compileArithmetic(self, expr):
		opcode, nargs = self.ARITH_OPS[expr[0]]
	
		if len(expr) - 1 != nargs:
			raise Exception('wrong number of arguments for', expr[0])
	
		# Synthesize lt and lte operators by switching order and using the opposite operators
		if expr[0] == '<':
			self.compileExpression(expr[1])
			self.compileExpression(expr[2])
			self.currentFunction.emitInstruction(OP_GTR)
		elif expr[0] == '<=':
			self.compileExpression(expr[1])
			self.compileExpression(expr[2])
			self.currentFunction.emitInstruction(OP_GTE)
		else:
			if len(expr) > 2:
				self.compileExpression(expr[2])

			self.compileExpression(expr[1])
			self.currentFunction.emitInstruction(opcode)

	def compileFunctionCall(self, expr):
		# User defined function call.  Create a new frame.
		# evaluate parameter expressions and stash results into frame
		# for next call.
		for paramExpr in reversed(expr[1:]):
			self.compileExpression(paramExpr)

		self.compileAtom(expr[0])
		self.currentFunction.emitInstruction(OP_CALL)
		if len(expr) > 1:
			self.currentFunction.emitInstruction(OP_CLEANUP, len(expr) - 1)

	#
	# Actual guts of the function body
	# ((param param...) body)
	#
	def compileFunctionBody(self, params, body):
		oldFunc = self.currentFunction
		newFunction = Function()
		self.currentFunction = newFunction
		self.enterLambda()
		
		for index, paramName in enumerate(params):
			var = self.createLocalVariable(paramName)
			var.index = index + 1

		self.currentFunction.numParams = len(params)
	
		# Compile top level expression.
		self.compileExpression(body)
		self.currentFunction.emitInstruction(OP_RETURN)
		self.exitLambda()
		self.currentFunction = oldFunc

		return newFunction

	#
	# lambda expression will be of the form (lambda (param param...) (expr))
	# We generate the code in a separate function, then we will emit a reference
	# to that code in the current function.
	#
	def compileLambda(self, expr):
		newFunction = self.compileFunctionBody(expr[1], expr[2])
		newFunction.referenced = True
		
		# Now compile code that references the lambda object we created.  We'll
		# set the tag to indicate this is a function.
		self.currentFunction.emitInstruction(OP_PUSH, TAG_FUNCTION)
		self.currentFunction.emitInstruction(OP_PUSH, 0)
		self.globalFixups += [ ( self.currentFunction,
			self.currentFunction.getProgramAddress() - 1, newFunction ) ]
		self.currentFunction.emitInstruction(OP_SETTAG)
		self.functionList += [ newFunction ]

	#
	# A block of expressions
	#
	def compileSequence(self, sequence):
		# Execute a sequence of statements
		# (begin stmt1 stmt2 stmt3...)
		first = True
		for expr in sequence:
			if not first:
				self.currentFunction.emitInstruction(OP_POP) # Clean up stack

			first = False
			self.compileExpression(expr)

	#
	# Of the form (let ((variable value) (variable value) (variable value)...) expr)
	# Reserve local variables and assign initial values to them.
	#
	def compileLet(self, expr):
		# Reserve space on stack for local variables
		variableCount = len(expr[1])
		self.enterScope()

		# Walk through each variable, define in scope, evaluate the initial value,
		# and assign.
		for variable, value in expr[1]:
			symbol = self.createLocalVariable(variable)
			symbol.index = self.currentFunction.allocateLocal()
			self.compileExpression(value)
			self.currentFunction.emitInstruction(OP_SETLOCAL, symbol.index)

		# Now evaluate the predicate, which can be a sequence
		self.compileSequence(expr[2:])
		self.exitScope()

	def performGlobalFixups(self):
		# Check if there are uninitialized globals
		for varName in self.globals:
			if not self.globals[varName].initialized:
				print 'unknown variable %s' % varName

		for function, functionOffset, target in self.globalFixups:
			if isinstance(target, Function):
				function.patch(functionOffset, target.baseAddress)
			elif isinstance(target, Symbol):
				if target.type == Symbol.GLOBAL_VARIABLE:
					function.patch(functionOffset, target.index)
				elif target.type == Symbol.FUNCTION:
					function.patch(functionOffset, target.function.baseAddress)
			else:
				raise Exception('unknown global fixup type')

BINOPS = {
	'+' : (lambda x, y : x + y),
	'-' : (lambda x, y : x - y),
	'/' : (lambda x, y : x / y),
	'*' : (lambda x, y : x * y),
	'and' : (lambda x, y : x & y),
	'or' : (lambda x, y : x | y),
	'xor' : (lambda x, y : x ^ y),
	'lshift' : (lambda x, y : x << y),
	'rshift' : (lambda x, y : x >> y),
	'>' : (lambda x, y : 1 if x > y else 0),
	'>=' : (lambda x, y : 1 if x >= y else 0),
	'<' : (lambda x, y : 1 if x < y else 0),
	'<=' : (lambda x, y : 1 if x <= y else 0),
	'=' : (lambda x, y : 1 if x == y else 0),
	'<>' : (lambda x, y : 1 if x != y else 0)
}

UOPS = {
	'~' : (lambda x : ~x),
	'-' : (lambda x : -x)
}

#
# Simple arithmetic constant folding on the S-Expression data structure.
#
def foldConstants(expr):
	if isinstance(expr, list) and len(expr) > 0:
		if expr[0] == 'quote':
			return expr			# Ignore everything in quotes
		else:
			# Fold arithmetic expressions if possible
			optimizedParams = [ foldConstants(sub) for sub in expr[1:] ]
			if not isinstance(expr[0], list) and expr[0] in BINOPS \
				and len(expr) == 3 and isinstance(optimizedParams[0], int) \
				and isinstance(optimizedParams[1], int):
				return BINOPS[expr[0]](optimizedParams[0], optimizedParams[1])
			
			if not isinstance(expr[0], list) and expr[0] in UOPS \
				and len(expr) == 2 and isinstance(optimizedParams[0], int):
				return UOPS[expr[0]](optimizedParams[0])
				
			# If an if form has a constant expression, only include the
			# appropriate clause
			if not isinstance(expr[0], list) and expr[0] == 'if' \
				and isinstance(optimizedParams[0], int):
				if optimizedParams[0] != 0:
					return optimizedParams[1]
				else:
					return optimizedParams[2]

			return [ expr[0] ] + optimizedParams
	else:
		return expr

#
# For debugging
#

# name, hasparam
disasmTable = {
	OP_NOP			: ('nop', False),
	OP_CALL 		: ('call', False),
	OP_RETURN 		: ('return', False),
	OP_CLEANUP 		: ('cleanup', True),
	OP_POP 			: ('pop', False),
	OP_ADD 			: ('add', False),
	OP_SUB 			: ('sub', False),
	OP_PUSH 		: ('push', True),
	OP_LOAD 		: ('load', False),
	OP_STORE 		: ('store', False),
	OP_GETLOCAL 	: ('getlocal', True),
	OP_SETLOCAL 	: ('setlocal', True),
	OP_GOTO 		: ('goto', True),
	OP_BFALSE 		: ('bfalse', True),
	OP_REST 		: ('rest', False),
	OP_RESERVE 		: ('reserve', True),
	OP_GTR			: ('gtr', False),
	OP_GTE			: ('gte', False),
	OP_EQ			: ('eq', False),
	OP_NEQ			: ('neq', False),
	OP_DUP			: ('dup', False),
	OP_GETTAG		: ('gettag', False),
	OP_SETTAG		: ('settag', False),
	OP_AND			: ('and', False),
	OP_OR			: ('or', False),
	OP_XOR			: ('xor', False),
	OP_LSHIFT		: ('lshift', False),
	OP_RSHIFT		: ('rshift', False),
	OP_GETBP		: ('getbp', False)
}

def disassemble(outfile, instructions, baseAddress):
	for pc, word in enumerate(instructions):
		outfile.write('' + str(baseAddress + pc))
		opcode = (word >> 16)
		name, hasParam = disasmTable[opcode]
		if hasParam:
			paramValue = word & 0xffff
			if paramValue & 0x8000:
				paramValue = -(((paramValue ^ 0xffff) + 1) & 0xffff)

			outfile.write('\t' + name + ' ' + str(paramValue) + '\n')
		else:
			outfile.write('\t' + name + '\n')

def prettyPrintSExpr(listfile, expr, indent = 0):
	if isinstance(expr, list):
		listfile.write('\n')
		for x in range(indent):
			listfile.write('  ')
		
		listfile.write('(')
		for elem in expr:
			if elem != expr[0]:
				listfile.write(' ')

			prettyPrintSExpr(listfile, elem, indent + 1)
			
		listfile.write(')\n')
		for x in range(indent - 1):
			listfile.write('  ')
	else:
		listfile.write(str(expr))


#
# The macro processor is actually a small lisp interpreter
# When we see macro, we evaluate its expression with the arguments as parameters.
#
class MacroProcessor:
	def __init__(self):
		self.macroList = {}

	def expandBackquote(self, expr, env):
		if isinstance(expr, list):
			if expr[0] == 'unquote':
				return self.eval(expr[1], env)	# This gets evaluated regularly
			else:
				return [ self.expandBackquote(term, env) for term in expr ]
		else:
			return expr

	def eval(self, expr, env):
		if isinstance(expr, list):
			func = expr[0]
			if func == 'first':
				return self.eval(expr[1], env)[0]
			elif func == 'rest':
				return self.eval(expr[1], env)[1]
			elif func == 'if':		# (if test trueexpr falsexpr)
				if self.eval(expr[1], env):
					return self.eval(pair[2], env)
				elif len(expr) > 3:
					return self.eval(expr[3], env)
				else:
					return 0
			elif func == 'assign':	# (assign var value)
				env[expr[1]] = self.eval(expr[2], env)
			elif func == 'list':
				return [ self.eval(element, env) for element in expr[1:] ]
			elif func == 'quote':
				return expr[1]
			elif func == 'backquote':
				return self.expandBackquote(expr[1], env)
			elif func == 'cons':
				return [ self.eval(expr[1], env) ] + [ self.eval(expr[2], env) ]
			elif func in BINOPS:
				return BINOPS[func](self.eval(expr[1], env), self.eval(expr[2], env) )
			elif func in self.macroList:
				# Invoke a sub-macro
				newEnv = copy.copy(env)
				argList, body = self.macroList[expr[0]]		
				for name, value in zip(argList, expr[1:]):
					newEnv[name] = value
					
				return self.eval(body, newEnv)
			else:
				# Call a function. This is a little tricky, since we can't really
				# define functions. Stubbed out for now.
				func = self.env[expr[0]]		# Func is (lambda (arg arg arg) body)
				if func == None or not isinstance(func, list) or func[0] != 'lambda':
					raise Exception('bad function call during macro expansion', '')
				for name, value in zip(func[0], expr[1:]):
					env[name] = self.eval(value, env)

				return self.eval(func[1], env)
		elif isinstance(expr, int):
			return expr	
		else:
			return env[expr]

	def macroPreProcess(self, program):
		updatedProgram = []
		for statement in program:
			if isinstance(statement, list) and statement[0] == 'defmacro':
				# (defmacro <name> (arg list) replace)
				self.macroList[statement[1]] = (statement[2], statement[3])
			else:
				updatedProgram += [ self.macroExpandRecursive(statement) ]

		return updatedProgram

	def macroExpandRecursive(self, statement):
		if isinstance(statement, list) and len(statement) > 0:
			if not isinstance(statement[0], list) and statement[0] in self.macroList:
				# This is a macro form.  Evalute the macro now and replace this form with
				# the result.
				argNames, body = self.macroList[statement[0]]
				if len(argNames) != len(statement) - 1:
					print 'warning: macro expansion of %s has the wrong number of arguments' % statement[0]
					print 'expected %d got %d:' % (len(argNames), len(statement) - 1)
					for arg in statement[1:]:
						print arg

				env = {}
				for name, value in zip(argNames, statement[1:]):
					env[name] = self.macroExpandRecursive(value)
					
				return self.eval(body, env)
			else:
				return [ self.macroExpandRecursive(term) for term in statement ]
		else:
			return statement

parser = Parser()
parser.parseFile('runtime.lisp')
for filename in sys.argv[1:]:
	parser.parseFile(filename)

macro = MacroProcessor()
expanded = macro.macroPreProcess(parser.getProgram())

optimized = [ foldConstants(sub) for sub in expanded ]

compiler = Compiler()
code = compiler.compile(optimized)

outfile = open('rom.hex', 'w')
for instr in code:
	outfile.write('%06x\n' % instr)
		
outfile.close()

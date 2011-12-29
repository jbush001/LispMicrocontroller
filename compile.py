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

import sys, shlex

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

	def __init__(self, type):
		self.type = type
		self.index = -1
		self.initialized = False	# For globals

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
		self.currentInstruction = 0	# A word that is being packed
		self.instructionOffset = 0	# Within word
		self.instructions = []		# Each entry is a word

		# Save a spot for an initial 'reserve' instruction
		self.emitInstructionWithParam(OP_RESERVE, 16383)

	def generateLabel(self):
		return Label()
		
	def allocateLocal(self):
		index = -(self.numLocals + 2)	# Skip return address and base pointer
		self.numLocals += 1
		return index

	def getProgramAddress(self):
		return len(self.instructions)

	# Align to word boundary
	def align(self):
		if self.instructionOffset != 0:
			self.instructions += [ self.currentInstruction ]
			self.instructionOffset = 0
			self.currentInstruction = 0

	def emitLabel(self, label):
		assert not label.defined
		label.defined = True
		self.align()
		label.address = self.getProgramAddress()

	def emitInstruction(self, op):
		self.currentInstruction |= op << ((3 - self.instructionOffset) *  5)
		self.instructionOffset += 1
		if self.instructionOffset == 4:
			self.instructions += [ self.currentInstruction ]
			self.instructionOffset = 0
			self.currentInstruction = 0

	def emitBranchInstruction(self, op, label):
		if label.defined:
			# We can emit this now.
			offset = label.address - self.getProgramAddress()
			self.emitInstructionWithParam(op, offset)
		else:
			# Forward reference, we'll get back to it later
			self.emitInstructionWithParam(op, 16383)
			self.localFixups += [( self.getProgramAddress() - 1, label)]

	def emitInstructionWithParam(self, op, param):
		# Determine the size required for this parameter
		if param > 16383 or param < -16384:
			raise Exception('param out of range ' + str(param));
		elif param > 511 or param < -512:
			paramSize = 3
		elif param > 15 or param < -16:
			paramSize = 2
		else:
			paramSize = 1
	
		# XXX could allow a param of zero to be at end of word as an optimization
		if self.instructionOffset + 1 + paramSize > 4:
			# Need to start a new packet to make this fit
			self.instructions += [ self.currentInstruction ]
			self.instructionOffset = 0
			self.currentInstruction = 0

		# Convert to two's complement
		if param < 0:
			param = ((-param ^ 0xffffffff) + 1) & 0xffffffff

		maskedParam = param & ((1 << ((3 - self.instructionOffset) * 5)) - 1)
		self.currentInstruction |= op << ((3 - self.instructionOffset) * 5)
		self.currentInstruction |= maskedParam
	
		# Round out this instruction
		self.instructionOffset = 0
		self.instructions += [ self.currentInstruction ]
		self.currentInstruction = 0

	def patch(self, offset, value):
		self.instructions[offset] &= ~0x7fff
		self.instructions[offset] |= value

	def performLocalFixups(self):
		if self.instructionOffset != 0:
			self.instructions += [ self.currentInstruction ]
	
		self.instructions[0] = (OP_RESERVE << 15) | self.numLocals
		for ip, label in self.localFixups:
			if not label.defined:
				raise Exception('undefined label')

			self.patch(ip, label.address - ip)


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
		self.lexer.wordchars += '<>!@#$%^&*;:.=-_'

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
		# This is a stack of lambdas, which is a stack of scopes, which is a 
		# dictionary of symbols.  Because closures are not currently
		# supported, we cannot access variables from the outer function.
		self.globals = {}
		self.environmentStack = [[{ 'T' : 1 }]]
		self.currentFunction = Function()
		self.functionTable = [ 0 ]		# We reserve a spot for 'main'
		self.loopStack = []	# Each entry is ( resultReg, exitLabel )

		# Can be a fixup for:
		#   - A global variable 
		#   - A function pointer
		# Each stores ( type, function, functionOffset, value )
		self.globalFixups = []	

	def enterScope(self):
		self.environmentStack[-1] += [{}]

	def exitScope(self):
		self.environmentStack[-1].pop()

	def enterLambda(self):
		# XXX could support closures here by tagging variables, but currently
		# not implemented.
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
		for scope in self.environmentStack[-1]:
			if name in scope:
				return scope[name]

		if name in self.globals:
			return self.globals[name]

		# XXX technically we could walk back up the environment stack to find closures,
		# but that is currently not supported.

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
	def compile(self, expr):
		self.currentFunction = Function()

		# create a built-in variable that indicates where the heap starts
		# (will be patched at the end of compilation with the proper address)
		self.lookupSymbol('$globalstart').initialized = True
		self.lookupSymbol('$heapstart').initialized = True

		for sub in expr:
			self.compileExpression(sub)

		# Put an infinite loop at the end 
		forever = self.currentFunction.generateLabel()
		self.currentFunction.emitLabel(forever)
		self.currentFunction.emitBranchInstruction(OP_GOTO, forever)
		
		# The top level code (which looks like a function) is the first code
		# emitted, since that's where execution will start
		self.functionTable[0] = self.currentFunction

		# Do fixups
		for function in self.functionTable:
			function.performLocalFixups()		# Replace labels with offsets

		self.performGlobalFixups()			

		# For debugging: create a listing of the instructions used.
		listfile = open('program.lst', 'wb')

		# Write out table of global variables
		listfile.write('Globals:\n')
		for var in self.globals:
			listfile.write(' ' + var + ' ' + str(self.globals[var].index + self.codeLength) + '\n')

		# Write out expanded expressions
		writeExpr(listfile, expr, 0)

		for func in self.functionTable:
			listfile.write('\nfunction @' + str(func.baseAddress) + '\n')
			disassemble(listfile, func.instructions, func.baseAddress)

		listfile.close()
		
		# Now consolidate the functions
		instructions = []
		for func in self.functionTable:
			instructions += func.instructions		
				
		# Write the values for __globalstart and __heapstart variables
		instructions += [ self.codeLength, self.codeLength + len(self.globals) ]
		
		return instructions

	#
	# The mother compile function, from which all other things are compiled.
	# Compiles an arbitrary lisp expression. 
	#
	def compileExpression(self, expr):
		if isinstance(expr, list):
			if len(expr) == 0:
				# Empty expression
				self.currentFunction.emitInstructionWithParam(OP_PUSH, 0)
			elif expr[0] == 'lambda':
				self.compileLambda(expr)
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
		self.currentFunction.emitInstructionWithParam(OP_PUSH, expr)

	# 
	# compile atom reference (which will look up the variable in the current
	# environment)
	#
	def compileAtom(self, expr):
		variable = self.lookupSymbol(expr)
		if variable.type == Symbol.LOCAL_VARIABLE:
			self.currentFunction.emitInstructionWithParam(OP_GETLOCAL, 
				variable.index)
		elif variable.type == Symbol.GLOBAL_VARIABLE:
			self.currentFunction.emitInstructionWithParam(OP_PUSH, 16383)
			self.globalFixups += [ ( self.currentFunction,
				self.currentFunction.getProgramAddress() - 1, variable ) ]
			self.currentFunction.emitInstruction(OP_LOAD);
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
		elif functionName == 'begin':
			self.compileSequence(expr[1:])
		elif functionName == 'while':
			self.compileWhile(expr)
		elif functionName == 'break':
			self.compileBreak(expr)
		elif functionName == 'cond':	# Special forms handling starts here
			self.compileCond(expr)
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
		self.currentFunction.emitInstructionWithParam(OP_GETLOCAL, 0)

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
		self.currentFunction.align()
		self.currentFunction.emitInstructionWithParam(OP_CLEANUP, 2)

	#
	# Strings just compile down to lists of characters, since the VM does not
	# natively support strings.
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
		self.currentFunction.align()
		self.currentFunction.emitInstructionWithParam(OP_CLEANUP, 2)

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
			self.currentFunction.emitInstructionWithParam(OP_SETLOCAL, variable.index)
		elif variable.type == Symbol.GLOBAL_VARIABLE:
			self.compileExpression(expr[2])
			self.currentFunction.emitInstruction(OP_DUP)
			self.currentFunction.emitInstructionWithParam(OP_PUSH, 16383)
			self.globalFixups += [ ( self.currentFunction,
				self.currentFunction.getProgramAddress() - 1, variable ) ]
			self.currentFunction.emitInstruction(OP_STORE);
			variable.initialized = True
		else:
			raise Exception('Internal error: what kind of variable is ' + expr[1] + '?', '')

	#
	# Note that this won't alter the stack.  It instead sets up branches to the appropriate
	# targets
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
				self.currentFunction.emitInstruction(OP_GOTO, trueTarget)
				self.currentFunction.emitLabel(testSecond)
				self.compileBooleanExpression(expr[2], falseTarget)
				self.currentFunction.emitLabel(trueTarget)
				return

		self.compileExpression(expr)
		self.currentFunction.emitBranchInstruction(OP_BFALSE, falseTarget)

	#
	# Conditional execution of the form
	# (cond (check1 val1) (check2 val2) (check3 val3))
	#
	def compileCond(self, expr):
		doneLabel = self.currentFunction.generateLabel()
		nextLabel = None
	
		for check, val in expr[1:]:
			if nextLabel != None:
				self.currentFunction.emitLabel(nextLabel)

			nextLabel = self.currentFunction.generateLabel()
			if check == '1' or check == 'T':
				# This is a default case, take a short-circuit fastpath
				self.currentFunction.emitLabel(nextLabel)
				self.compileExpression(val)
				self.currentFunction.emitLabel(doneLabel)
				return
			else:
				self.compileBooleanExpression(check, nextLabel)
				self.compileExpression(val)
				self.currentFunction.emitBranchInstruction(OP_GOTO, doneLabel);

		# No cases were true.  Behavior is technically undefined, but we 
		# return 0
		self.currentFunction.emitLabel(nextLabel)
		self.currentFunction.emitInstructionWithParam(OP_PUSH, 0)
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

		result = self.compileSequence(expr[2:])
		self.currentFunction.emitInstruction(OP_POP) # Clean up stack
		self.currentFunction.emitBranchInstruction(OP_GOTO, topOfLoop)
		self.currentFunction.emitLabel(exitLoop)
		self.loopStack.pop()

		self.currentFunction.emitInstructionWithParam(OP_PUSH, 0)

	# break out of a loop 
	# (break [value])		
	def compileBreak(self, expr):
		outValue, label = self.loopStack[-1]
		self.compileExpression(expr[1], outValue)	# Push value on stack
		self.currentFunction.emitInstruction(OP_GOTO, label)

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
				if opcode == OP_STORE:
					self.currentFunction.emitInstruction(OP_DUP)
	
			self.compileExpression(expr[1])
			self.currentFunction.emitInstruction(opcode)

	def compileFunctionCall(self, expr):
		# User defined function call.  Create a new frame.
		# evaluate parameter expressions and stash results into frame
		# for next call.
		for paramExpr in reversed(expr[1:]):
			self.compileExpression(paramExpr)

		# Push the address of the function
		self.compileAtom(expr[0])
		
		self.currentFunction.emitInstruction(OP_CALL)
		self.currentFunction.align()	# Return always comes back to word boundary
		if len(expr) > 1:
			self.currentFunction.emitInstructionWithParam(OP_CLEANUP, len(expr) - 1)

	#
	# lambda expression will be of the form (lambda (param param...) (expr))
	# We generate the code in a separate function, then we will emit a reference
	# to that code in the current function.
	#
	def compileLambda(self, expr):
		# We begin generating a totally new function
		oldFunc = self.currentFunction
		newFunction = Function()
		self.currentFunction = newFunction
		
		self.enterLambda()
		
		for index, paramName in enumerate(expr[1]):
			var = self.createLocalVariable(paramName)
			var.index = index + 1

		self.currentFunction.numParams = len(expr[1])
	
		# Compile top level expression.
		self.compileExpression(expr[2])
		self.currentFunction.emitInstruction(OP_RETURN)
		self.exitLambda()
		self.currentFunction = oldFunc
		
		# Now compile code that references the lambda object we created.  We'll
		# set the tag to indicate this is a function.
		self.currentFunction.emitInstructionWithParam(OP_PUSH, TAG_FUNCTION)
		self.currentFunction.emitInstructionWithParam(OP_PUSH, 16383)
		self.currentFunction.emitInstruction(OP_SETTAG)
		self.globalFixups += [ ( self.currentFunction,
			self.currentFunction.getProgramAddress() - 1, newFunction ) ]
		self.functionTable += [ newFunction ]

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
			self.currentFunction.emitInstructionWithParam(OP_SETLOCAL, symbol.index)

		# Now evaluate the predicate, which can be a sequence
		self.compileSequence(expr[2:])
		self.exitScope()

	def performGlobalFixups(self):
		# Check if there are uninitialized globals
		for varName in self.globals:
			if not self.globals[varName].initialized:
				print 'unknown variable %s' % varName

		# Need to determine where functions are in memory and where global
		# table starts
		self.codeLength = 0
		for func in self.functionTable:
			func.baseAddress = self.codeLength
			self.codeLength += len(func.instructions)

		for function, functionOffset, target in self.globalFixups:
			if isinstance(target, Function):
				function.patch(functionOffset, target.baseAddress)
			elif isinstance(target, Symbol) and target.type == Symbol.GLOBAL_VARIABLE:
				function.patch(functionOffset, target.index + self.codeLength)
			else:
				raise Exception('unknown global fixup type')

FOLDABLE_BINOPS = {
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

FOLDABLE_UOPS = {
	'~' : (lambda x : ~x),
	'-' : (lambda x : -x)
}

def foldConstants(expr):
	if isinstance(expr, list) and len(expr) > 0:
		if expr[0] == 'quote':
			return expr			# Ignore everything in quotes
		elif expr[0] == 'cond':
			newExpr = [ 'cond' ]
			for test, result in expr[1:]:
				newTest = foldConstants(test)
				if newTest != '0':		# Eliminate cases that don't make sense
					newExpr += [ [ newTest, foldConstants(result) ] ]

			if len(newExpr) == 2 and (newExpr[1][0] == '1' or newExpr[1][0] == 'T'):
				newExpr = newExpr[1][1]	# There is only one case that is always true

			return newExpr
		else:
			# Optimize this expression
			optimizedParams = [ foldConstants(sub) for sub in expr[1:] ]
			if not isinstance(expr[0], list) and expr[0] in FOLDABLE_BINOPS \
				and len(expr) == 3 and not isinstance(optimizedParams[0], list) \
				and isinstance(optimizedParams[0], int) and not isinstance(optimizedParams[1], list) and isinstance(optimizedParams[1], int):
				return str(FOLDABLE_BINOPS[expr[0]](optimizedParams[0], optimizedParams[1]))
			if not isinstance(expr[0], list) and expr[0] in FOLDABLE_UOPS \
				and len(expr) == 2 and not isinstance(optimizedParams[0], list) \
				and isinstance(optimizedParams[0], int):
				return str(FOLDABLE_UOPS[expr[0]](optimizedParams[0]))
			else:
				return [ expr[0] ] + optimizedParams
	else:
		return expr

#
# For debugging
#

# name, hasparam
disasmTable = {
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
		for index in range(4):
			opcode = (word >> ((3 - index) * 5)) & 0x1f
			if opcode == 0:
				continue
				
			name, hasParam = disasmTable[opcode]
			if hasParam:
				paramBits = (3 - index) * 5
				mask = (1 << paramBits) - 1
				paramValue = word & mask
				if paramValue & (1 << (paramBits - 1)):
					paramValue = -(((paramValue ^ mask) + 1) & mask)

				if name == 'goto' or name == 'bfalse':
					paramValue = baseAddress + pc + paramValue
					
				outfile.write('\t' + name + ' ' + str(paramValue) + '\n')
				break	# Skip to next word
			else:
				outfile.write('\t' + name + '\n')

# Pretty print an S-Expression
def writeExpr(listfile, expr, indent):
	if isinstance(expr, list):
		listfile.write('\n')
		for x in range(indent):
			listfile.write('  ')
		
		listfile.write('(')
		for elem in expr:
			if elem != expr[0]:
				listfile.write(' ')

			writeExpr(listfile, elem, indent + 1)
			
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
			if expr[0] == 'first':
				return eval(expr[1])[0]
			elif expr[0] == 'rest':
				return eval(expr[1])[1]
			elif expr[0] == 'cond':		# (cond (test prediate) (test predicate)...)
				result = 0
				for pair in expr[1:]:
					if eval(pair[0]):
						result = eval(pair[1])
						break

				return result
			elif expr[0] == 'assign':	# (assign var value)
				env[expr[1]] = self.eval(expr[2], env)
			elif expr[0] == 'list':
				return [ self.eval(element) for element in expr[1:] ]
			elif expr[0] == 'quote':
				return expr[1]
			elif expr[0] == 'backquote':
				return self.expandBackquote(expr[1], env)
			elif expr[0] == 'cons':
				return [ self.eval(expr[1]) ] + [ self.eval(expr[2]) ]
			elif expr[0] in self.macroList:
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
					env[name] = value

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
parser.parseFile('runtime.l')
for filename in sys.argv[1:]:
	parser.parseFile(filename)

macro = MacroProcessor()
expanded = macro.macroPreProcess(parser.getProgram())
optimized = [ foldConstants(sub) for sub in expanded ]

compiler = Compiler()
code = compiler.compile(optimized)

outfile = open('ram.hex', 'w')
for instr in code:
	outfile.write('%06x\n' % instr)
		
outfile.close()
#!/usr/bin/python
#
# Copyright 2011-2012 Jeff Bush
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

'''
Read LISP source files and compile to machine code in hex
format. Output file is 'program.hex'

 ./compile.py <source file 1> [<source file 2>] ...
'''

import copy
import math
import shlex
import sys

TAG_INTEGER = 0  # Make this zero because types default to this when pushed
TAG_CONS = 1
TAG_FUNCTION = 2
TAG_CLOSURE = 3

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
OP_RESERVE = 24
OP_PUSH = 25
OP_GOTO = 26
OP_BFALSE = 27
OP_GETLOCAL = 29
OP_SETLOCAL = 30
OP_CLEANUP = 31


class Symbol(object):
    LOCAL_VARIABLE = 1
    GLOBAL_VARIABLE = 2
    FUNCTION = 3

    def __init__(self, symtype):
        self.type = symtype
        self.index = -1
        self.initialized = False    # For globals
        self.function = None
        self.closure_source = None


class Label(object):
    '''
    A label represents a branch destination.
    Labels are only visible inside the functions they are defined in.
    '''

    def __init__(self):
        self.defined = False
        self.offset = 0


class Function(object):

    def __init__(self):
        self.name = None
        self.fixups = []
        self.base_address = None
        self.num_local_variables = 0
        self.prologue = None
        self.instructions = []
        self.environment = [{}]         # Stack of scopes
        self.free_variables = []
        self.enclosing_function = None
        self.referenced = False         # Used to strip dead functions
        self.num_params = 0
        self.entry = Label()
        self.emit_label(self.entry)

    def enter_scope(self):
        self.environment += [{}]

    def exit_scope(self):
        self.environment.pop()

    def lookup_local_variable(self, name):
        for scope in reversed(self.environment):
            if name in scope:
                return scope[name]

        return None

    def reserve_local_variable(self, name):
        sym = Symbol(Symbol.LOCAL_VARIABLE)
        self.environment[-1][name] = sym
        # Skip return address and base pointer
        sym.index = -(self.num_local_variables + 2)
        self.num_local_variables += 1
        return sym

    def reserve_parameter(self, name, index):
        sym = Symbol(Symbol.LOCAL_VARIABLE)
        self.environment[-1][name] = sym
        sym.index = index + 1

    def emit_label(self, label):
        assert not label.defined
        label.defined = True
        label.offset = len(self.instructions)

    def emit_branch_instruction(self, op, label):
        self.emit_instruction(op, 0)
        self.add_fixup(label)

    def emit_instruction(self, op, param=0):
        if param > 32767 or param < -32768:
            raise Exception('param out of range ' + str(param))

        self.instructions += [(op << 16) | (param & 0xffff)]

    def add_prologue(self):
        prologue = []
        if self.num_local_variables > 0:
            prologue.append((OP_RESERVE << 16) | self.num_local_variables)

        if self.free_variables:
            prologue.append((OP_PUSH << 16) | 1)  # Address of $closure
            prologue.append(OP_LOAD << 16)

            # Read the list
            for index, var in enumerate(self.free_variables):
                if index:
                    prologue.append(OP_REST << 16)  # Read next pointer

                if index != len(self.free_variables) - 1:
                    # Save pointer for call to rest in next loop iteration
                    prologue.append(OP_DUP << 16)

                prologue.append(OP_LOAD << 16)  # Read value (car)
                prologue.append((OP_SETLOCAL << 16) | (
                    var.index & 0xffff))  # save
                prologue.append(OP_POP << 16)

        self.prologue = prologue

    def get_size(self):
        return len(self.prologue) + len(self.instructions)

    def add_fixup(self, target):
        '''
        This remembers that the last emitted instruction should be
        patched later to point to the passed object, which can be
        a Label, Function, or Symbol
        '''
        self.fixups.append((len(self.instructions) - 1, target))

    def patch(self, offset, value):
        self.instructions[offset] &= ~0xffff
        self.instructions[offset] |= (value & 0xffff)

    def apply_fixups(self):
        '''
        Walk through all fixups for this function and patch instructions
        to point to the proper targets (which this expects should all be
        known at this point).
        '''
        base_address = self.base_address + len(self.prologue)
        for pc, target in self.fixups:
            if isinstance(target, Label):
                assert target.defined
                self.patch(pc, base_address + target.offset)
            elif isinstance(target, Function):
                self.patch(pc, target.base_address)
            elif isinstance(target, Symbol):
                if target.type == Symbol.GLOBAL_VARIABLE:
                    self.patch(pc, target.index)
                elif target.type == Symbol.FUNCTION:
                    self.patch(pc, target.function.base_address)
            else:
                raise Exception(
                    'internal error: unknown fixup type ' + target.__name__)


class Parser(object):
    '''Converts text LISP source into a nested set of python lists'''

    def __init__(self):
        self.lexer = None
        self.program = []
        self.filename = None

    def parse_file(self, filename):
        self.filename = filename
        with open(filename, 'r') as stream:
            self.lexer = shlex.shlex(stream)
            self.lexer.commenters = ';'
            self.lexer.quotes = '"'
            self.lexer.wordchars += '?+<>!@#$%^&*;:.=-_'

            while True:
                expr = self.parse_expr()
                if expr == '':
                    break

                self.program += [expr]

    def parse_paren_list(self):
        parenlist = []
        while True:
            lookahead = self.lexer.get_token()
            if lookahead == '':
                print('missing )')
                break
            elif lookahead == ')':
                break

            self.lexer.push_token(lookahead)
            parenlist += [self.parse_expr()]

        return parenlist

    def parse_expr(self):
        token = self.lexer.get_token()
        if token == '':
            return ''
        elif token == '\'':
            return ['quote', self.parse_expr()]
        elif token == '`':
            return ['backquote', self.parse_expr()]
        elif token == ',':
            return ['unquote', self.parse_expr()]
        elif token == '(':
            return self.parse_paren_list()
        elif token.isdigit() or (token[0] == '-' and len(token) > 1):
            return int(token)
        elif token == ')':
            raise Exception('unmatched ), ' + self.filename +
                            ':' + str(self.lexer.lineno))
        else:
            return token


class Compiler(object):

    def __init__(self):
        self.globals = {}
        self.current_function = Function()
        self.function_list = [None]        # Reserve a spot for 'main'
        self.break_stack = []
        self.code_length = 0

    def lookup_symbol(self, name):
        '''
        Lookup a symbol, starting in the current scope and working outward
        to enclosing scopes. If the symbol doesn't exist, create it in the
        global scope.
        '''

        # Check for local variable
        sym = self.current_function.lookup_local_variable(name)
        if sym:
            return sym

        # A variable is 'free' if it is defined in the enclosing
        # function. In this example, a is a free variable:
        #
        # (function foo (a) (function (b) (+ a b)))
        #
        is_free_var = False
        function = self.current_function.enclosing_function
        while function:
            sym = function.lookup_local_variable(name)
            if sym:
                is_free_var = True
                break

            function = function.enclosing_function

        if is_free_var:
            # Create a new local variable to contain the value
            sym = self.current_function.reserve_local_variable(name)
            self.current_function.free_variables += [sym]

            # Determine where to capture this from in the source environment
            dest = sym
            func = self.current_function.enclosing_function
            while True:
                dest.closure_source = func.lookup_local_variable(name)
                if dest.closure_source:
                    break

                # The variable is from a function above this one, eg:
                # (function foo (a) (function bar (b) (function baz(c) (+ c a))))
                # In this example, we want to create a variable 'a' in the scope
                # of function b, so it is copied through properly. This is
                # named so, if there are subseqent uses of 'a', they will reference
                # the same variable.
                dest.closure_source = func.reserve_local_variable(name)
                func.free_variables += [dest.closure_source]
                dest = dest.closure_source
                func = func.enclosing_function

            return sym

        # Check if this is a global variable
        if name in self.globals:
            return self.globals[name]

        # Not found, create a new global variable implicitly
        sym = Symbol(Symbol.GLOBAL_VARIABLE)
        sym.index = len(self.globals)        # Allocate a storage slot for this
        self.globals[name] = sym
        return sym

    def compile(self, program):
        '''
        Top level compile function. All code not in function blocks will be
        emitted into an implicitly created dummy function 'main'
        '''
        self.current_function = Function()
        self.current_function.referenced = True
        self.current_function.name = 'main'

        # Create a built-in variable that indicates where the heap starts
        # (will be patched at the end of compilation with the proper address)
        # The code to patch this below assumes it is the first instruction
        # emitted.
        heapstart = self.lookup_symbol('$heapstart')
        heapstart.initialized = True

        # This is used during calls with closures. Code expects this variable
        # to be at address 1 (which it will be because it is the second global
        # variable that was created).
        closure_ptr = self.lookup_symbol('$closure')
        closure_ptr.initialized = True
        self.current_function.emit_instruction(OP_PUSH, 0)
        self.current_function.emit_instruction(OP_PUSH, heapstart.index)
        self.current_function.emit_instruction(OP_STORE)
        self.current_function.emit_instruction(OP_POP)

        for expr in program:
            if expr[0] == 'function':
                self.compile_function(expr)
            else:
                self.compile_expression(expr)
                self.current_function.emit_instruction(
                    OP_POP)  # Clean up stack

        # Call (halt) library call at end
        self.compile_identifier('halt')
        self.current_function.emit_instruction(OP_CALL)
        self.current_function.emit_instruction(OP_CLEANUP, 2)

        # main is the first function emitted, since that's where execution
        # will start
        self.function_list[0] = self.current_function

        # Strip out functions that aren't called
        self.function_list = [
            function for function in self.function_list if function.referenced]

        # Check for globals that are referenced but not used
        for var_name in self.globals:
            if not self.globals[var_name].initialized:
                print('unknown variable {}'.format(var_name))

        # Generate prologues and determine function addresses
        pc = 0
        for function in self.function_list:
            function.base_address = pc
            function.add_prologue()
            pc += function.get_size()

        self.code_length = pc

        # Fix up all unresolved references
        for function in self.function_list:
            function.apply_fixups()

        # Fix up the global variable size table. This assumes the push of the
        # size is the first instruction emitted above.
        self.function_list[0].patch(0, len(self.globals))

        # Generate instruction stream by flattening all generated functions
        instructions = []
        for function in self.function_list:
            instructions += function.prologue
            instructions += function.instructions

        # For debugging: create a list file with the disassembly
        with open('program.lst', 'w') as listfile:
            # Write out table of global variables
            listfile.write('Globals:\n')
            for var in self.globals:
                sym = self.globals[var]
                if sym.type != Symbol.FUNCTION:
                    listfile.write(' {} var@{}\n'.format(var, sym.index))

            disassemble(listfile, instructions, self.function_list)

        return instructions

    def compile_function(self, expr):
        '''
        Compile named function definition
        (function name (param param...) body)
        '''

        function = self.compile_function_body(expr[1], expr[2], expr[3:])
        self.function_list += [function]

        if expr[1] in self.globals:
            # There was a forward reference to this function and it was
            # assumed to be a global. We're kind of stuck with that now,
            # because code was generated that can't be easily fixed up.
            # Emit code to stash it in the global table.
            sym = self.globals[expr[1]]
            if sym.initialized:
                raise Exception('Global variable ' +
                                expr[1] + ' redefined as function')

            # Function address, to be fixed up
            self.current_function.emit_instruction(OP_PUSH, 0)
            self.current_function.add_fixup(function)

            # Global variable offset, to be fixed up
            self.current_function.emit_instruction(OP_PUSH, 0)
            self.current_function.add_fixup(sym)
            self.current_function.emit_instruction(OP_STORE)
            self.current_function.emit_instruction(OP_POP)
            sym.initialized = True
            function.referenced = True
        else:
            sym = Symbol(Symbol.FUNCTION)
            sym.initialized = True
            sym.function = function

        self.globals[expr[1]] = sym

    def compile_expression(self, expr, is_tail_call=False):
        '''
        The mother compile function, from which all useful things are compiled.
        Compiles an arbitrary lisp expression. Each expression consumes
        all parameters, which will be pushed onto the stack from right to left,
        and leave a result value on the stack. All expressions have values in LISP.

        Determining if something is a tail call is straightforward in
        S-Expression form. The outermost function call is a tail call.
        This may be wrapped in control flow form. If a sequence is outermost,
        the last function call will be a tail call.
        '''

        if isinstance(expr, list):
            if len(expr) == 0:
                # Empty expression
                self.current_function.emit_instruction(OP_PUSH, 0)
            else:
                self.compile_combination(expr, is_tail_call)
        elif isinstance(expr, int):
            self.compile_integer_literal(expr)
        elif expr[0] == '"':
            self.compile_string(expr[1:-1])
        elif expr == 'nil' or expr == 'false':
            self.current_function.emit_instruction(OP_PUSH, 0)
        elif expr == 'true':
            self.current_function.emit_instruction(OP_PUSH, 1)
        else:
            # This is a variable.
            self.compile_identifier(expr)

    def compile_integer_literal(self, expr):
        self.current_function.emit_instruction(OP_PUSH, expr)

    def compile_identifier(self, expr):
        '''
        Look up the variable in the current environment and push its value
        onto the stack.
        '''

        variable = self.lookup_symbol(expr)
        if variable.type == Symbol.LOCAL_VARIABLE:
            self.current_function.emit_instruction(OP_GETLOCAL,
                                                   variable.index)
        elif variable.type == Symbol.GLOBAL_VARIABLE:
            self.current_function.emit_instruction(OP_PUSH, 0)
            self.current_function.add_fixup(variable)
            self.current_function.emit_instruction(OP_LOAD)
        elif variable.type == Symbol.FUNCTION:
            variable.function.referenced = True
            self.current_function.emit_instruction(OP_PUSH, 0)
            self.current_function.add_fixup(variable)
        else:
            raise Exception(
                'internal error: symbol does not have a valid type', '')

    def compile_combination(self, expr, is_tail_call=False):
        '''
        A combination is a list expression (op param param...)
        This may be a special form (like if) or a function call.
        Anything that isn't an atom or a number will be compiled here.
        '''

        if isinstance(expr[0], str):
            function_name = expr[0]
            if function_name in self.PRIMITIVES:
                self.compile_primitive(expr)
            elif function_name == 'function':
                self.compile_anonymous_function(expr)
            elif function_name == 'begin':
                self.compile_sequence(expr[1:], is_tail_call)
            elif function_name == 'while':
                self.compile_while(expr)
            elif function_name == 'break':
                self.compile_break(expr)
            elif function_name == 'if':
                self.compile_if(expr, is_tail_call)
            elif function_name == 'assign':
                self.compile_assign(expr)
            elif function_name == 'quote':
                self.compile_quote(expr[1])
            elif function_name == 'let':
                self.compile_let(expr, is_tail_call)
            elif function_name == 'getbp':
                self.current_function.emit_instruction(OP_GETBP)
            elif function_name == 'and' or function_name == 'or' or function_name == 'not':
                self.compile_boolean_expression(expr)
            else:
                # Call to a user defined function.
                self.compile_function_call(expr, is_tail_call)
        else:
            self.compile_function_call(expr)

    def compile_quote(self, expr):
        '''
         Quoted expressions compile to a series of cons calls.
        '''

        if isinstance(expr, list):
            if len(expr) == 3 and expr[1] == '.':
                # This is a pair, which has special syntax: ( expr . expr )
                # Create a single cons cell for it.
                self.compile_quote(expr[2])
                self.compile_quote(expr[0])

                # Emit a call to the cons library function
                self.compile_identifier('cons')
                self.current_function.emit_instruction(OP_CALL)
                self.current_function.emit_instruction(OP_CLEANUP, 2)
            elif len(expr) == 0:
                # Empty list
                self.compile_integer_literal(0)
            else:
                # List, create a chain of cons calls
                self.compile_quoted_list(expr)
        elif isinstance(expr, int):
            self.compile_integer_literal(expr)
        else:
            self.compile_string(expr)

    def compile_quoted_list(self, tail):
        if len(tail) == 1:
            self.compile_integer_literal(0)
        else:
            # Do the tail first to avoid allocating a bunch of temporaries
            self.compile_quoted_list(tail[1:])

        self.compile_quote(tail[0])

        # Emit a call to the cons library function
        self.compile_identifier('cons')
        self.current_function.emit_instruction(OP_CALL)
        self.current_function.emit_instruction(OP_CLEANUP, 2)

    def compile_string(self, string):
        '''
        String literals compile to a cons call for each character, since
        there is not a native string type.
        '''

        if len(string) == 1:
            self.compile_integer_literal(0)
        else:
            self.compile_string(string[1:])

        self.compile_integer_literal(ord(string[0]))

        # Emit a call to the cons library function
        self.compile_identifier('cons')
        self.current_function.emit_instruction(OP_CALL)
        self.current_function.emit_instruction(OP_CLEANUP, 2)

    def compile_assign(self, expr):
        '''
        Set a variable (assign variable value)
        This will leave the value of the expression on the stack, since all
        expressions do that.
        '''

        variable = self.lookup_symbol(expr[1])
        if variable.type == Symbol.LOCAL_VARIABLE:
            self.compile_expression(expr[2])
            self.current_function.emit_instruction(OP_SETLOCAL, variable.index)
        elif variable.type == Symbol.GLOBAL_VARIABLE:
            self.compile_expression(expr[2])
            self.current_function.emit_instruction(OP_PUSH, 0)
            self.current_function.add_fixup(variable)
            self.current_function.emit_instruction(OP_STORE)
            variable.initialized = True
        elif variable.type == Symbol.FUNCTION:
            raise Exception('Error: cannot assign function ' + expr[1])
        else:
            raise Exception(
                'Internal error: what kind of variable is ' +
                expr[1] + '?', '')

    def compile_boolean_expression(self, expr):
        '''
        Compile a boolean expression that is not part of an conditional form like
        if or while. This will push the result (1 or 0) on the stack.
        '''

        false_label = Label()
        done_label = Label()
        self.compile_predicate(expr, false_label)
        self.current_function.emit_instruction(OP_PUSH, 1)
        self.current_function.emit_branch_instruction(OP_GOTO, done_label)
        self.current_function.emit_label(false_label)
        self.current_function.emit_instruction(OP_PUSH, 0)
        self.current_function.emit_label(done_label)

    def compile_predicate(self, expr, false_label):
        '''
        Compile a boolean expression that is part of a control flow expression.
        If the expression is false, this will jump to the label 'false_label', otherwise
        it will fall through. This performs short circuit evaluation where possible.
        '''

        if isinstance(expr, list):
            if expr[0] == 'and':
                if len(expr) < 2:
                    raise Exception('wrong number of arguments for and')

                # Short circuit if any condition is false
                for cond in expr[1:]:
                    self.compile_predicate(cond, false_label)

                return
            elif expr[0] == 'or':
                if len(expr) < 2:
                    raise Exception('wrong number of arguments for or')

                true_target = Label()
                for cond in expr[1:-1]:
                    test_next = Label()
                    self.compile_predicate(cond, test_next)
                    self.current_function.emit_branch_instruction(
                        OP_GOTO, true_target)
                    self.current_function.emit_label(test_next)

                # Final test short circuits to false target
                self.compile_predicate(expr[-1], false_label)
                self.current_function.emit_label(true_target)
                return
            elif expr[0] == 'not':
                if len(expr) != 2:
                    raise Exception('wrong number of arguments for not')

                skip_to = Label()
                self.compile_predicate(expr[1], skip_to)
                self.current_function.emit_branch_instruction(
                    OP_GOTO, false_label)
                self.current_function.emit_label(skip_to)
                return

        self.compile_expression(expr)
        self.current_function.emit_branch_instruction(OP_BFALSE, false_label)

    def compile_if(self, expr, is_tail_call=False):
        '''
        Conditional execution
        (if expr true [false])
        '''

        false_label = Label()
        done_label = Label()

        self.compile_predicate(expr[1], false_label)
        self.compile_expression(expr[2], is_tail_call)    # True clause
        self.current_function.emit_branch_instruction(OP_GOTO, done_label)
        self.current_function.emit_label(false_label)

        # False clause
        if len(expr) > 3:
            self.compile_expression(expr[3], is_tail_call)
        else:
            self.current_function.emit_instruction(OP_PUSH, 0)

        self.current_function.emit_label(done_label)

    def compile_while(self, expr):
        '''
        Loop construct
        (while condition body)
        That body is implitly a (begin... and can use a sequence
        If the loop terminates normally (the condition is false), the
        result is zero. If (break val) is called, 'val' will be the result.
        '''

        top_of_loop = Label()
        bottom_of_loop = Label()
        break_loop = Label()
        self.break_stack += [break_loop]
        self.current_function.emit_label(top_of_loop)
        self.compile_predicate(expr[1], bottom_of_loop)
        self.compile_sequence(expr[2:])
        self.current_function.emit_instruction(OP_POP)  # Clean up stack
        self.current_function.emit_branch_instruction(OP_GOTO, top_of_loop)
        self.current_function.emit_label(bottom_of_loop)
        self.break_stack.pop()
        self.current_function.emit_instruction(OP_PUSH, 0)    # Default value
        self.current_function.emit_label(break_loop)

    def compile_break(self, expr):
        '''
        break out of the current loop
        (break [value])
        '''

        label = self.break_stack[-1]
        if len(expr) > 1:
            self.compile_expression(expr[1])    # Push value on stack
        else:
            self.current_function.emit_instruction(OP_PUSH, 0)

        self.current_function.emit_branch_instruction(OP_GOTO, label)

    # Primitives look like function calls, but map to machine
    # instructions
    PRIMITIVES = {
        '+': (OP_ADD, 2),
        '-': (OP_SUB, 2),
        '>': (OP_GTR, 2),
        '>=': (OP_GTE, 2),
        '<': (-1, 2),    # These are handled by switching operand order
        '<=': (-1, 2),
        '=': (OP_EQ, 2),
        '<>': (OP_NEQ, 2),
        'load': (OP_LOAD, 1),
        'store': (OP_STORE, 2),
        'first': (OP_LOAD, 1),
        'rest': (OP_REST, 1),
        'second': (OP_REST, 1),    # Alias for rest
        'settag': (OP_SETTAG, 2),
        'gettag': (OP_GETTAG, 1),
        'bitwise-and': (OP_AND, 2),
        'bitwise-or': (OP_OR, 2),
        'bitwise-xor': (OP_XOR, 2),
        'rshift': (OP_RSHIFT, 2),
        'lshift': (OP_LSHIFT, 2)
    }

    def compile_primitive(self, expr):
        opcode, nargs = self.PRIMITIVES[expr[0]]

        if len(expr) - 1 != nargs:
            raise Exception('wrong number of arguments for', expr[0])

        # Synthesize lt and lte operators by switching order and using the
        # opposite operators
        if expr[0] == '<':
            self.compile_expression(expr[1])
            self.compile_expression(expr[2])
            self.current_function.emit_instruction(OP_GTR)
        elif expr[0] == '<=':
            self.compile_expression(expr[1])
            self.compile_expression(expr[2])
            self.current_function.emit_instruction(OP_GTE)
        else:
            if len(expr) > 2:
                self.compile_expression(expr[2])

            self.compile_expression(expr[1])
            self.current_function.emit_instruction(opcode)

    def compile_function_call(self, expr, is_tail_call=False):
        '''Call a function'''

        if isinstance(expr[0], int):
            raise Exception('Cannot use integer as function')

        # Push arguments
        for param_expr in reversed(expr[1:]):
            self.compile_expression(param_expr)

        if self.current_function.name == expr[0] and is_tail_call:
            # This is a recursive tail call. Copy parameters back into
            # frame and then jump to entry
            for opnum in range(len(expr) - 1):
                self.current_function.emit_instruction(OP_SETLOCAL, opnum + 1)
                self.current_function.emit_instruction(OP_POP)

            self.current_function.emit_branch_instruction(
                OP_GOTO, self.current_function.entry)
        else:
            is_closure_call = True
            if isinstance(expr[0], str):
                func = self.lookup_symbol(expr[0])
                if func.type == Symbol.FUNCTION:
                    is_closure_call = False

            self.compile_expression(expr[0])

            if is_closure_call:
                # Need to check if this is a closure or just a function
                self.current_function.emit_instruction(OP_DUP)
                self.current_function.emit_instruction(OP_GETTAG)
                not_closure = Label()
                self.current_function.emit_instruction(OP_PUSH, TAG_CLOSURE)
                self.current_function.emit_instruction(OP_EQ)
                self.current_function.emit_instruction(OP_BFALSE, 0)
                self.current_function.add_fixup(not_closure)

                # This is a closure, extract relevant parts. Store pointer to
                # environment at address 1, which is $closure.
                self.current_function.emit_instruction(OP_DUP)
                self.current_function.emit_instruction(OP_REST)  # read env
                self.current_function.emit_instruction(OP_PUSH, 1)  # $closure
                self.current_function.emit_instruction(OP_STORE)  # save
                self.current_function.emit_instruction(OP_POP)
                self.current_function.emit_instruction(
                    OP_LOAD)  # load function

                self.current_function.emit_label(not_closure)
                self.current_function.emit_instruction(OP_CALL)
                if len(expr) > 1:
                    self.current_function.emit_instruction(OP_CLEANUP,
                                                           len(expr) - 1)
            else:
                # Optimized function call
                self.current_function.emit_instruction(OP_CALL)
                if len(expr) > 1:
                    self.current_function.emit_instruction(
                        OP_CLEANUP, len(expr) - 1)

    def compile_function_body(self, name, params, body):
        '''
        Common code to compile body of the function definition (either anonymous or named)
        ((param param...) body)
        '''

        old_function = self.current_function
        new_function = Function()
        new_function.name = name
        new_function.enclosing_function = old_function
        self.current_function = new_function

        for index, param_name in enumerate(params):
            self.current_function.reserve_parameter(param_name, index)

        self.current_function.num_params = len(params)

        # Compile top level expression.
        self.compile_sequence(body, is_tail_call=True)
        self.current_function.emit_instruction(OP_RETURN)
        self.current_function = old_function

        return new_function

    def compile_anonymous_function(self, expr):
        '''
        Anonymous function
        (function (param param...) (expr))
        Generate the code in a separate global function, then emit a push
        of the reference to it in the current function.
        '''

        # Do an enter_scope because we may create temporary variables to
        # represent free variables while compiling. See lookup_symbol for more
        # information.
        self.current_function.enter_scope()
        new_function = self.compile_function_body(None, expr[1], expr[2:])
        new_function.referenced = True
        self.current_function.exit_scope()

        new_function.name = '<anonymous function>'

        # Compile reference to function into enclosing function
        if new_function.free_variables:
            # There are free variables. Compile code to create closure.
            # closure is a pair, with the first element being a pointer to the
            # function code (which is fixed up later) and the second being a list
            # of all free variables that need to be copied in the prologue of
            # the function.
            self.current_function.emit_instruction(OP_PUSH, TAG_CLOSURE)

            # Copy all of the closure variables into a list
            self.current_function.emit_instruction(OP_PUSH, 0)  # Delimeter
            for var in reversed(new_function.free_variables):
                self.current_function.emit_instruction(OP_GETLOCAL,
                                                       var.closure_source.index)
                # Append to list
                self.compile_identifier('cons')
                self.current_function.emit_instruction(OP_CALL)
                self.current_function.emit_instruction(OP_CLEANUP, 2)

            # Add function pointer
            self.current_function.emit_instruction(OP_PUSH, 0)
            self.current_function.add_fixup(new_function)

            # Create the pair of (funcaddr . valuelist)
            self.compile_identifier('cons')
            self.current_function.emit_instruction(OP_CALL)
            self.current_function.emit_instruction(OP_CLEANUP, 2)

            # Change the tag of this cons cell into a closure
            self.current_function.emit_instruction(OP_SETTAG)
        else:
            # No free variables
            self.current_function.emit_instruction(OP_PUSH, TAG_FUNCTION)
            self.current_function.emit_instruction(OP_PUSH, 0)
            self.current_function.add_fixup(new_function)
            self.current_function.emit_instruction(OP_SETTAG)

        self.function_list += [new_function]

    def compile_sequence(self, sequence, is_tail_call=False):
        '''
        A sequence of expressions. The result will be the last expression evaluated.
        (sequence stmt1 stmt2 ... stmtn)
        '''

        if len(sequence) == 0:
            self.current_function.emit_instruction(
                OP_PUSH, 0)  # Need to have at least one value
        else:
            for expr in sequence[:-1]:
                self.compile_expression(expr, is_tail_call=False)
                self.current_function.emit_instruction(
                    OP_POP)  # Clean up stack

            self.compile_expression(sequence[-1], is_tail_call)

    def compile_let(self, expr, is_tail_call=False):
        '''
        Reserve local variables and assign initial values to them.
        (let ((variable value) (variable value) (variable value)...) expr)
        '''

        # Reserve space on stack for local variables
        self.current_function.enter_scope()

        # Walk through each variable, define in scope, evaluate the initial value,
        # and assign.
        for variable, value in expr[1]:
            symbol = self.current_function.reserve_local_variable(variable)
            self.compile_expression(value)
            self.current_function.emit_instruction(OP_SETLOCAL, symbol.index)
            # Remove value setlocal left on stack
            self.current_function.emit_instruction(OP_POP)

        # Evaluate the predicate, which can be a sequence
        self.compile_sequence(expr[2:], is_tail_call)
        self.current_function.exit_scope()

OPTIMIZE_BINOPS = {
    '+': (lambda x, y: x + y),
    '-': (lambda x, y: x - y),
    '/': (lambda x, y: x // y),
    '*': (lambda x, y: x * y),
    'bitwise-and': (lambda x, y: x & y),
    'bitwise-or': (lambda x, y: x | y),
    'bitwise-xor': (lambda x, y: x ^ y),
    'lshift': (lambda x, y: x << y),
    'rshift': (lambda x, y: x >> y),
    '>': (lambda x, y: 1 if x > y else 0),
    '>=': (lambda x, y: 1 if x >= y else 0),
    '<': (lambda x, y: 1 if x < y else 0),
    '<=': (lambda x, y: 1 if x <= y else 0),
    '=': (lambda x, y: 1 if x == y else 0),
    '<>': (lambda x, y: 1 if x != y else 0)
}

OPTIMIZE_UOPS = {
    'bitwise-not': (lambda x: ~x),
    '-': (lambda x: -x),
    'not': (lambda x: 1 if x else 0)
}


def is_power_of_two(x):
    return (x & (x - 1)) == 0


def make_legal_constant(x):
    x &= 0xffff
    if x & 0x8000:
        return -((~x + 1) & 0xffff)
    else:
        return x


def optimize(expr):
    '''
    Optimize the S-Expression program, performing transforms like constant
    folding, constant conditional folding, and strength reduction.
    '''

    if isinstance(expr, list) and len(expr) > 0:
        if expr[0] == 'quote':
            return expr  # Don't optimize things in quotes
        else:
            # Fold arithmetic expressions if possible
            optimized_params = [optimize(subexpr) for subexpr in expr[1:]]
            if not isinstance(expr[0], list) and \
                    expr[0] in OPTIMIZE_BINOPS and \
                    len(expr) == 3 and \
                    isinstance(optimized_params[0], int) and \
                    isinstance(optimized_params[1], int):
                return make_legal_constant(
                    OPTIMIZE_BINOPS[
                        expr[0]](optimized_params[0], optimized_params[1]))

            if not isinstance(expr[0], list) and expr[0] in OPTIMIZE_UOPS and \
                    len(expr) == 2 and \
                    isinstance(optimized_params[0], int):
                return make_legal_constant(
                    OPTIMIZE_UOPS[expr[0]](optimized_params[0]))

            # If any parameters are constant 0, the whole thing is zero
            if expr[0] == 'and':
                all_ones = True
                for param in optimized_params:
                    if isinstance(param, int):
                        if param == 0:
                            return 0
                    else:
                        all_ones = False

                if all_ones:
                    return 1

                # Could not optimize
                return [expr[0]] + optimized_params

            # If any parameters are constant 1, the whole thing is 1
            if expr[0] == 'or':
                all_zeroes = True
                for param in optimized_params:
                    if isinstance(param, int):
                        if param != 0:
                            return 1
                    else:
                        all_zeroes = False

                if all_zeroes:
                    return 0

                # Could not optimize
                return [expr[0]] + optimized_params

            # If a conditional form has a constant expression, include only the
            # appropriate clause
            if not isinstance(expr[0], list) and expr[0] == 'if' \
                    and isinstance(optimized_params[0], int):
                if optimized_params[0] != 0:
                    return optimized_params[1]
                elif len(optimized_params) > 2:
                    return optimized_params[2]
                else:
                    return 0    # Did not have an else, this is an empty expression

            # Strength reduction for power of two multiplies and divides
            if len(optimized_params) > 1 and isinstance(
                    optimized_params[1], int) and is_power_of_two(
                    optimized_params[1]) and optimized_params[1] > 0 and (
                    expr[0] == '*' or expr[0] == '/'):
                return ['lshift' if expr[0] == '*' else 'rshift',
                        optimized_params[0], int(math.log(int(optimized_params[1]), 2))]

            # Nothing to optimize, return the expression as is
            return [expr[0]] + optimized_params
    else:
        return expr

#
# For debugging
#

# name, hasparam
DISASM_TABLE = {
    OP_NOP: ('nop', False),
    OP_CALL: ('call', False),
    OP_RETURN: ('return', False),
    OP_CLEANUP: ('cleanup', True),
    OP_POP: ('pop', False),
    OP_ADD: ('add', False),
    OP_SUB: ('sub', False),
    OP_PUSH: ('push', True),
    OP_LOAD: ('load', False),
    OP_STORE: ('store', False),
    OP_GETLOCAL: ('getlocal', True),
    OP_SETLOCAL: ('setlocal', True),
    OP_GOTO: ('goto', True),
    OP_BFALSE: ('bfalse', True),
    OP_REST: ('rest', False),
    OP_RESERVE: ('reserve', True),
    OP_GTR: ('gtr', False),
    OP_GTE: ('gte', False),
    OP_EQ: ('eq', False),
    OP_NEQ: ('neq', False),
    OP_DUP: ('dup', False),
    OP_GETTAG: ('gettag', False),
    OP_SETTAG: ('settag', False),
    OP_AND: ('and', False),
    OP_OR: ('or', False),
    OP_XOR: ('xor', False),
    OP_LSHIFT: ('lshift', False),
    OP_RSHIFT: ('rshift', False),
    OP_GETBP: ('getbp', False)
}


def disassemble(outfile, instructions, functions):
    next_function_start = functions[0].base_address
    func_index = 0

    for pc, word in enumerate(instructions):
        if pc == next_function_start:
            outfile.write('\n{}:\n'.format(functions[func_index].name))
            func_index += 1
            if func_index == len(functions):
                next_function_start = 0xffffffff
            else:
                next_function_start = functions[func_index].base_address

        outfile.write('    {:04d}    '.format(pc))
        opcode = (word >> 16) & 0x1f
        name, has_param = DISASM_TABLE[opcode]
        if has_param:
            param_value = word & 0xffff
            if param_value & 0x8000:
                param_value = -(((param_value ^ 0xffff) + 1) & 0xffff)

            outfile.write('{} {}\n'.format(name, param_value))
        else:
            outfile.write('{}\n'.format(name))


def pretty_print_sexpr(listfile, expr, indent=0):
    if isinstance(expr, list):
        if len(expr) > 0 and expr[0] == 'function':
            listfile.write('\n')

        listfile.write('\n')
        listfile.write('  ' * indent)

        listfile.write('(')
        for elem in expr:
            if elem != expr[0]:
                listfile.write(' ')

            pretty_print_sexpr(listfile, elem, indent + 1)

        listfile.write(')')
    else:
        listfile.write(str(expr))


class MacroProcessor(object):
    '''
    The macro processor is a small lisp interpreter
    Evaluate macro expressions with their arguments as parameters, insert
    the result into the expression list.
    '''

    def __init__(self):
        self.macro_list = {}

    def expand_backquote(self, expr, env):
        if isinstance(expr, list):
            if expr[0] == 'unquote':
                # This gets evaluated regularly
                return self.eval(expr[1], env)
            else:
                return [self.expand_backquote(term, env) for term in expr]
        else:
            return expr

    def eval(self, expr, env):
        if isinstance(expr, list):
            function = expr[0]
            if function == 'first':
                return self.eval(expr[1], env)[0]
            elif function == 'rest':
                return self.eval(expr[1], env)[1]
            elif function == 'if':        # (if test trueexpr falsexpr)
                if self.eval(expr[1], env):
                    return self.eval(expr[2], env)
                elif len(expr) > 3:
                    return self.eval(expr[3], env)
                else:
                    return 0
            elif function == 'assign':    # (assign var value)
                env[expr[1]] = self.eval(expr[2], env)
            elif function == 'list':
                return [self.eval(element, env) for element in expr[1:]]
            elif function == 'quote':
                return expr[1]
            elif function == 'backquote':
                return self.expand_backquote(expr[1], env)
            elif function == 'cons':
                return [self.eval(expr[1], env)] + [self.eval(expr[2], env)]
            elif function in OPTIMIZE_BINOPS:
                return OPTIMIZE_BINOPS[function](
                    self.eval(
                        expr[1], env), self.eval(
                        expr[2], env))
            elif function in self.macro_list:
                # Invoke a sub-macro
                new_env = copy.copy(env)
                arg_list, body = self.macro_list[expr[0]]
                for name, value in zip(arg_list, expr[1:]):
                    new_env[name] = value

                return self.eval(body, new_env)
            else:
                # Call a function. We can't really define functions yet, so
                # stubbed out for now.
                # Func is (function (arg arg arg) body)
                function = env[expr[0]]
                if function is None or not isinstance(function, list) or \
                        function[0] != 'function':
                    raise Exception(
                        'bad function call during macro expansion', '')
                for name, value in zip(function[0], expr[1:]):
                    env[name] = self.eval(value, env)

                return self.eval(function[1], env)
        elif isinstance(expr, int):
            return expr
        else:
            return env[expr]

    def macro_pre_process(self, program):
        updated_program = []
        for statement in program:
            if isinstance(statement, list) and statement[0] == 'defmacro':
                # (defmacro <name> (arg list) replace)
                self.macro_list[statement[1]] = (statement[2], statement[3])
            else:
                updated_program += [self.macro_expand_recursive(statement)]

        return updated_program

    def macro_expand_recursive(self, statement):
        if isinstance(statement, list) and len(statement) > 0:
            if not isinstance(statement[0], list) and statement[
                    0] in self.macro_list:
                # This is a macro form. Evalute the macro now and replace this form with
                # the result.
                arg_names, body = self.macro_list[statement[0]]
                if len(arg_names) != len(statement) - 1:
                    print('warning: macro expansion of {} has the wrong number of arguments'.format(
                        statement[0]))
                    print('expected {} got {}:'.format(
                        len(arg_names), len(statement) - 1))
                    for arg in statement[1:]:
                        print(arg)

                env = {}
                for name, value in zip(arg_names, statement[1:]):
                    env[name] = self.macro_expand_recursive(value)

                return self.eval(body, env)
            else:
                return [self.macro_expand_recursive(
                    term) for term in statement]
        else:
            return statement


def compile_program(files):
    parser = Parser()

    # Read standard runtime library
    parser.parse_file('runtime.lisp')

    # Read source files
    for filename in files:
        parser.parse_file(filename)

    macro = MacroProcessor()
    expanded = macro.macro_pre_process(parser.program)

    optimized = [optimize(sub) for sub in expanded]

    compiler = Compiler()
    code = compiler.compile(optimized)

    with open('program.hex', 'w') as outfile:
        for instr in code:
            outfile.write('{:06x}\n'.format(instr))

compile_program(sys.argv[1:])

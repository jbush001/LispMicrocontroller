#!/usr/bin/python
#
# Copyright 2011-2016 Jeff Bush
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

"""Read LISP source files and compile to binary machine code.

 ./compile.py <source file 1> [<source file 2>] ...

Output file is 'program.hex', which contains the hexadecimal encoded
instruction memory, starting at address 0. Each entry in the hex file
is a 16 bit value value, separated with a newline.
"""

import copy
import math
import os
import re
import shlex
import sys

# 2 bits associated with each data memory location, stored in hardware
# to indicate its type.
TAG_INTEGER = 0  # Make this zero because types default to this when pushed
TAG_CONS = 1
TAG_FUNCTION = 2
TAG_CLOSURE = 3

# Upper 5 bits in each instruction that indicates the operation.
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


class CompileError(Exception):
    pass


class Symbol(object):
    """What an identifier refers to."""
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
    """Placeholder for a branch destination."""

    def __init__(self):
        self.defined = False
        self.offset = 0


class Function(object):
    """This is a builder pattern that is used while generating code for a function.

    The compiler can call into this to append instructions to a function.
    Because of anonymous inner functions, there can be several functions being
    built at once. This contains both the raw instructions themselves, as well as
    symbol information and fixups.
    """

    def __init__(self, name):
        self.name = name
        self.fixups = []
        self.base_address = None
        self.num_local_variables = 0
        self.prologue = None
        self.instructions = []
        self.environment = [{}]         # Stack of scopes
        self.free_variables = []
        self.enclosing_function = None
        self.referenced = False         # Used to strip dead functions
        self.referenced_funcs = []
        self.entry = Label()
        self.emit_label(self.entry)

    def enter_scope(self):
        """Start a new region of code where local variables are live."""
        self.environment.append({})

    def exit_scope(self):
        """Any local variables defined in the previous scope are no longer live."""
        self.environment.pop()

    def lookup_local_variable(self, name):
        """Attempt to find a local variable visible at the current code location.

        This will start with the current scope, then walk outward to enclosing
        scopes. This means variables with the same name in inner scopes can
        shadow outer ones. This will also found closure variables outside
        of a function, which will be handled specially later.

        Args:
            name (str): Human readable identifier

        Returns:
            Symbol corresponding to identifier or None
        """
        for scope in reversed(self.environment):
            if name in scope:
                return scope[name]

        return None

    def reserve_local_variable(self, name):
        """Allocate space for a local variable.

        We also record the identifier in the inner-most scope.

        Args:
            name (str): Human readable identifier

        Returns:
            Symbol object corresponding to location.
        """

        sym = Symbol(Symbol.LOCAL_VARIABLE)
        self.environment[-1][name] = sym
        # Skip return address and base pointer
        sym.index = -(self.num_local_variables + 2)
        self.num_local_variables += 1
        return sym

    def set_param(self, name, index):
        """Record information about a paramter to this function.

        Args:
            name (str): Human readable identifier used to access
              the contents from within the function.
            index (int): Offset in the stack frame used to find
              the value of this parameter, passed from caller.
        """
        sym = Symbol(Symbol.LOCAL_VARIABLE)
        self.environment[-1][name] = sym
        sym.index = index + 1

    def emit_label(self, label):
        """Set the instruction address of a label.

        The address of this label will be set to the *next* instruction to be
        emitted. During later fixups, all instructions that reference this
        label will be adjusted to point here.
        The label will already have been created, and may already have been
        used as a forward branch target.

        Args:
            label (Label): the label to assign to this location.
        """
        assert not label.defined
        label.defined = True
        label.offset = len(self.instructions)

    def emit_branch_instruction(self, opcode, label):
        """Append a branch instruction to the end of the function.

        Args:
            opcode (int): opcode of the branch instruction (e.g.
               conditional vs. unconditional)
            label (Label): destination of the branch.
        """
        self.emit_instruction(opcode, 0)
        self.add_fixup(label)

    def emit_instruction(self, opcode, param=0):
        """Append an instruction to the end of this function.

        Args:
            opcode (int): Upper 5 bits of instruction that indicate the
              operation.
            param: Lower 16 bits of instruction.
        """
        if param > 32767 or param < -32768:
            raise CompileError('param out of range ' + str(param))

        self.instructions.append((opcode << 16) | (param & 0xffff))

    def add_prologue(self):
        """Emit code that is executed at the top of the function.

        This code is invoked immediately after a function is called, before
        any of the user defined code. It includes basic local variable setup
        and some bookkeeping for closures.
        """
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
                prologue.append((OP_SETLOCAL << 16) |
                                (var.index & 0xffff))  # save
                prologue.append(OP_POP << 16)

        self.prologue = prologue

    def get_size(self):
        """Return the current number of instructions in this function."""
        return len(self.prologue) + len(self.instructions)

    def add_fixup(self, target):
        """Record instruction reference to memory location for later patching.

        This remembers that the last emitted instruction should have its
        data field adjusted later to point to 'target'. This can't always
        be done immediately because it may be a forward reference.

        Args:
            target (Label|Function|Symbol): memory location reference.
        """
        self.fixups.append((len(self.instructions) - 1, target))

    def patch(self, offset, value):
        """Update instruction to point to a memory location.

        Change the immediate field of the instruction, leaving its opcode
        unmodified.

        Args:
            offset (int): index of the instruction, starting after the prologue
            value (int): new value for immediate field
        """
        self.instructions[offset] &= ~0xffff
        self.instructions[offset] |= (value & 0xffff)

    def apply_fixups(self):
        """Update all memory references in instructions in this function.

        Walk through all previously recorded calls to add_fixup and adjust
        the instructions to point to the proper targets. These *should*
        all be known at this point, as the labels will have been emitted,
        but, if not, this will raise an exception (which would indicate a bug
        in this code).
        """
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
                raise CompileError(
                    'internal error: unknown fixup type ' + target.__name__)

    def mark_callees(self):
        """Recursively mark all functions called indirectly or directly by this one.

        This ensures they won't be removed by dead code stripping. The
        reference list contains either functions (for anonymous functions
         or declared functions) or symbols (for forward references)
        """
        self.referenced = True
        for ref in self.referenced_funcs:
            if isinstance(ref, Symbol):
                function = ref.function
            else:
                function = ref

            if not function.referenced:
                function.mark_callees()

class Parser(object):
    """Convert text LISP source into a nested set of python lists."""

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
            self.lexer.wordchars += '?+<>!@#$%^&*;:.=-_\\'

            while True:
                expr = self.parse_expr()
                if expr == '':
                    break

                self.program.append(expr)

    def parse_paren_list(self):
        parenlist = []
        while True:
            lookahead = self.lexer.get_token()
            if lookahead == '':
                raise CompileError('missing )')
            elif lookahead == ')':
                break

            self.lexer.push_token(lookahead)
            parenlist.append(self.parse_expr())

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
            raise CompileError('unmatched )')
        elif token[:2] == '#\\': # character code
            if token[2:] == 'newline':
                return ord('\n')
            elif token[2:] == 'space':
                return ord(' ')
            else:
                return ord(token[2])
        else:
            return token


class Compiler(object):

    def __init__(self):
        self.globals = {}
        self.next_global_slot = 0
        self.current_function = None
        self.function_list = []
        self.break_stack = []

    def lookup_symbol(self, name):
        """Given an identifier, find its type and where it's stored.

        Start lookup in the current scope and works outward to enclosing
        scopes. If the symbol doesn't exist, create it in the global scope.
        If it is defined outside the current function closure, there is a
        bunch of extra accounting to do.

        Args:
            name (string): human readable symbol text

        Returns:
            Symbol object.
        """
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
            self.current_function.free_variables.append(sym)

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
                func.free_variables.append(dest.closure_source)
                dest = dest.closure_source
                func = func.enclosing_function

            return sym

        # Check if this is a global variable
        if name in self.globals:
            return self.globals[name]

        # Not found, create a new global variable implicitly
        sym = Symbol(Symbol.GLOBAL_VARIABLE)
        sym.index = self.next_global_slot
        self.next_global_slot += 1
        self.globals[name] = sym
        return sym

    def compile(self, program):
        """Convert the entire program into machine code.

        All code not in function blocks will be emitted into an implicitly
        created dummy function 'main'
        """
        self.current_function = Function('main')
        self.function_list.append(self.current_function)

        # Create a built-in variable that indicates where the heap starts
        # (will be patched at the end of compilation with the proper address)
        # The code to patch this below assumes it is the first instruction
        # emitted.
        heapstart = self.lookup_symbol('$heapstart')
        heapstart.initialized = True
        self.current_function.emit_instruction(OP_PUSH, 0)
        self.current_function.emit_instruction(OP_PUSH, heapstart.index)
        self.current_function.emit_instruction(OP_STORE)
        self.current_function.emit_instruction(OP_POP)

        # This is used during calls with closures. Code expects this variable
        # to be at address 1 (which it will be because it is the second global
        # variable that was created).
        closure_ptr = self.lookup_symbol('$closure')
        closure_ptr.initialized = True

        # Do a pass to register all functions in the global scope. This is
        # necessary to avoid creating these symbols as global variables
        # when there are forward references.
        for expr in program:
            if expr[0] == 'function':
                self.globals[expr[1]] = Symbol(Symbol.FUNCTION)

        # Compile
        for expr in program:
            if expr[0] == 'function':
                self.compile_function(expr)
            else:
                self.compile_expression(expr)
                self.current_function.emit_instruction(OP_POP) # Clean up stack

        # Call (halt) library call at end
        self.compile_identifier('halt')
        self.current_function.emit_instruction(OP_CALL)
        self.current_function.emit_instruction(OP_CLEANUP, 2)

        # Strip out functions that aren't called
        self.current_function.mark_callees()
        self.function_list = [
            function for function in self.function_list if function.referenced]

        # Check for globals that are referenced but not assigned
        for name, sym in self.globals.items():
            if not sym.initialized:
                raise CompileError('unknown variable {}'.format(name))

        # Generate prologues and determine function addresses
        pc = 0
        for function in self.function_list:
            function.base_address = pc
            function.add_prologue()
            pc += function.get_size()

        # Fix up all references
        for function in self.function_list:
            function.apply_fixups()

        # Patch $heapsize now that we know the number of global variables.
        # This assumes the push of the size is the first instruction emitted
        # above.
        self.function_list[0].patch(0, len(self.globals))

        # Flatten all generated instructions into an array
        instructions = []
        for function in self.function_list:
            instructions += function.prologue
            instructions += function.instructions

        with open('program.hex', 'w') as outfile:
            for instr in instructions:
                outfile.write('{:06x}\n'.format(instr))

        # For debugging: create a list file with the disassembly
        with open('program.lst', 'w') as listfile:
            # Write out table of global variables
            listfile.write('Globals:\n')
            for var in sorted(self.globals, key=lambda key: self.globals[key].index):
                sym = self.globals[var]
                if sym.type != Symbol.FUNCTION:
                    listfile.write(' {:4d} {} \n'.format(sym.index, var))

            disassemble(listfile, instructions, self.function_list)

    def compile_function(self, expr):
        """Compile named function definition.

        These are only supported in the global scope.
        (function name (param param...) body)

        Args:
            expr (List): List containing the S-expr
        """
        function = self.compile_function_body(expr[1], expr[2], expr[3:])
        self.function_list.append(function)

        assert expr[1] in self.globals  # Added by first pass
        sym = self.globals[expr[1]]
        if sym.initialized:
            raise CompileError('Global variable {} redefined as function'
                               .format(expr[1]))

        sym.initialized = True
        sym.function = function

    def compile_expression(self, expr, is_tail_call=False):
        """The mother code generation function.

        Compiles an arbitrary lisp expression. Each expression consumes
        all parameters--which are pushed onto the stack from right to left--
        and leaves a result value on the stack. All expressions have values in LISP.

        Determining if something is a tail call is straightforward in
        S-Expression form. The outermost function call is a tail call.
        This may be wrapped in control flow form. If a sequence is outermost,
        the last function call will be a tail call.

        Args:
            expr (List): List containing the S-expr
            is_tail_call (bool): True if there are no other expressions evaluated
              after this one before returning from the function.
        """
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
        """Look up variable and emit code to push its value onto the stack.

        Args:
            expr (str): Human readable of the variable to reference
        """
        variable = self.lookup_symbol(expr)
        if variable.type == Symbol.LOCAL_VARIABLE:
            self.current_function.emit_instruction(OP_GETLOCAL,
                                                   variable.index)
        elif variable.type == Symbol.GLOBAL_VARIABLE:
            self.current_function.emit_instruction(OP_PUSH, 0)
            self.current_function.add_fixup(variable)
            self.current_function.emit_instruction(OP_LOAD)
        elif variable.type == Symbol.FUNCTION:
            self.current_function.referenced_funcs.append(variable)
            self.current_function.emit_instruction(OP_PUSH, 0)
            self.current_function.add_fixup(variable)
        else:
            raise CompileError(
                'internal error: symbol {} does not have a valid type'
                .format(expr))

    def compile_combination(self, expr, is_tail_call=False):
        """Compile a list expression (op param param...).

        This may be a special form (like if) or a function call.
        Any expression that isn't an atom or a number will be compiled here.
        Args:
            expr (List): List containing the S-expr
            is_tail_call (bool): True if there are no other expressions evaluated
              after this one before returning from the function.
        """
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
            elif function_name == 'list':
                self.compile_list(expr)
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

    def compile_list(self, expr):
        """Emit code to construct a literal list

        Args:
            expr (List): list of expression values
        """
        for value in reversed(expr[1:]):
            self.compile_expression(value)

            # Emit a call to the cons library function
            self.compile_identifier('cons')
            self.current_function.emit_instruction(OP_CALL)
            self.current_function.emit_instruction(OP_CLEANUP, 2)

    def compile_quote(self, expr):
        """Convert quoted expression to a series of cons calls.

        Args:
            expr (List|int|str): literal value to be quoted.
        """
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
        """Convert string literal to a cons call for each character

        There isn't not a native string type.

        Args:
            string (str): literal to be encoded.
        """
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
        """Emit code to write to a variable (assign variable value).

        This will leave the value of the expression on the stack, since all
        expressions do that.

        Args:
            expr (List): List containing the S-expr
        """
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
            raise CompileError('cannot assign function {}'.format(expr))
        else:
            raise CompileError(
                'Internal error: what kind of variable is {}?'.format(expr[1]))

    def compile_boolean_expression(self, expr):
        """Compile boolean expression (and, or, not) that stores value on stack.

        This is not used for conditional form like if or while. This will push
        the result (1 or 0) on the stack.

        Args:
            expr (List): List containing the S-expr

        """
        false_label = Label()
        done_label = Label()
        self.compile_predicate(expr, false_label)
        self.current_function.emit_instruction(OP_PUSH, 1)
        self.current_function.emit_branch_instruction(OP_GOTO, done_label)
        self.current_function.emit_label(false_label)
        self.current_function.emit_instruction(OP_PUSH, 0)
        self.current_function.emit_label(done_label)

    def compile_predicate(self, expr, false_label):
        """Compile boolean expression that is part of a control flow expression.

        If the expression is false, this will jump to the label 'false_label',
        otherwise it will fall through. This performs short circuit evaluation
        where possible.

        Args:
            expr (List): List containing the S-expr
            false_label (Label): Where to jump to if express is false.
        """
        if isinstance(expr, list):
            if expr[0] == 'and':
                if len(expr) < 2:
                    raise CompileError('two few arguments for and')

                # Short circuit if any condition is false
                for cond in expr[1:]:
                    self.compile_predicate(cond, false_label)

                return
            elif expr[0] == 'or':
                if len(expr) < 2:
                    raise CompileError('two few arguments for or')

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
                    raise CompileError('two few arguments for not')

                skip_to = Label()
                self.compile_predicate(expr[1], skip_to)
                self.current_function.emit_branch_instruction(
                    OP_GOTO, false_label)
                self.current_function.emit_label(skip_to)
                return

        self.compile_expression(expr)
        self.current_function.emit_branch_instruction(OP_BFALSE, false_label)

    def compile_if(self, expr, is_tail_call=False):
        """Compile conditional branch.

        (if expr true [false])

        Args:
            expr (List): List containing the S-expr
            is_tail_call (bool): True if there are no other expressions evaluated
              after this one before returning from the function.
        """
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
        """Compile loop.

        That body is implicitly a (begin... and can use a sequence
        If the loop terminates normally (the condition is false), the
        result is zero. If (break val) is called, 'val' will be the result.

        (while condition body)

        Args:
            expr (List): List containing the S-expr
        """
        top_of_loop = Label()
        bottom_of_loop = Label()
        break_loop = Label()
        self.break_stack.append(break_loop)
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
        """Emit instruction to jump past the end of the current loop body.

        (break [value])

        Args:
            expr (List): List containing the S-expr
        """
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
            raise CompileError('wrong number of arguments for {}'.format(expr[0]))

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
        """Emit code to call a function.

        Args:
            expr (List): List containing the S-expr
            is_tail_call (bool): True if there are no other expressions evaluated
              after this one before returning from the function.
        """
        if isinstance(expr[0], int):
            raise CompileError('Cannot use integer as function')

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
            may_be_closure = True
            if isinstance(expr[0], str):
                func = self.lookup_symbol(expr[0])
                if func.type == Symbol.FUNCTION:
                    may_be_closure = False

            self.compile_expression(expr[0])

            if may_be_closure:
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
        """Common code to compile body function definition.

        This can be either anonymous or named.
        ((param param...) body)

        Args:
            name (str): Human readable identifier of function.
            params (List): A list of all parameter identifiers.
            body (List): S-Expression of the code to execute in the function.

        Returns:
            new Function object.
        """
        old_function = self.current_function
        new_function = Function(name)
        new_function.enclosing_function = old_function
        self.current_function = new_function

        for index, param_name in enumerate(params):
            self.current_function.set_param(param_name, index)

        # Compile top level expression.
        self.compile_sequence(body, is_tail_call=True)
        self.current_function.emit_instruction(OP_RETURN)
        self.current_function = old_function

        return new_function

    def compile_anonymous_function(self, expr):
        """Compile unnamed function.

        Generate the code in a separate global function (lambda lifting),
        then emit a push of the reference to it in the current function.

        (function (param param...) (expr))

        Args:
            expr (List): List containing the S-expr
        """
        # Do an enter_scope because we may create temporary variables to
        # represent free variables while compiling. See lookup_symbol for more
        # information.
        self.current_function.enter_scope()
        new_function = self.compile_function_body('<anonymous function>', expr[1], expr[2:])
        self.current_function.exit_scope()
        self.current_function.referenced_funcs.append(new_function)

        # Compile reference to function into enclosing function
        if new_function.free_variables:
            # There are free variables. Compile code to create closure.
            # closure is a pair, with the first element being a pointer to the
            # function code (which is fixed up later) and the second being a list
            # of all free variables that need to be copied in the prologue of
            # the function.
            self.current_function.emit_instruction(OP_PUSH, TAG_CLOSURE)

            # Copy all of the closure variables into a list
            self.current_function.emit_instruction(OP_PUSH, 0)  # Delimiter
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
            # No free variables. Marking this as a function is an
            # optimization that avoids extra setup during the function
            # call.
            self.current_function.emit_instruction(OP_PUSH, TAG_FUNCTION)
            self.current_function.emit_instruction(OP_PUSH, 0)
            self.current_function.add_fixup(new_function)
            self.current_function.emit_instruction(OP_SETTAG)

        self.function_list.append(new_function)

    def compile_sequence(self, sequence, is_tail_call=False):
        """A list of expressions to evaluate in order.

        The value of this expression as a whole will be the last
        expression evaluated.

        (sequence stmt1 stmt2 ... stmtn)

        Args:
            expr (List): List containing the S-expr
            is_tail_call (bool): True if there are no other expressions evaluated
              after this one before returning from the function.
        """
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
        """ Create a new scope and allocate local variables

        This also emits code to assign initial values.

        (let ((variable value) (variable value) (variable value)...) expr)

        Args:
            expr (List): List containing the S-expr
            is_tail_call (bool): True if there are no other expressions evaluated
              after this one before returning from the function.
        """
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


def is_power_of_two(i):
    return (i & (i - 1)) == 0


def make_legal_constant(i):
    i &= 0xffff
    if i & 0x8000:
        return -((~i + 1) & 0xffff)
    else:
        return i


def optimize(expr):
    """Optimize the program in S-Expression list format.

    Perform transforms like constant folding, constant conditional folding,
    and strength reduction to improve performance and reduce size.

    Args:
        expr (List): List containing the S-expr

    Returns:
        The optimized S-Expr.
    """
    if isinstance(expr, list) and len(expr) > 0:
        if expr[0] == 'quote':
            return expr  # Don't optimize quoted elements
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

CADR_RE = re.compile('c[ad]+r')

def expand_cadr(expr):
    """Expand shortand for car and cdr calls.

    Scheme encodes sequences of car and cdr calls where the intermediate
    letters represent each operation. Expand into proper calls
    here (we use first and rest);

    (cadadr foo) => (car (cdr (car (cdr foo))))

    Args:
        expr (List): List containing the S-expr

    Returns:
        A new S-Expr.
    """
    if isinstance(expr, list) and len(expr) > 0:
        name = expr[0]
        if name == 'quote':
            return expr  # Don't mess with quoted lists

        mutated = [expand_cadr(param) for param in expr[1:]]
        if isinstance(name, str) and CADR_RE.search(name):
            if name[-2] == 'a':
                mutated = ['first'] + mutated
            else:
                mutated = ['rest'] + mutated

            for letter in reversed(name[1:-2]):
                if letter == 'a':
                    mutated = ['first'] + [mutated]
                else:
                    mutated = ['rest'] + [mutated]
        else:
            mutated.insert(0, name)

        return mutated
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
    """Given binary instructions, convert back readable assembly format.

    This is useful for debugging.

    Args:
        outfile (File): file handle to write to
        instructions (List<int>): a list of integers representing instruction values
        functions (List): list of instruction start addresses, used to make the
           output more readable.
    """
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
    """Expand macros at compile time.

    The macro processor is a small lisp interpreter.
    Evaluate macro expressions with their arguments as parameters, insert
    the result into the expression list.
    """
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
                    raise CompileError(
                        'bad function call {} during macro expansion'
                        .format(expr[0]))
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
                updated_program.append(self.macro_expand_recursive(statement))

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
    """Top level compiler.

    This loads the runtime library (written in LISP), then walks through the
    given files and assembles them all into a single program.

    Args:
        files (List<str>): List of filenames to read and compile.
    """
    parser = Parser()

    # Read standard runtime library
    parser.parse_file(os.path.dirname(os.path.abspath(__file__)) + '/runtime.lisp')

    # Read source files
    for filename in files:
        parser.parse_file(filename)

    passes = [
        expand_cadr,
        lambda program: MacroProcessor().macro_pre_process(program),
        lambda program: [optimize(sub) for sub in program]
    ]

    program = parser.program
    for passfn in passes:
        program = passfn(program)

    Compiler().compile(program)

try:
    compile_program(sys.argv[1:])
except CompileError as ex:
    print('Compile error: ' + str(ex))
    sys.exit(1)

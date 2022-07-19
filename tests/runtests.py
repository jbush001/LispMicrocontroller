#!/usr/bin/env python3
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

import os
import subprocess
import sys

TEST_DIR = os.path.normpath(os.path.dirname(os.path.abspath(__file__)))
PROJECT_ROOT = os.path.join(TEST_DIR, '..')

POSITIVE_TESTS = [
    # Basic Compiler/Interpreter tests
    'hello.lisp',
    'scope.lisp',
    'math.lisp',
    'optimizer.lisp',
    'conditionals.lisp',
    'list.lisp',
    'closure.lisp',
    'tail-recurse.lisp',
    'anonfunc.lisp',
    'forloop.lisp',
    'breakloop.lisp',
    'getbp_bug.lisp',
    'sequence.lisp',

    # Runtime library tests
    'map-reduce.lisp',
    'filter.lisp',
    'gc.lisp',
    'oom.lisp',

    # Sample programs
    'y-combinator.lisp',
    'sum-even-fib.lisp',
    'zip.lisp',
    'anagram.lisp',
    'prime.lisp',
    'fib.lisp',
    'dict.lisp'
]

def check_result(output, check_filename):
    result_offset = 0
    found_check_lines = False
    with open(check_filename, 'r') as infile:
        for linenum, line in enumerate(infile):
            chkoffs = line.find('CHECK: ')
            if chkoffs != -1:
                found_check_lines = True
                expected = line[chkoffs + 7:].strip()
                got = output.find(expected, result_offset)
                if got != -1:
                    result_offset = got + len(expected)
                else:
                    print('FAIL: line {} expected string {} was not found'
                        .format(linenum + 1, expected))
                    print('searching here:' + output[result_offset:])
                    return False

    if not found_check_lines:
        print('FAIL: no lines with CHECK: were found')
        return False

    if output.find('HALTED', result_offset) == -1:
        print('simulation did not halt normally')
        return False

    print('PASS')

    return True


def runtest(filename):
    try:
        # Compile test
        subprocess.check_call(['python3', os.path.join(PROJECT_ROOT, 'compile.py'), filename])

        # Run test
        result = subprocess.check_output(['vvp', os.path.join(PROJECT_ROOT, 'sim.vvp')]).decode().strip()
        if result:
            check_result(result, filename)
        else:
            print('FAIL: no output')
    except KeyboardInterrupt:
        raise
    except:
        print('FAIL: exception thrown')
        raise


def run_compile_error_test(filename, errorstr):
    result = subprocess.run(['python3', os.path.join(PROJECT_ROOT, 'compile.py'), filename],
        capture_output=True)
    if result.returncode != 1:
        print('FAIL: bad return call')

    if errorstr not in str(result.stdout, 'utf-8'):
        print('FAIL: error message not found')

    print('PASS')


if len(sys.argv) > 1:
    runtest(os.path.join(TEST_DIR, sys.argv[1]))
else:
    for filename in POSITIVE_TESTS:
        print(filename, end=' ')
        sys.stdout.flush()
        runtest(os.path.join(TEST_DIR, filename))

    print('compile-fail.lisp', end=' ')
    run_compile_error_test(os.path.join(TEST_DIR, 'compile-fail.lisp'), 'Compile error: missing )')

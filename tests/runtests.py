#!/usr/bin/env python
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

from __future__ import print_function
import subprocess
import sys

TESTS = [
    'oom.lisp',
    'gc.lisp',
    'closure.lisp',
    'map-reduce.lisp',
    'sum-even-fib.lisp',
    'optimizer.lisp',
    'zip.lisp',
    'anagram.lisp',
    'anonfunc.lisp',
    'breakloop.lisp',
    'reverse.lisp',
    'prime.lisp',
    'pair.lisp',
    'conditionals.lisp',
    'forloop.lisp',
    'fib.lisp',
    'filter.lisp',
    'getbp_bug.lisp',
    'hello.lisp',
    'dict.lisp',
    'math.lisp',
    'nth.lisp'
]


def check_output(output, check_filename):
    result_offset = 0
    line_no = 1
    found_check_lines = False
    with open(check_filename, 'r') as infile:
        for line in infile.readlines():
            chkoffs = line.find('CHECK: ')
            if chkoffs != -1:
                found_check_lines = True
                expected = line[chkoffs + 7:].strip()
                got = output.find(expected, result_offset)
                if got:
                    result_offset = got + len(expected)
                else:
                    print('FAIL: line ' + str(line_no) +
                          ' expected string ' + expected + ' was not found')
                    print('searching here:' + output[result_offset:])
                    return False

            line_no += 1

    if not found_check_lines:
        print('FAIL: no lines with CHECK: were found')
        return False

    if output.find('HALTED', result_offset) == -1:
        print('simulation did not halt normally')
        return False

    return True


def runtest(filename):
    try:
        # Compile test
        subprocess.check_call(['python', 'compile.py', filename])

        # Run test
        output = subprocess.check_output(['vvp', 'sim.vvp']).decode().strip()
        if output:
            if check_output(output, filename):
                print('PASS')

    except KeyboardInterrupt:
        raise
    except:
        print('FAIL: exception thrown')
        raise

if len(sys.argv) > 1:
    runtest('tests/' + sys.argv[1])
else:
    for filename in TESTS:
        print(filename, end=' ')
        runtest('tests/' + filename)

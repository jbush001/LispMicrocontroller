#!/usr/bin/env python

import subprocess
import sys
import re

TESTS = [
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
    'muldiv.lisp',
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
                regexp = re.compile(expected)
                got = regexp.search(output, result_offset)
                if got:
                    result_offset = got.end()
                else:
                    print('FAIL: line ' + str(line_no) +
                          ' expected string ' + expected + ' was not found')
                    print('searching here:' + output[result_offset:])
                    return False

            line_no += 1

    if not found_check_lines:
        print('FAIL: no lines with CHECK: were found')
        return False

    return True


def runtest(filename):
    try:
        # Compile test
        args = ['python', 'compile.py', filename]
        process = None
        try:
            process = subprocess.Popen(args)
            process.communicate()
        except:
            print('compile failed')
            if process:
                process.kill()

            raise

        # Run test
        args = ['vvp', 'sim.vvp']
        process = None
        output = None
        try:
            process = subprocess.Popen(args, stdout=subprocess.PIPE)
            output = process.communicate()[0].strip()
        except:
            if process:
                process.kill()

            raise

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
        print(filename)
        runtest('tests/' + filename)

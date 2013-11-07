import subprocess, sys, re

TESTS = [
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
	'map.lisp',
	'muldiv.lisp',
	'nth.lisp'
]

def checkOutput(output, checkFilename):
    resultOffset = 0
    lineNo = 1
    foundCheckLines = False
    f = open(checkFilename, 'r')
    for line in f.readlines():
    	chkoffs = line.find('CHECK: ')
    	if chkoffs != -1:
    		foundCheckLines = True
    		expected = line[chkoffs + 7:].strip()
    		regexp = re.compile(expected)
    		got = regexp.search(output, resultOffset)
    		if got:
    			resultOffset = got.end()
    		else:
    			print 'FAIL: line ' + str(lineNo) + ' expected string ' + expected + ' was not found'
    			print 'searching here:' + result[resultOffset:]
    			return False
			
    	lineNo += 1

    if not foundCheckLines:
    	print 'FAIL: no lines with CHECK: were found'    
        return False
        
    return True
    
def runtest(filename):
	try:
		# Compile test
		args = [ 'python', 'compile.py', filename ]
		process = None
		try:
			process = subprocess.Popen(args)
			process.communicate()
		except:
			print 'compile failed'
			if process: 
				process.kill()
		
			raise
		
		# Run test
		args = [ 'vvp', 'sim.vvp' ]
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
			if checkOutput(output, filename):
				print 'PASS'
				
	except KeyboardInterrupt:
		raise
	except:
		print 'FAIL: exception thrown'
		raise

if len(sys.argv) > 1:
	runtest('tests/' + sys.argv[1])
else:
	for filename in TESTS:
		print filename, 
		runtest('tests/' + filename)

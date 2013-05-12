import subprocess, sys

TESTS = [
	'anonfunc.lisp',
	'breakloop.lisp',
	'reverse.lisp',
	'prime.lisp',
	'pair.lisp',
	'conditionals.lisp', 
	'count.lisp', 
	'fib.lisp', 
	'filter.lisp',
	'getbp_bug.lisp',
	'hello.lisp',
	'map.lisp',
	'muldiv.lisp',
	'nth.lisp'
]

def runtest(filename):
	# Compile test
	args = [ 'python', 'compile.py', filename ]

	try:
		process = None
		try:
			process = subprocess.Popen(args)
			process.communicate()
		except:
			print 'compile failed'
			if process: 
				process.kill()
		
			raise
		
		# Read expected results
		checkval = ''
		f = open(filename, 'r')
		for line in f.readlines():
			offs = line.find('CHECK: ')
			if offs != -1:
				checkval += line[offs + 7:].strip()
		
		checkval.strip()
	
		# Run test
		args = [ 'vvp', 'sim.vvp' ]
		process = None
		try:
			process = subprocess.Popen(args, stdout=subprocess.PIPE)
			output = process.communicate()[0].strip()
		except:
			print 'execute failed'
			if process:
				process.kill()

			raise

		result = ''
		for line in output.split('\n'):
			if line.find('Not enough words in the file for the requested range') != -1:
				continue
			
			if line.find('VCD info') != -1:
				continue
			
			result += line.strip()

		if result != checkval:
			print 'FAIL:'
			print 'expected: ' + checkval
			print 'actual: ' + result
		else:
			print 'PASS'	
	except KeyboardInterrupt:
		raise
	except:
		print 'FAIL: exception thrown'

if len(sys.argv) > 1:
	runtest('tests/' + sys.argv[1])
else:
	for filename in TESTS:
		print filename, 
		runtest('tests/' + filename)

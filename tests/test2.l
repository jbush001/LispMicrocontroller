;
; Recursive function call with conditional
;

(function fib (n)
	(if (< n 2)
		n
		(+ (fib (- n 1)) (fib (- n 2)))
	)
)

(for i 0 10 1
	(begin
		(printhex (fib i))
		(printchar 10)
	)
)


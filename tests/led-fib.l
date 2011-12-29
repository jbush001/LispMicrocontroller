;
; On altera dev board, display fibonacci result using LEDs
;

(function fib (n)
	(if (< n 2)
		n
		(+ (fib (- n 1)) (fib (- n 2)))
	)
)

(write-register 1 (fib 11))


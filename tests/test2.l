;
; Recursive function call with conditional
;

(printhex 1234)

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


; Expected output:
; 0000
; 0001
; 0001
; 0002
; 0003
; 0005
; 0008
; 000D
; 0015
; 0022
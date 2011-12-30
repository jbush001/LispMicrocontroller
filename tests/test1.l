;
; Garbage collector test
;

(assign b (cons 1 2))	; Global holds a reference to this element

(printhex b)
(printchar 10)

(function foo ()
	(let ((a (cons 3 4)))	; Reference on the stack, won't be collected
		(printhex a)
		(printchar 10)

		($gc)
	)
)

(foo)
($gc)	; We should get element a back now
(assign c (cons 5 6))	; This will take the space that a formerly took

(printhex c)
(printchar 10)

(assign d (cons 7 8))	; Allocate a new block from the wilderness
(printhex d)
(printchar 10)

; Expected output
; 0184
; 0186
; 0186
; 0188
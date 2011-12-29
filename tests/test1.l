;
; Garbage collector test
;

(assign b (cons 1 2))

(function foo ()
	(let ((a (cons 3 4)))
		($gc)
	)
)

(foo)
(assign c (cons 5 6))

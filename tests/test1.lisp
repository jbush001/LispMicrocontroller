;
; Garbage collector test  
;

; Hold references to these in global variables
(assign a '(1 2 (99 98 97 96) 4))	; Nested list, needs to recurse
(assign b '(5 6 7 8))

(function foo ()
	(let ((c '(9 10 11 12)) (d '(13 14 15 16)))	; Reference on the stack, won't be collected
		($gc)
	)
)

(foo)
($gc)	; We should get element 'c' and 'd' back now


(assign e '(17 18 19 20 21 22 23 24))	; This will take the space that a formerly took


(assign f '(25 26 27 28))	; Allocate a new block from the wilderness

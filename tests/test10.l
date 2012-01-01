
; Case 1: will GC and free up nodes repeatedly
;(while 1
;	(cons 1 2)
;)

; Case 2: will run out of memory
(while 1
	(assign a (cons 1 a))
)

(function append (list element)
	(if list
		(cons (first list) (append (rest list) element))
		(cons element 0)
	)
)

(function reverse (list)
	(if list
		(append (reverse (rest list)) (first list))
		0
	)
)

(foreach node (reverse '(1 2 3 4 5))
	(begin
		(printhex node)
		(printchar 10)
	)
)

; Expected output:
; 0005
; 0004
; 0003
; 0002
; 0001
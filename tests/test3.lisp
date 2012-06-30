
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
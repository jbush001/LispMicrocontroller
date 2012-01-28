

(function foo (a b)
	(begin
		(printhex a)
		(printchar 10)
		(printhex b)
		(printchar 10)
	)
)

(foo (getbp) 5)

;
; When the bug is present, this prints
;  1FFC
;  0000
;
;  With a fix, it prints
;  1FFC
;  0005
;
   


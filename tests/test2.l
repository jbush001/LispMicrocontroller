;
; Recursive function call with conditional
;

(function aprog (n)
	(if n 
		(+ n (aprog (- n 1)))
		0
	)
)

(printhex (aprog 10))




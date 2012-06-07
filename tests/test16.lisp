; Use variables so the optimizer doesn't hard code these values
(assign true 1)
(assign false 0)

(printhex (and true true))	; 1
(printchar 10)

(printhex (and true false)) ; 0
(printchar 10)

(printhex (and false true)) ; 0
(printchar 10)

(printhex (and false false)) ; 0
(printchar 10)

(printhex (or true true)) ; 1
(printchar 10)

(printhex (or true false)) ; 1
(printchar 10)

(printhex (or false true)) ; 1
(printchar 10)

(printhex (or false false)) ; 0
(printchar 10)

(if (and true true) ; 1
	(printhex 1)
	(printhex 0)
)
(printchar 10)

(if (and true false) ; 0
	(printhex 1)
	(printhex 0)
)
(printchar 10)

(if (and false true) ; 0
	(printhex 1)
	(printhex 0)
)
(printchar 10)

(if (and false false) ; 0
	(printhex 1)
	(printhex 0)
)
(printchar 10)

(if (or true true) ; 1
	(printhex 1)
	(printhex 0)
)
(printchar 10)

(if (or true false) ; 1
	(printhex 1)
	(printhex 0)
)
(printchar 10)

(if (or false true) ; 1
	(printhex 1)
	(printhex 0)
)
(printchar 10)

(if (or 0 0) ; 0
	(printhex 1)
	(printhex 0)
)
(printchar 10)

; Now check that we short-circuit properly
(printhex (and true true)) ; 1
(printchar 10)

(printhex (and true false)) ; 0
(printchar 10)

; 0001
; 0000
; 0000
; 0000
; 0001
; 0001
; 0001
; 0000
; 0001
; 0000
; 0000
; 0000
; 0001
; 0001
; 0001
; 0000
; 0001
; 0000

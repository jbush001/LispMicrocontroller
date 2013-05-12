; Use variables so the optimizer doesn't hard code these values
(assign yes 1)
(assign no 0)

(printhex (and yes yes))	; 1
(printhex (and yes no)) ; 0
(printhex (and no yes)) ; 0
(printhex (and no no)) ; 0

(printhex (or yes yes)) ; 1
(printhex (or yes no)) ; 1
(printhex (or no yes)) ; 1
(printhex (or no no)) ; 0

(if (and yes yes) ; 1
	(printhex 1)
	(printhex 0)
)

(if (and yes no) ; 0
	(printhex 1)
	(printhex 0)
)

(if (and no yes) ; 0
	(printhex 1)
	(printhex 0)
)

(if (and no no) ; 0
	(printhex 1)
	(printhex 0)
)

(if (or yes yes) ; 1
	(printhex 1)
	(printhex 0)
)

(if (or yes no) ; 1
	(printhex 1)
	(printhex 0)
)

(if (or no yes) ; 1
	(printhex 1)
	(printhex 0)
)

(if (or no no) ; 0
	(printhex 1)
	(printhex 0)
)

; Check that we short-circuit properly
(if (and yes yes yes yes yes yes)	; 1
	(printhex 1)
	(printhex 0)
)

(if (and yes yes no yes yes) ; 0
	(printhex 1)
	(printhex 0)
)

(if (or no no no no yes) ; 1
	(printhex 1)
	(printhex 0)
)

(if (or no no no no no) ; 0
	(printhex 1)
	(printhex 0)
)

; CHECK: 00010000000000000001000100010000000100000000000000010001000100000001000000010000

	
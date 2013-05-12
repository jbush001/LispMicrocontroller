; Use variables so the optimizer doesn't hard code these values
(assign yes 1)
(assign no 0)

(printdec (and yes yes))	; CHECK: 1
(printdec (and yes no)) ; CHECK: 0
(printdec (and no yes)) ; CHECK: 0
(printdec (and no no)) ; CHECK: 0

(printdec (or yes yes)) ; CHECK: 1
(printdec (or yes no)) ; CHECK: 1
(printdec (or no yes)) ; CHECK: 1
(printdec (or no no)) ; CHECK: 0

(if (and yes yes) ; CHECK: 1
	(printdec 1)
	(printdec 0)
)

(if (and yes no) ; CHECK: 0
	(printdec 1)
	(printdec 0)
)

(if (and no yes) ; CHECK: 0
	(printdec 1)
	(printdec 0)
)

(if (and no no) ; CHECK: 0
	(printdec 1)
	(printdec 0)
)

(if (or yes yes) ; CHECK: 1
	(printdec 1)
	(printdec 0)
)

(if (or yes no) ; CHECK: 1
	(printdec 1)
	(printdec 0)
)

(if (or no yes) ; CHECK: 1
	(printdec 1)
	(printdec 0)
)

(if (or no no) ; CHECK: 0
	(printdec 1)
	(printdec 0)
)

; Check that we short-circuit properly
(if (and yes yes yes yes yes yes)	; CHECK: 1
	(printdec 1)
	(printdec 0)
)

(if (and yes yes no yes yes) ; CHECK: 0
	(printdec 1)
	(printdec 0)
)

(if (or no no no no yes) ; CHECK: 1
	(printdec 1)
	(printdec 0)
)

(if (or no no no no no) ; CHECK: 0
	(printdec 1)
	(printdec 0)
)

	

; Sprite 0 (player rocket)
(write-register 5 1)			; enable
(write-register 3 (-240 20))	; y coord (a little up from the bottom)
(assign x0 (- (/ 320 2) 8))

(while 1
	; Wait for start of vblank
	(while (<> (read-register 1) 1)
		()
	)

	; Set up sprite 0
	(write-register 2 x0)	; X coord
	(write-register 4 s0shape)	; animation frame

	; Wait for end of vblank
	(while (read-register 1)
		()
	)

	; Left?
	(if (and (read-register 0) 1)
		(if (> x0 5)
			(assign x0 (- x0 5))
		)
	)

	; Move right?
	(if (and (read-register 0) 2)
		(if (< x0 (-320 21))
			(assign x0 (+ x0 5))
		)
	)

	; Animate (flicker fire)
	(assign s0shape (- 1 s0shape))
)


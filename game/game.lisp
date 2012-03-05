
; Sprite 0
(write-register 4 0)	; shape
(write-register 5 1)	; enable
(assign xdir 1)
(assign ydir 1)

(while 1
	; Wait for start of vblank
	(while (<> (read-register 1) 1)
		()
	)

	; Set up sprite 0
	(write-register 2 x0)	; X coord
	(write-register 3 y0)	; y coord

	; Wait for end of vblank
	(while (read-register 1)
		()
	)

	(if (< x0 1)
		(assign xdir 1)
	)

	(if (> x0 (- 320 16))
		(assign xdir -1)
	)

	(if (< y0 1)
		(assign ydir 1)
	)

	(if (> y0 (- 240 16))
		(assign ydir -1)
	)

	(assign x0 (+ x0 xdir))
	(assign y0 (+ y0 ydir))
)


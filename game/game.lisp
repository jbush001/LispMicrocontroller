; Set up sprites

; Wait for vblank
(while (<> (read-register 1) 1)
	()
)

; Set up sprite 0
(write-register 2 5)	; X coord
(write-register 3 5)	; y coord
(write-register 4 0)	; shape
(write-register 5 1)	; enable

; Set up sprite 1
(write-register 6 20)	; X coord
(write-register 7 30)	; Y coord
(write-register 8 1)	; shape
(write-register 9 1)	; enable
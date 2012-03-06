;
; On the cyclone II dev board, compute nth iteration of a fibonacci sequence and display
; on 7 segment display
;

(assign segments '(64 249 36 48 25 18 2 120 0 16))

(function set-display (num)
	(for register 2 6 1
		(begin
			(write-register register (nth segments (mod num 10)))
			(assign num (/ num 10))
		)
	)
)

(function fib (n)
    (if (< n 2)
        n
        (+ (fib (- n 1)) (fib (- n 2)))
    )
)

(assign a 0)
(while 1
	(set-display (fib a))
	(assign a (+ a 1))

	; Wait for key release
	(while (and (read-register 6) 1)
		()
	)

	; Wait for key press
	(while (= (and (read-register 6) 1) 0)
		()
	)
)

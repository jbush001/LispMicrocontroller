
(assign segments '(64 249 36 48 25 18 2 120 0 16))

(function set-display (num)
	(for register 2 6 1
		(begin
			(write-register register (nth segments (mod num 10)))
			(assign num (/ num 10))
		)
	)
)

(assign a 0)
(while 1
	(set-display a)
	(assign a (+ a 1))
	(if (> a 9999)
		(assign a 0)
	)

	(for j 0 5 1
		(for i 0 16000 1
			()
		)
	)
)

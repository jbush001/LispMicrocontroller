
(assign a 1)
(while 1
	(assign a (or (lshift a 1) (rshift a 7)))
	(write-register 1 a)
	(for j 0 10 1
		(for i 0 16000 1
			()
		)
	)
)


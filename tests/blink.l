
(assign a 0)
(while 1
	(assign a (+ a 1))
	(write-register 1 a)
	(for i 0 16000 1
		()
	)
)


(function isprime (x)
	(let ((p 1))
		(for i 2 (sqrt x) 1
			(if (% x i)
				()			

				(begin
					(assign p 0)
					(break)
				)
			)
		)

		p
	)
)

; Print a list of all prime numbers thru 100
(for i 2 100 1
	(if (isprime i)
		(begin
			(printdec i)
			(printchar 10)
		)
	)
)

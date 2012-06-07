(printhex
	(while (< i 10)
		(assign i (+ i 1))
	)
)

(printchar 10)

(printhex
	(while (< j 10)
		(if (= j 7)
			(break 37)
		)

		(assign j (+ j 1))
	)
)
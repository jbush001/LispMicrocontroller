(function filter (list func)
	(if list
		(if (func (first list))
			(cons (first list) (filter (rest list) func))
			(filter (rest list) func)
		)

		0
	)
)

; Show only odd numbers of a sequence
(foreach i (filter '(1 2 3 4 5 6 7 8 9 10) (lambda (x) (and x 1)))
	(begin
		(printhex i)
		(printchar 10)
	)
)



(assign segments '(240 249 36 48 41 18 2 120 0 16))

(function set-display (num)
	(for register 5 1 -1
		(begin
			(write-register register (nth segments (% num 10)))
			(assign num (/ num 10))
		)
	)
)

(set-display 2301)

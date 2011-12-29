; A map consists of ((name value) (name value) (name value))

; Find an item in a map
(function map-lookup (map name)
	(if map
		(if (= name (first (first map)))
			(first (rest (first map)))		; Match, return value
			(map-lookup (rest map) name)	; Lookup in remaining elements
		)
		
		0
	)
)

; Enter an item into a map
(function map-set (map name value)
	(if map	
		(if (= name (first (first map)))
			(cons (cons name (cons value 0)) (rest map)) ; Found a match, replace
			(cons (first map) (map-set (rest map) name value)) ; Search rest of list
		)

		(cons (cons name (cons value 0)) 0)	; No match, add new entry
	)
)

(assign map 0)
(assign map (map-set map 1 7))
(assign map (map-set map 2 9))
(assign map (map-set map 3 5))
(assign map (map-set map 2 8))		; Replace second entry

; Print map contents
(foreach entry map 
	(begin
		(printhex (first entry))
		(printchar 32)
		(printhex (first (rest entry)))
		(printchar 10)
	)
)

; Do some lookups
(printhex (map-lookup map 1))
(printchar 10)
(printhex (map-lookup map 2))
(printchar 10)
(printhex (map-lookup map 3))
(printchar 10)
(printhex (map-lookup map 4))		; Bad key, should return zero
(printchar 10)

; Expected output:
; 0001 0007
; 0002 0008
; 0003 0005
; 0007
; 0008
; 0005
; 0000




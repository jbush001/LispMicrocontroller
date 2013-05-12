; 
; Copyright 2011-2012 Jeff Bush
; 
; Licensed under the Apache License, Version 2.0 (the "License");
; you may not use this file except in compliance with the License.
; You may obtain a copy of the License at
; 
;     http://www.apache.org/licenses/LICENSE-2.0
; 
; Unless required by applicable law or agreed to in writing, software
; distributed under the License is distributed on an "AS IS" BASIS,
; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
; See the License for the specific language governing permissions and
; limitations under the License.
; 

; A map consists of ((name value) (name value) (name value))

; Find an item in a map
(function map-lookup (map name)
	(if map
		(if (= name (first (first map)))
			(first (rest (first map)))		; Match, return value
			(map-lookup (rest map) name)	; Lookup in remaining elements
		)
		
		nil
	)
)

; Enter an item into a map
(function map-set (map name value)
	(if map	
		(if (= name (first (first map)))
			(cons (cons name (cons value nil)) (rest map)) ; Found a match, replace
			(cons (first map) (map-set (rest map) name value)) ; Search rest of list
		)

		(cons (cons name (cons value nil)) nil)	; No match, add new entry
	)
)

(assign map nil)
(assign map (map-set map 1 7))
(assign map (map-set map 2 9))
(assign map (map-set map 3 5))
(assign map (map-set map 2 8))		; Replace second entry

;
; Print map contents
; CHECK: 0001 0007
; CHECK: 0002 0008
; CHECK: 0003 0005

(foreach entry map 
	(begin
		(printhex (first entry))
		(printchar 32)
		(printhex (first (rest entry)))
		(printchar 10)
	)
)

; Do some lookups
(printhex (map-lookup map 1)) ; CHECK: 0007
(printhex (map-lookup map 2)) ; CHECK: 0008
(printhex (map-lookup map 3)) ; CHECK: 0005
(printhex (map-lookup map 4)) ; CHECK: 0000



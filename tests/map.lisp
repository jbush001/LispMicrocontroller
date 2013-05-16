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

; A map consists of ((name . value) (name . value) (name . value))

; Find an item in a map.  Return nil if it is not present.

(function map-lookup (map name)
	(if map
		(if (= name (first (first map))) ; then check if key matches
			(rest (first map))	; then match, return value
			(map-lookup (rest map) name) ; else lookup in remaining elements
		)
		
		nil ; else not found
	)
)

; Enter an item into a map
(function map-set (map name value)
	(if map	
		(if (= name (first (first map))) ; then check if key matches
			(cons (cons name value) (rest map)) ; then key exists, replace
			(cons (first map) (map-set (rest map) name value))	; else search rest of list
		)
		
		(cons (cons name value) nil) ; else no match, add new entry
	)
)

; Add some entries
(assign map nil)
(assign map (map-set map 1 7))
(assign map (map-set map 2 9))
(assign map (map-set map 3 5))
(assign map (map-set map 2 8))		; Replace second entry

(foreach i map
	(begin
		(print (first i))
		(print (rest i))
	)
)

; CHECK: 17
; CHECK: 28
; CHECK: 35

; Do some lookups
(print (map-lookup map 1)) ; CHECK: 7
(print (map-lookup map 2)) ; CHECK: 8
(print (map-lookup map 3)) ; CHECK: 5
(print (map-lookup map 4)) ; CHECK: 0



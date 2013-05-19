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

(function sequence (first last)
	(if (< first last)
		(cons first (sequence (+ first 1) last)) ; then append next value
		(cons last nil))) ; else end of list

(function filter (list func)
	(if list
		; then
		(if (func (first list))
			; Then (filter returns true, this is member of list)
			(cons (first list) (filter (rest list) func))

			; Else (this should be excluded from list)
			(filter (rest list) func))

		nil)) ; else end of list

; Show only odd numbers of a sequence
(print (filter (sequence 0 10) (function (x) (bitwise-and x 1))))
; CHECK: (1 3 5 7 9)


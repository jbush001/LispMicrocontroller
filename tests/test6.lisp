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
(foreach i (filter '(1 2 3 4 5 6 7 8 9 10) (function (x) (bitwise-and x 1)))
	(begin
		(printhex i)
		(printchar 10)
	)
)

; Expected output
; 0001
; 0003
; 0005
; 0007
; 0009
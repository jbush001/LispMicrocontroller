; 
; Copyright 2011-2013 Jeff Bush
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

; Merge two lists into a list of pairs.
(function zip (a b)
	(if (and a b)
		(cons (cons (first a) (first b)) (zip (rest a) (rest b)))
		nil))		; else end of list	

(foreach i (zip '(1 2 3 4 5) '(11 13 15 17 19))
	(begin
		(print (first i))
		(print (second i))))

; Result should be ((1 . 11) (2 . 13) (3 . 15) (4 . 17) (5 . 19))
; CHECK: 1
; CHECK: 11
; CHECK: 2
; CHECK: 13
; CHECK: 3
; CHECK: 15
; CHECK: 4
; CHECK: 17
; CHECK: 5
; CHECK: 19

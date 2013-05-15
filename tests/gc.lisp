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

;
; Garbage collector test.  This can't be run automatically.  I enable
; GC logs in runtime.lisp, then manually analyze the sequence of allocs/frees.
;

; Hold references to these in global variables
(assign a '(1 2 (99 98 97 96) 4))	; Nested list, needs to recurse
(assign b '(5 6 7 8))

(function foo ()
	(let ((c '(9 10 11 12)) (d '(13 14 15 16)))	; Reference on the stack, won't be collected
		($gc)
	)
)

(foo)
($gc)	; We should get element 'c' and 'd' back now


(assign e '(17 18 19 20 21 22 23 24))	; This will take the space that a formerly took


(assign f '(25 26 27 28))	; Allocate a new block from the wilderness

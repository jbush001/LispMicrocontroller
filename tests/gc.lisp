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
; Garbage collector test.
; In the automated configuration, this ensures the program runs to completion,
; but can't ensure it frees everything. To verify this completely, I enable
; GC logs in runtime.lisp, then manually analyze the sequence of allocs/frees.
;

; Hold references to these in global variables
(assign a '(1 2 (99 98 97 96) 4))    ; Nested list, needs to recurse
(assign b '(5 6 7 8))

(function foo ()
    (let ((c '(9 10)) (d '(11 12)))    ; Reference on the stack, won't be collected
        ($gc)   ; This shouldn't free anything
        (let ((g '(13 14 15 16))) ; If c or d were incorrectly freed, this would clobber
            (print c)   ; CHECK: (9 10)
            (print d)))) ; CHECK: (11 12)

(foo)
($gc)    ; We should get element 'c', 'd', and 'g' back now

(assign e '(17 18 19 20 21 22 23 24))    ; This will take the space that c, d, and g formerly took

(assign f '(25 26 27 28))    ; Allocate a new block from the wilderness

(print a) ; CHECK: (1 2 (99 98 97 96) 4)
(print b) ; CHECK: (5 6 7 8)
(print e) ; CHECK: (17 18 19 20 21 22 23 24)
(print f) ; CHECK: (25 26 27 28)




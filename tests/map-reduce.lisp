;
; Copyright 2011-2016 Jeff Bush
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

(function sum (a b)
    (+ a b))

(function square (a)
    (* a a))

(function sum-of-squares (values)
    (reduce (map values square) sum))

(print (map '(5 7 9) square))           ; CHECK: (25 49 81)
(print (map nil square))                ; CHECK: 0

(print (reduce '(1) sum))               ; CHECK: 1
(print (reduce '(1 2) sum))             ; CHECK: 3
(print (reduce '(1 2 3) sum))           ; CHECK: 6
(print (reduce '(1 2 3 4) sum))         ; CHECK: 10
(print (reduce nil sum))                ; CHECK: 0

(print (sum-of-squares '(2)))           ; CHECK: 4
(print (sum-of-squares '(3 4)))         ; CHECK: 25
(print (sum-of-squares '(5 6 7)))       ; CHECK: 110
(print (sum-of-squares '(8 9 10 11)))   ; CHECK: 366
(print (sum-of-squares nil))            ; CHECK: 0
(print (sum-of-squares '()))            ; CHECK: 0

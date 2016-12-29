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

; We use variables in these expressions rather than constants so the
; optimizer doesn't remove the operations.

(assign NEG -7)
(assign POS 23)

; Builtin operators
(print (+ POS NEG))             ; CHECK: 16
(print (- POS NEG))             ; CHECK: 30
(print (> 23 POS))              ; CHECK: 0
(print (> 24 POS))              ; CHECK: 1
(print (< 23 POS))              ; CHECK: 0
(print (< 22 POS))              ; CHECK: 1
(print (>= 22 POS))             ; CHECK: 0
(print (>= 23 POS))             ; CHECK: 1
(print (>= 24 POS))             ; CHECK: 1
(print (<= 24 POS))             ; CHECK: 0
(print (<= 23 POS))             ; CHECK: 1
(print (<= 22 POS))             ; CHECK: 1
(print (= 22 POS))              ; CHECK: 0
(print (= 23 POS))              ; CHECK: 1
(print (<> 22 POS))             ; CHECK: 1
(print (<> 23 POS))             ; CHECK: 0
(print (bitwise-and NEG POS))   ; CHECK: 17
(print (bitwise-or 64 POS))     ; CHECK: 87
(print (bitwise-xor POS 15))    ; CHECK: 24
(print (rshift POS 1))          ; CHECK: 11
(print (rshift POS 2))          ; CHECK: 5
(print (lshift POS 1))          ; CHECK: 46
(print (lshift POS 2))          ; CHECK: 92

; Runtime library functions
(print (* NEG NEG))             ; CHECK: 49
(print (* NEG POS))             ; CHECK: -161
(print (* POS POS))             ; CHECK: 529
(print (* POS NEG))             ; CHECK: -161
(print (* 0 POS))               ; CHECK: 0
(print (* POS 0))               ; CHECK: 0

(print (/ -2317 POS))           ; CHECK: -100
(print (/ -2317 NEG))           ; CHECK: 331
(print (/ 2317 POS))            ; CHECK: 100
(print (/ 2317 NEG))            ; CHECK: -331
(print (/ POS 2317))            ; CHECK: 0
(print (/ 0 POS))               ; CHECK: 0

(print (mod -2319 POS))         ; CHECK: 19
(print (mod -2319 NEG))         ; CHECK: -2
(print (mod 2319 POS))          ; CHECK: 19
(print (mod 2319 NEG))          ; CHECK: -2
(print (sqrt 1902))             ; CHECK: 43

(print (abs NEG))               ; CHECK: 7
(print (abs POS))               ; CHECK: 23

(print (equal 1 2))                     ; CHECK: 0
(print (equal 2 2))                     ; CHECK: 1
(print (equal 2 '(2)))                  ; CHECK: 0
(print (equal '(2) '(2)))               ; CHECK: 1
(print (equal '(1 2 3) '(1 2 3)))       ; CHECK: 1
(print (equal '(1 2) '(1 2 3)))         ; CHECK: 0
(print (equal '(1 2 3) '(1 2)))         ; CHECK: 0
(print (equal '(1 (2 3)) '(1 (2 3))))   ; CHECK: 1
(print (equal '((1 2) 3) '(1 (2 3))))   ; CHECK: 0
(print (equal "foo" "bar"))             ; CHECK: 0
(print (equal "foo" "foo"))             ; CHECK: 1
(print (equal print print))             ; CHECK: 1
(print (equal (function () 1) (function() 1)))  ; CHECK: 0

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


(assign NEG -7)
(assign POS 23)

(print (* NEG NEG))     ; CHECK: 49
(print (* NEG POS))     ; CHECK: -161
(print (* POS POS))     ; CHECK: 529
(print (* POS NEG))     ; CHECK: -161
(print (* 0 POS))       ; CHECK: 0
(print (* POS 0))       ; CHECK: 0

(print (/ -2317 POS))   ; CHECK: -100
(print (/ -2317 NEG))   ; CHECK: 331
(print (/ 2317 POS))    ; CHECK: 100
(print (/ 2317 NEG))    ; CHECK: -331
(print (/ POS 2317))    ; CHECK: 0
(print (/ 0 POS))       ; CHECK: 0

(print (mod -2319 POS)) ; CHECK: 19
(print (mod -2319 NEG)) ; CHECK: -2
(print (mod 2319 POS))  ; CHECK: 19
(print (mod 2319 NEG))  ; CHECK: -2
(print (sqrt 1902))     ; CHECK: 43

(print (abs NEG))       ; CHECK: 7
(print (abs POS))       ; CHECK: 23


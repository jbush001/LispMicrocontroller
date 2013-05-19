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

; This module can verify correctness of operations that can be optimized, but not that
; they actually are optimized. That can be done by manually inspecting program.lst.
; The transformed S-Expression version of the code will show a bunch of constant prints


;
; Constant folding operations
;
(print (bitwise-and (/ 30006 9781) (- 10926))) ; CHECK: 2
(print (bitwise-or (- (bitwise-xor 9378 -14876)) (- 3224))) ; CHECK: -6
(print (- (- (bitwise-not -6307) 12569) 25988)) ; CHECK: -32251
(print (- (- (bitwise-and (/ -6162 -7804) -11603)) (+ (bitwise-not -31886) -12666))) ; CHECK: -19219
(print (- (bitwise-not (- (bitwise-not (bitwise-not 9450)))))) ; CHECK: -9449
(print (bitwise-not (bitwise-or (bitwise-not -27560) -23648))) ; CHECK: 5208
(print (+ 8600 (- 15344))) ; CHECK: -6744
(print (- (- (+ (bitwise-and -13413 -30063) 32184)))) ; CHECK: 2121
(print (+ (bitwise-not 6015) (bitwise-xor (- (bitwise-xor -25330 -30116) (* 14939 -18396)) (* -1427 -20641)))) ; CHECK: -2955
(print (- (bitwise-xor 15162 (* (- -537) (bitwise-not (- -2093 8550)))))) ; CHECK: -2168
(print (- (/ (bitwise-not (- -6642)) (- (- 4255 -24399) (bitwise-not 6132))))) ; CHECK: 0
(print (- (bitwise-and -13272 (bitwise-xor -15109 17211)))) ; CHECK: 31744
(print (bitwise-not (* (bitwise-and -32697 (- -12007)) 14871))) ; CHECK: -7266
(print (bitwise-xor -13890 (bitwise-or (bitwise-not (bitwise-not -28328)) (bitwise-not (- (- 16323)))))) ; CHECK: 6338
(print (- (bitwise-or 4826 -26464))) ; CHECK: 25862
(print (- (- (+ (- (- (bitwise-and -6319 14172)) (+ -14153 3183)) (bitwise-not (- -27588)))))) ; CHECK: -26683
(print (* (/ (- -21065 12010) (bitwise-xor 15577 (bitwise-not -18429))) (- -19260))) ; CHECK: 19260
(print (- (bitwise-not 28024) (bitwise-not (* (+ (bitwise-or -16256 -22043) (bitwise-not -14113)) (bitwise-not (bitwise-not (- -1821))))))) ; CHECK: 29465
(print (- (/ (/ -14462 -18426) (- 14441)))) ; CHECK: 0
(print (bitwise-not 31999)) ; CHECK: -32000
(print (rshift (bitwise-not 416) (- 5 2))) ; CHECK: -53
(print (+ (lshift 3 2) 5)) ; CHECK: 17

;
; Power of two strength reduction
;
(assign a 12)
(print (/ a 4)) ; CHECK: 3
(print (/ a 2)) ; CHECK: 6
(print (* a 8)) ; CHECK: 96
(print (* a 16)) ; CHECK: 192

; Conditionals
(print (if (< 5 7) 12 5))  ; CHECK: 12
(print (if (< 7 5) 7 4)) ; CHECK: 4
(print (if (> 3 2) 7)) ; CHECK: 7
(print (if (> 2 3) 7)) ; CHECK: 0

; Logical operators
(print (and 0 0 0)) ; CHECK: 0
(print (and 0 0 1)) ; CHECK: 0
(print (and 0 1 0)) ; CHECK: 0
(print (and 0 1 1)) ; CHECK: 0
(print (and 1 0 0)) ; CHECK: 0
(print (and 1 0 1)) ; CHECK: 0
(print (and 1 1 0)) ; CHECK: 0
(print (and 1 1 1)) ; CHECK: 1

(print (or 0 0 0)) ; CHECK: 0
(print (or 0 0 1)) ; CHECK: 1
(print (or 0 1 0)) ; CHECK: 1
(print (or 0 1 1)) ; CHECK: 1
(print (or 1 0 0)) ; CHECK: 1
(print (or 1 0 1)) ; CHECK: 1
(print (or 1 1 0)) ; CHECK: 1
(print (or 1 1 1)) ; CHECK: 1

(print (and (or 0 0) (or 0 0))) ; CHECK: 0
(print (and (or 0 0) (or 1 0))) ; CHECK: 0
(print (and (or 0 1) (or 0 0))) ; CHECK: 0
(print (and (or 1 0) (or 0 1))) ; CHECK: 1

(print (or (and 0 0) (and 0 0))) ; CHECK: 0 
(print (or (and 1 0) (and 0 0))) ; CHECK: 0
(print (or (and 0 0) (and 1 0))) ; CHECK: 0
(print (or (and 1 1) (and 0 0))) ; CHECK: 1
(print (or (and 0 1) (and 1 1))) ; CHECK: 1






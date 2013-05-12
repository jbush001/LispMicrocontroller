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


(assign a 7)
(assign b -7)

(printhex (* -231 a))		; negative times positive
(printhex (* -231 b))		; negative times negative
(printhex (* 231 a))		; positive times positive
(printhex (* 231 b))		; positive times negative
(printhex (* 0 a))			; zero identity
(printhex (* a 0))			; zero identity

; CHECK: F9AF
; CHECK: 0651
; CHECK: 0651
; CHECK: F9AF
; CHECK: 0000
; CHECK: 0000


(printhex (/ -2317 a))		; negative / positive
(printhex (/ -2317 b))		; negative / negative
(printhex (/ 2317 a))		; positive / positive
(printhex (/ 2317 b))		; positive / negative
(printhex (/ a 2317))		; divisor < dividend
(printhex (/ 0 a))			; zero identity

; CHECK: FEB5
; CHECK: 014B
; CHECK: 014B
; CHECK: FEB5
; CHECK: 0000
; CHECK: 0000


(printhex (mod -2319 a))		; negative / positive
(printhex (mod -2319 b))		; negative / negative
(printhex (mod 2319 a))		; positive / positive
(printhex (mod 2319 b))		; positive / negative

; CHECK: 0002
; CHECK: FFFE
; CHECK: 0002
; CHECK: FFFE

(printhex (sqrt 1902))

; CHECK: 002B

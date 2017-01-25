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

; This test validates basic primitives for list access and construction

(assign a '(1 2 3 4 5 6))

(print (length a)) ; CHECK: 6
(print (nth a 0)) ; CHECK: 1
(print (nth a 1)) ; CHECK: 2
(print (nth a 2)) ; CHECK: 3
(print (nth a 3)) ; CHECK: 4
(print (nth a 4)) ; CHECK: 5
(print (nth a 5)) ; CHECK: 6
(print (nth a 6)) ; CHECK: 0

(print (length nil))    ; CHECK: 0
(print (nth nil))       ; CHECK: 0

(assign b '(7 8))
(print b) ; CHECK: (7 8)

; Append atom
(print (append b 9)) ; CHECK: (7 8 9)

; Append list
(print (append b '(10 11 12))) ; CHECK: (7 8 10 11 12)

; Append to nil list.
(print (append nil '(13 14 15))) ; CHECK: (13 14 15)

(print (append '(16 17 18) nil)) ; CHECK (16 17 18)
(print (append '(19) 20)) ; CHECK (19 20)
(print (append '(21) '(22))) ; CHECK (21 22)


(assign foo 24)
(print (list 25 26 foo))  ; CHECK: (25 26 24)

(print (reverse '(27 28 29 30 31)))
; CHECK: (31 30 29 28 27)

;
; Test dot notation for creating cons cells directly
;
(assign a '(65 . 66))
(print (first a))	; CHECK: 65
(print (second a))	; CHECK: 66

(assign b '((12 . 22) . (47 . 59)))
(print (first (first b)))	; CHECK: 12
(print (second (first b)))	; CHECK: 22
(print (first (second b)))	; CHECK: 47
(print (second (second b)))		; CHECK: 59

;
; setfirst/setnext
;
(assign foo '(0 . 0))
(setfirst foo 61)
(print foo)     ; CHECK: (61)
(setnext foo '(65 . 0))
(print foo)    ; CHECK: (61 65)

;
; Test c[ad]+r operations
;
(assign test1 '(70 (71 (72 73 74) 75) 76))
(assign test2 '(77 . 78))

(print (car test2)) ; CHECK: 77
(print (cdr test2)) ; CHECK: 78

(print (car test1)) ; CHECK: 70
(print (cdr test1)) ; CHECK: ((71 (72 73 74) 75) 76)
(print (cadr test1)) ; CHECK: (71 (72 73 74) 75)
(print (caadr test1)) ; CHECK: 71
(print (cadadr test1)) ; CHECK: (72 73 74)
(print (caadadr test1)) ; CHECK: 72

;
; find-string
;
(print (find-string "abcdefghij" "abc")) ; CHECK: 0
(print (find-string "habcdefghi" "abc")) ; CHECK: 1
(print (find-string "hiabcdefgh" "abc")) ; CHECK: 2
(print (find-string "abcdefghij" "cdg")) ; CHECK: -1

; Partial match and restart
(print (find-string "abcdcdefgh" "cde")) ; CHECK: 4

; Hit end of haystack before match
(print (find-string "abcdefghij" "hijk")) ; CHECK: -1

; Edge cases, not valid input
(print (find-string nil "hijk")) ; CHECK: -1
(print (find-string "abc" nil)) ; CHECK: 0
(print (find-string nil nil)) ; CHECK: -1

;
; sub-list
;
(assign source '(90 91 92 93 94 95 96 97 98 99))

(print (sub-list source 0 10))  ; CHECK: (90 91 92 93 94 95 96 97 98 99)
(print (sub-list source 1 10))  ; CHECK: (91 92 93 94 95 96 97 98 99)
(print (sub-list source 1 8))   ; CHECK: (91 92 93 94 95 96 97 98)
(print (sub-list source 2 3))   ; CHECK: (92 93 94)
(print (sub-list source 5 1))   ; CHECK: (95)
(print (sub-list source 11 5))  ; CHECK: 0
(print (sub-list nil 2 5))      ; CHECK: 0
(print (sub-list source 0 0))   ; CHECK: 0

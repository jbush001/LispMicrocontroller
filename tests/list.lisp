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

(assign b '(1 2))
(print b) ; CHECK: (1 2)

; Append atom
(print (append b 3)) ; CHECK: (1 2 3)

; Append list
(print (append b '(4 5 6))) ; CHECK: (1 2 4 5 6)

(print (append nil '(1 2 3))) ; CHECK (1 2 3)
(print (append '(1 2 3) nil)) ; CHECK (1 2 3)
(print (append '(1) 2)) ; CHECK (1 2)
(print (append '(1) '(2))) ; CHECK (1 2)


(assign foo 12)
(print (list 1 2 foo))  ; CHECK: (1 2 12)

(print (reverse '(1 2 3 4 5)))
; CHECK: (5 4 3 2 1)

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
(setfirst foo 12)
(print foo)     ; CHECK: (12)
(setnext foo '(15 . 0))
(print foo)    ; CHECK: (12 15)

;
; Test c[ad]+r operations
;
(assign test1 '(1 (2 (3 4 5) 6) 7))
(assign test2 '(8 . 9))

(print (car test2)) ; CHECK: 8
(print (cdr test2)) ; CHECK: 9

(print (car test1)) ; CHECK: 1
(print (cdr test1)) ; CHECK: ((2 (3 4 5) 6) 7)
(print (cadr test1)) ; CHECK: (2 (3 4 5) 6)
(print (caadr test1)) ; CHECK: 2
(print (cadadr test1)) ; CHECK: (3 4 5)
(print (caadadr test1)) ; CHECK: 3

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
(assign source '(0 1 2 3 4 5 6 7 8 9))

(print (sub-list source 0 10))  ; CHECK: (0 1 2 3 4 5 6 7 8 9)
(print (sub-list source 1 10))  ; CHECK: (1 2 3 4 5 6 7 8 9)
(print (sub-list source 1 8))   ; CHECK: (1 2 3 4 5 6 7 8)
(print (sub-list source 2 3))   ; CHECK: (2 3 4)
(print (sub-list source 5 1))   ; CHECK: (5)
(print (sub-list source 11 5))  ; CHECK: 0
(print (sub-list nil 2 5))      ; CHECK: 0
(print (sub-list source 0 0))   ; CHECK: 0



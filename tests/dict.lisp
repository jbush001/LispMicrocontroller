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

; A dict consists of ((name . value) (name . value) (name . value))

; Find an item in a dict.  Return nil if it is not present.

(function dict-lookup (dict name)
    (if dict
        (if (= name (first (first dict))) ; then check if key matches
            (second (first dict))    ; then match, return value
            (dict-lookup (rest dict) name) ; else lookup in remaining elements
        )

        nil)) ; else not found

; Enter an item into a dict
(function dict-set (dict name value)
    (if dict
        (if (= name (first (first dict))) ; then check if key matches
            (cons (cons name value) (rest dict)) ; then key exists, replace
            (cons (first dict) (dict-set (rest dict) name value))    ; else search rest of list
        )

        (cons (cons name value) nil))) ; else no match, add new entry

; Add some entries
(assign dict nil)
(assign dict (dict-set dict 1 7))
(assign dict (dict-set dict 2 9))
(assign dict (dict-set dict 3 5))
(assign dict (dict-set dict 2 8))        ; Replace second entry

(foreach i dict
    (begin
        (print (first i))
        (print (second i))))

; CHECK: 17
; CHECK: 28
; CHECK: 35

; Do some lookups
(print (dict-lookup dict 1)) ; CHECK: 7
(print (dict-lookup dict 2)) ; CHECK: 8
(print (dict-lookup dict 3)) ; CHECK: 5
(print (dict-lookup dict 4)) ; CHECK: 0



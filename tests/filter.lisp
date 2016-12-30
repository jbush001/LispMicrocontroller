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

(function sequence (first last)
    (if (< first last)
        (cons first (sequence (+ first 1) last)) ; then append next value
        (cons last nil))) ; else end of list

(assign source (sequence 0 10))

; Filter everything
(print (filter source (function (x) false)))
; CHECK: 0

; Filter nothing
(print (filter source (function (x) true)))
; CHECK: (0 1 2 3 4 5 6 7 8 9 10)

; Show only odd numbers of a sequence
(print (filter source (function (x) (bitwise-and x 1))))
; CHECK: (1 3 5 7 9)



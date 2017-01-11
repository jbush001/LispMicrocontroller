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

; Conditional break
(print
    (while true
        (print j)
        (if (= j 7)
            (break 37))

        (assign j (+ j 1))))

; CHECK: 0
; CHECK: 1
; CHECK: 2
; CHECK: 3
; CHECK: 4
; CHECK: 5
; CHECK: 6
; CHECK: 7
; CHECK: 37

; Break inner loop of nested loop. Ensure break stack works properly.
(for i 3 4 1
    (print
        (for j 1 5 1
            (break i))))

; CHECK: 3
; CHECK: 4

; Break outer loop of nested loop.
(print (while true
    (for j 17 19 1
        (print j))

    (break 99)))

; CHECK: 17
; CHECK: 18
; CHECK: 19
; CHECK: 99

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

; Parameter are constants
(for i 3 9 1
    (print i))

; CHECK: 3456789

; Negative loop index
(for i 7 0 -1
    (print i))

; CHECK: 76543210

; Different step size
(for i 1 9 2
    (print i))

; CHECK: 13579

; Parameters are variables
(assign start 1)
(assign end 13)
(assign step 2)
(for j start end step
    (print j))

; CHECK: 135791113

; Parameters are expressions
(for j (+ start 7) (+ end 3) (+ step 1)
    (print j))

; CHECK: 81114

; Nested loop
(for i 65 78 1
    (for j 0 4 1
        ($printchar (+ i j))))

; CHECK: ABCDEBCDEFCDEFGDEFGH

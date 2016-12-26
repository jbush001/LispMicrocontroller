;
; Copyright 2016 Jeff Bush
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

; This uses tail recursion. Ensure it loops and doesn't overflow the
; stack.
(function tail-recurse (n sum)
    (if n
        (tail-recurse (- n 1) (+ sum 3))
        sum))

($printdec (tail-recurse 2000)) ; CHECK: 6000

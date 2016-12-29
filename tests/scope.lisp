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

(assign foo 12)
(print foo) ; CHECK: 12

; Shadow global with parameter
((function (foo)
    (print foo)) 15) ; CHECK: 15

(print foo) ; CHECK: 12

; Shadow global with local variables
((function ()
    (let ((foo 17))
        (print foo)         ; CHECK: 17
        (let ((foo 19))
            (print foo))    ; CHECK: 19

        (print foo))        ; CHECK: 17
    (print foo)))           ; CHECK: 12

(print foo) ; CHECK: 12

; Shadow with parameter enclosing closure
((function (foo)
    ((function()
        (print foo)))) 23)  ; CHECK: 23

(print foo) ; CHECK: 12


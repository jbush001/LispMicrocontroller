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

(assign foo 13)
(print foo) ; CHECK: 13

(function bar () ($printstr "bar"))

; Shadow global with parameter
((function (foo bar)
    (print foo) ; CHECK: 17
    (print bar) ; CHECK: 19
    (assign foo 23)
    (assign bar 29)
    (print foo) ; CHECK: 23
    (print bar)) ; CHECK: 29
    17 19)

(print foo) ; CHECK: 13
(bar)   ; CHECK: bar

; Shadow global with local variables
; Shadow local with inner scope (let) of locals
((function ()
    (let ((foo 31) (bar 37))
        (print foo)         ; CHECK: 31
        (print bar)         ; CHECK: 37
        (assign foo 41)
        (assign bar 43)
        (print foo)         ; CHECK: 41
        (print bar)         ; CHECK: 43
        (let ((foo 47) (bar 53))
            (print foo)     ; CHECK: 47
            (print bar)     ; CHECK: 53
            (assign foo 59)
            (assign bar 61)
            (print foo)      ; CHECK: 59
            (print bar))     ; CHECK: 61

        (print foo)        ; CHECK: 41
        (print bar))       ; CHECK: 43
    (print foo)))          ; CHECK: 13

(print foo) ; CHECK: 13
(bar)   ; CHECK: bar

; Shadow with parameter enclosing closure
((function (foo bar)
    ((function()
        (print foo)             ; CHECK: 59
        (print bar)))) 59 61)   ; CHECK: 61

(print foo) ; CHECK: 13
(bar)   ; CHECK: bar


;
; Copyright 2011-2013 Jeff Bush
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

; http://anler.me/posts/2015-09-17-recursion-aerobics.html

(function Y (f)
    ((function (x) (x x))(function (y) (f (function (arg) ((y y) arg))))))

(function makefib (f)
    (function (n)
        (if (< n 2)
            n
            (+ (f (- n 1)) (f (- n 2))))))

(assign fib (Y makefib))

(print (fib 8))    ; CHECK: 21
(print (fib 9))    ; CHECK: 34



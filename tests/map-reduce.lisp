;
; Copyright 2011-2015 Jeff Bush
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

(function map (values func)
    (if values
        (cons (func (first values)) (map (rest values) func))
        nil))

(function reduce-helper (accum values func)
    (if values
        (reduce-helper (func accum (first values)) (rest values) func)
        accum))

(function reduce (values func)
    (reduce-helper 0 values func))

(function sum-of-squares (values)
    (reduce (map values (function (x) (* x x))) (function (x y) (+ x y))))

(print (sum-of-squares '(2)))    ; CHECK: 4
(print (sum-of-squares '(3 5 7 9)))    ; CHECK: 164
(print (sum-of-squares nil))    ; CHECK: 0
(print (sum-of-squares '()))    ; CHECK: 0



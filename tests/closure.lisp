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

; Upvals are not fully implemented yet. Right now, this will return a compilation
; error.

(function mkgtr (x)
    (function (y) (> y x)))

(assign gtr7 (mkgtr 7))

(for x 0 10 1
    (begin
        (if (gtr7 x) (printchar 84) (printchar 70))
        (printchar 10)))


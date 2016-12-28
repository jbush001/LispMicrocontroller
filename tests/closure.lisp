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

(function make_between (low high)
    (function (value) (and (>= value low) (<= value high))))

(assign check (make_between 3 5))

(print check) ; CHECK: closure (3 5)

; Run a GC to ensure the closure is properly marked
($gc)

; If the GC did free the closure, this will clobber it
(cons 0 0)

; Now get back to testing that the closure works correctly
(for x 0 10 1
    (if (check x) ($printchar 84) ($printchar 70)))

; CHECK: FFFTTTFFFF


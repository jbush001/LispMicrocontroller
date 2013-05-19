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

; Test dot notation for creating cons cells directly

(assign a '(65 . 66))
(print (first a))	; CHECK: 65
(print (second a))	; CHECK: 66

(assign b '((12 . 22) . (47 . 59)))
(print (first (first b)))	; CHECK: 12
(print (second (first b)))	; CHECK: 22
(print (first (second b)))	; CHECK: 47
(print (second (second b)))		; CHECK: 59

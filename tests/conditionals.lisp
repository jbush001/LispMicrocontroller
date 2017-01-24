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

; Use variables so the optimizer doesn't hard code these values
(assign yes 1)
(assign no 0)

(if yes (print 1) (print 0)) ; CHECK: 1
(if no (print 1) (print 0)) ; CHECK: 0

; Test bare logical forms with 2 and 3 arguments. These get compiled differently
; than if because of short circuit evaluation.
(print (and no no)) ; CHECK: 0
(print (and no yes)) ; CHECK: 0
(print (and yes no)) ; CHECK: 0
(print (and yes yes)) ; CHECK: 1
(print (and no no no)) ; CHECK: 0
(print (and no no yes)) ; CHECK: 0
(print (and no yes no)) ; CHECK: 0
(print (and no yes yes)) ; CHECK: 0
(print (and yes no no)) ; CHECK: 0
(print (and yes no yes)) ; CHECK: 0
(print (and yes yes no)) ; CHECK: 0
(print (and yes yes yes)) ; CHECK: 1

; If forms of the same
(if (and no no) (print 1) (print 0)) ; CHECK: 0
(if (and no yes) (print 1) (print 0)) ; CHECK: 0
(if (and yes no) (print 1) (print 0)) ; CHECK: 0
(if (and yes yes) (print 1) (print 0)) ; CHECK: 1
(if (and no no no) (print 1) (print 0)) ; CHECK: 0
(if (and no no yes) (print 1) (print 0)) ; CHECK: 0
(if (and no yes no) (print 1) (print 0)) ; CHECK: 0
(if (and no yes yes) (print 1) (print 0)) ; CHECK: 0
(if (and yes no no) (print 1) (print 0)) ; CHECK: 0
(if (and yes no yes) (print 1) (print 0)) ; CHECK: 0
(if (and yes yes no) (print 1) (print 0)) ; CHECK: 0
(if (and yes yes yes) (print 1) (print 0)) ; CHECK: 1

; Perform same tests as above with or
(print (or no no)) ; CHECK: 0
(print (or no yes)) ; CHECK: 1
(print (or yes no)) ; CHECK: 1
(print (or yes yes)) ; CHECK: 1

(print (or no no no)) ; CHECK: 0
(print (or no no yes)) ; CHECK: 1
(print (or no yes no)) ; CHECK: 1
(print (or no yes yes)) ; CHECK: 1
(print (or yes no no)) ; CHECK: 1
(print (or yes no yes)) ; CHECK: 1
(print (or yes yes no)) ; CHECK: 1
(print (or yes yes yes)) ; CHECK: 1

(if (or no no) (print 1) (print 0)) ; CHECK: 0
(if (or no yes) (print 1) (print 0)) ; CHECK: 1
(if (or yes no) (print 1) (print 0)) ; CHECK: 1
(if (or yes yes) (print 1) (print 0)) ; CHECK: 1

(if (or no no no) (print 1) (print 0)) ; CHECK: 0
(if (or no no yes) (print 1) (print 0)) ; CHECK: 1
(if (or no yes no) (print 1) (print 0)) ; CHECK: 1
(if (or no yes yes) (print 1) (print 0)) ; CHECK: 1
(if (or yes no no) (print 1) (print 0)) ; CHECK: 1
(if (or yes no yes) (print 1) (print 0)) ; CHECK: 1
(if (or yes yes no) (print 1) (print 0)) ; CHECK: 1
(if (or yes yes yes) (print 1) (print 0)) ; CHECK: 1

; Mix and/or
(if (and (or no no) no) (print 1) (print 0)) ; CHECK: 0
(if (and (or no no) yes) (print 1) (print 0)) ; CHECK: 0
(if (and (or no yes) no) (print 1) (print 0)) ; CHECK: 0
(if (and (or no yes) yes) (print 1) (print 0)) ; CHECK: 1
(if (and (or yes no) no) (print 1) (print 0)) ; CHECK: 0
(if (and (or yes no) yes) (print 1) (print 0)) ; CHECK: 1
(if (and (or yes yes) no) (print 1) (print 0)) ; CHECK: 0
(if (and (or yes yes) yes) (print 1) (print 0)) ; CHECK: 1

(if (or (and no no) no) (print 1) (print 0)) ; CHECK: 0
(if (or (and no no) yes) (print 1) (print 0)) ; CHECK: 1
(if (or (and no yes) no) (print 1) (print 0)) ; CHECK: 0
(if (or (and no yes) yes) (print 1) (print 0)) ; CHECK: 1
(if (or (and yes no) no) (print 1) (print 0)) ; CHECK: 0
(if (or (and yes no) yes) (print 1) (print 0)) ; CHECK: 1
(if (or (and yes yes) no) (print 1) (print 0)) ; CHECK: 1
(if (or (and yes yes) yes) (print 1) (print 0)) ; CHECK: 1

; Make sure the value of the if expression itself is correct
(print (if yes 37 21)) ; CHECK: 37
(print (if no 51 72)) ; CHECK: 72

; Validate short circuit evaluation.
(and yes (print 97))    ; CHECK: 97
(and no (print 1))
(or yes (print 1))
(or no (print 34))    ; CHECK: 34

; unless and when macros (which just wrap ifs)
(unless no ($printchar #\A))
(unless yes ($printchar #\B))
(when no ($printchar #\C))
(when yes ($printchar #\D))
; CHECK: AD

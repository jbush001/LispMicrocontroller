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

(assign test1 '(1 (2 (3 4 5) 6) 7))
(assign test2 '(8 . 9))

(print (car test2)) ; CHECK: 8
(print (cdr test2)) ; CHECK: 9

(print (car test1)) ; CHECK: 1
(print (cdr test1)) ; CHECK: ((2 (3 4 5) 6) 7)
(print (cadr test1)) ; CHECK: (2 (3 4 5) 6)
(print (caadr test1)) ; CHECK: 2
(print (cadadr test1)) ; CHECK: (3 4 5)
(print (caadadr test1)) ; CHECK: 3


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

; When changing the test harness, call this to ensure it catches the error
;
; $ python3 runtests.py match-fail.lisp
; FAIL: line 27 expected string Hello was not found
; searching here:HALTED


($printstr "Hello")
($printchar 10)
($printstr "World")

; check strings must be matched in order. Even though both occur, there
; isn't a Hello after world, so this should fail on the second check.
; CHECK: World
; CHECK: Hello

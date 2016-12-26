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

; When changing the test harness, add this explicitly to the list of
; tests to ensure it fails

($printstr "Hello")
($printchar 10)
($printstr "World")

; Order is maintained by the CHECK strings. Even though both occur, there
; isn't a Hello after world, so this should fail on the second check.
; CHECK: World
; CHECK: Hello

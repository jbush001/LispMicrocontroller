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

;
; Recursive function call with conditional
;

(function fib (n)
	(if (< n 2)
		n
		(+ (fib (- n 1)) (fib (- n 2)))
	)
)

(for i 0 10 1
	(begin
		(printhex (fib i))
	)
)

; CHECK: 0000
; CHECK: 0001
; CHECK: 0001
; CHECK: 0002
; CHECK: 0003
; CHECK: 0005
; CHECK: 0008
; CHECK: 000D
; CHECK: 0015
; CHECK: 0022

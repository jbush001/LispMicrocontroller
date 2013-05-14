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

(function isprime (x)
	(let ((p true))
		(for i 2 (+ (sqrt x) 1) 1
			(if (mod x i)
				()			

				(begin
					(assign p false)
					(break)
				)
			)
		)

		p
	)
)

; Print a list of all prime numbers below 40
(for i 2 40 1
	(if (isprime i)
		(begin
			(print i)
		)
	)
)

; CHECK: 2
; CHECK: 3
; CHECK: 5
; CHECK: 7
; CHECK: 11
; CHECK: 13
; CHECK: 17
; CHECK: 19
; CHECK: 23
; CHECK: 29 
; CHECK: 31
; CHECK: 37

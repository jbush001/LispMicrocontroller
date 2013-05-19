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
; Modified Project Euler problem #2: Sum even fibonacci terms below 1000.
;

(function sum-even-fib (a b max total)
	(let ((next-sum (+ a b)))
		(if (< next-sum max)
			(sum-even-fib b next-sum max
				(if (bitwise-and next-sum 1)
					total  ; Odd
					(+ total next-sum))) ; Even
			total)))

(print (sum-even-fib 1 1 1000 0)) ; CHECK: 798


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
; On the cyclone II dev board, compute nth iteration of a fibonacci sequence and display
; on 7 segment display
;

(assign segments '(64 249 36 48 25 18 2 120 0 16))

(function set-display (num)
	(for register 2 6 1
		(begin
			(write-register register (nth segments (mod num 10)))
			(assign num (/ num 10)))))

(function fib (n)
    (if (< n 2)
        n
        (+ (fib (- n 1)) (fib (- n 2)))))

(assign a 0)
(while 1
	(set-display (fib a))
	(assign a (+ a 1))

	; Wait for key release
	(while (bitwise-and (read-register 6) 1)
		())

	; Wait for key press
	(while (= (bitwise-and (read-register 6) 1) 0)
		()))


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
; Library of standard macros and runtime functions
;

(defmacro foreach (var list expr)
	`(let ((,var 0)(nodePtr ,list))
		(while nodePtr
			(assign ,var (first nodePtr))
			,expr
			(assign nodePtr (rest nodePtr)))))

(defmacro for (var start end step expr)
	`(if (< ,step 0)
		; Decrementing
		(let ((,var ,start) (__endval ,end))
			(while (> ,var __endval) 
				,expr
				(assign ,var (+ ,var ,step))))

		; Incrementing
		(let ((,var ,start)(__endval ,end))
			(while (< ,var __endval) 
				,expr
				(assign ,var (+ ,var ,step))))))

(defmacro write-register (index value)
	`(store (- ,index 4096) ,value))

(defmacro read-register (index)
	`(load (- ,index 4096)))

; For debugging, uncomment the printchar lines to log GC actions
(defmacro gclog (prefix address)
	`(begin
;		($printchar ,prefix)
;		($printhex ,address)
;		($printchar 10)
	))

(defmacro atom? (ptr)
	`(= (bitwise-and (gettag ,ptr) 3) 0))

(defmacro list? (ptr)
	`(= (bitwise-and (gettag ,ptr) 3) 1))

(defmacro function? (ptr)
	`(= (bitwise-and (gettag ,ptr) 3) 2))

; Note that $heapstart is a variable created automatically
; by the compiler.  Wilderness is memory that has never been allocated and
; that we can simply slice off from.
(assign $wilderness-start $heapstart)
(assign $stacktop (getbp))	; This is called from top level main, so BP will be top of stack
(assign $max-heap (- $stacktop 1024)) 	
(assign $freelist nil)

; Mark a pointer, following links if it is a pair
(function $mark-recursive (ptr)
	(if (and ptr (list? ptr))	; Check if this is a cons and is not null
		(begin
			(let ((firstword (load ptr)) (tag (gettag firstword)))
				(if (not (rshift tag 2))
					(begin
						; An unmarked cons cell, mark it and continue
						(gclog 77 ptr)	; M
						(store ptr (settag firstword (bitwise-or tag 4)))

						; Check if we need to mark the first pointer
						($mark-recursive (first ptr)))))

			($mark-recursive (rest ptr)))))

; Mark a range of contiguous addresses.
(function $mark-range (start end)
	($mark-recursive (load start))
	(if (< start end)
		($mark-range (+ start 1) end)))

;
; Garbage collect, using mark-sweep algorithm
;

(function $gc ()
	(gclog 71 $wilderness-start)

	;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; Mark phase
	;;;;;;;;;;;;;;;;;;;;;;;;;;;

	; Clear GC flags 
	(for ptr $heapstart $wilderness-start 2
		(let ((val (load ptr)) (tag (gettag val)))
			(store ptr (settag val (bitwise-and tag 3)))))
	
	($mark-range 0 $heapstart)      ; Mark global variables
	($mark-range (getbp) $stacktop) ; Mark stack
	
	;;;;;;;;;;;;;;;;;;;;;;;;;;;
	; Sweep phase 
	;;;;;;;;;;;;;;;;;;;;;;;;;;;

	(assign $freelist nil)	; First clear the freelist so we don't double-add
	(for ptr $heapstart $wilderness-start 2
		(if (not (bitwise-and (gettag (load ptr)) 4))
			(begin
				; This is not used, stick it back in the free list.
				(store (+ 1 ptr) $freelist)
				(assign $freelist ptr)
				(gclog 70 ptr))))) 	; 'F'

(function $oom ()
	($printchar 79)
	($printchar 79)
	($printchar 77)
	($printchar 10)
	(while 1 ()))

;
; Allocate a new cell and return a pointer to it
;
(function cons (_first _rest)
	(let ((ptr nil))
		(if $freelist

			; There are nodes on freelist, grab one.
			(begin
				(assign ptr $freelist)
				(assign $freelist (rest ptr)))

			; Nothing on freelist, try to expand frontier
			(begin
				(if (< $wilderness-start $max-heap)
					; Space is available in frontier, snag from there.
					(begin
						(assign ptr $wilderness-start)
						(assign $wilderness-start (+ $wilderness-start 2)))

					; No more space available, need to garbage collect
					(begin
						($gc)
						(if $freelist
							; Then: got a block, assign it
							(begin
								(assign ptr $freelist)
								(assign $freelist (rest ptr)))

							; Else: GC gave us nothing, give up.
							($oom))))))

		(gclog 65 ptr) 	; 'A' Debug: print cell that has been allocated
		(store ptr _first)
		(store (+ ptr 1) _rest)
		(settag ptr 1)))	; Mark this as a cons cell and return

(function abs (x)
	(if (< x 0)
		(- 0 x)
		x))

(function $umul (multiplicand multiplier)
	(let ((product 0))
		(while multiplier
			(if (bitwise-and multiplier 1)
				(assign product (+ product multiplicand)))

			(assign multiplier (rshift multiplier 1))
			(assign multiplicand (lshift multiplicand 1)))
			
		product))

(function * (multiplicand multiplier)
	(let ((uprod ($umul (abs multiplicand) (abs multiplier))))
		(if (= (< multiplicand 0) (< multiplier 0))
			uprod			; same sign
			(- 0 uprod))))	; different signs

;
; Unsigned divide.  If getrem is 1, this will return the remainder.  Otherwise
; it will return the quotient
;
(function $udiv (divisor dividend getrem)
	(if (< divisor dividend)
		; If the divisor is less than the divident, division result will
		; be zero
		(if getrem
			divisor
			0)

		; Need to do division
		(let ((quotient 0) (dnext dividend) (numbits 0))
			; Align remainder and divisor
			(while (<= dnext divisor)
				(assign dividend dnext)
				(assign numbits (+ numbits 1))
				(assign dnext (lshift dnext 1)))
	
			; Divide
			(while numbits
				(assign quotient (lshift quotient 1))
				(if (>= divisor dividend)
					(begin
						(assign divisor (- divisor dividend))
						(assign quotient (bitwise-or quotient 1))))
			
				(assign dividend (rshift dividend 1))
				(assign numbits (- numbits 1)))
	
			(if getrem
				divisor
				quotient))))

(function / (divisor dividend)
	(let ((uquotient ($udiv (abs divisor) (abs dividend) 0)))
		(if (= (< divisor 0) (< dividend 0))
			uquotient			; same sign
			(- 0 uquotient))))	; different signs

(function mod (divisor dividend)
	(let ((uremainder ($udiv (abs divisor) (abs dividend) 1)))
		(if (< dividend 0)
			(- 0 uremainder)	
			uremainder)))

(function sqrt (num)
	(let ((guess num) (lastguess (+ num 3)))
		(while (> (- lastguess guess) 2)
			(assign lastguess guess)
			(assign guess (/ (+ guess (/ num guess)) 2)))
		guess))

(function $printchar (x)
	(write-register 0 x))

(function $printstr (x)
	(foreach ch x
		($printchar ch)))

; Print a number in decimal format
(function $printdec (num)
	(if (< num 0)
		(begin
			; Negative number
			(assign num (- 0 num))
			($printchar 45)))	; minus sign

	(if num
		; Not zero
		(let ((str nil))
			(while num
				(assign str (cons (mod num 10) str))
				(assign num (/ num 10)))

			(foreach ch str
				($printchar (+ 48 ch))))

		; Is zero
		($printchar 48)))

(function $printhex (num)
	(for idx 0 16 4
		(let ((digit (bitwise-and (rshift num (- 12 idx)) 15)))
			(if (< digit 10)
				($printchar (+ digit 48))
				($printchar (+ digit 55))))))	; - 10 + 'A'

(function print (x)
	(if (list? x)
		;; This is a list
		(begin
			($printchar 40)	; Open paren
			(let ((needspace false))
				(foreach element x
					(begin
						(if needspace
							($printchar 32)
							(assign needspace true))
						(print element))))
	
			($printchar 41)))		; Close paren

	(if (atom? x)
		;; This is a number
		($printdec x))

	(if (function? x)
		;; This is a function
		(begin
			($printstr "function")
			($printhex x))))

(function nth (list index)
	(if list
		(if index 
			(nth (rest list) (- index 1)) ; Keep traversing
			(first list))                 ; Found item at index
		nil))	                          ; Index is beyond length of list

(function $$length-helper (list length)
	(if list
		($$length-helper (rest list) (+ length 1))
		length))

(function length (list)
	($$length-helper list 0))

(function append (list element)
	(if list
		(cons (first list) (append (rest list) element))
		(cons element nil)))

(function $$reverse_recursive (forward backward)
	(if forward
		($$reverse_recursive (rest forward) (cons (first forward) backward))
		backward))

(function reverse (list)
	($$reverse_recursive list nil))

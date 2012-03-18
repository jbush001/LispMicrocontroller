;
; Library of standard macros and runtime functions
;

(defmacro foreach (var list expr)
	`(let ((,var 0)(nodePtr ,list))
		(while nodePtr
			(assign ,var (first nodePtr))
			,expr
			(assign nodePtr (rest nodePtr))
		)
	)
)

(defmacro for (var start end step expr)
	`(if (< ,step 0)
		; Decrementing
		(let ((,var ,start) (__endval ,end))
			(while (> ,var __endval) 
				,expr
				(assign ,var (+ ,var ,step))
			)
		)

		; Incrementing
		(let ((,var ,start)(__endval ,end))
			(while (< ,var __endval) 
				,expr
				(assign ,var (+ ,var ,step))
			)
		)
	)
)

(defmacro write-register (index value)
	`(store (- ,index 4096) ,value)
)

(defmacro read-register (index)
	`(load (- ,index 4096))
)

(defmacro gclog (prefix address)
	`(begin
;		(printchar ,prefix)
;		(printhex ,address)
;		(printchar 10)
	)
)

; Note that $heapstart is a variable created automatically
; by the compiler.  Wilderness is memory that has never been allocated and
; that we can simply slice off from.
(assign $wilderness-start $heapstart)
(assign $stacktop (getbp))	; This is called from top level main, so BP will be top of stack
(assign $max-heap (- $stacktop 1024)) 	
(assign $freelist 0)

(function $mark-recursive (ptr)
	(let ((tag (gettag ptr)))
		(while (and tag (= (and tag 3) 1))	; Check if this is a cons and is not null
			(let ((firstword (load ptr)) (gcflag (gettag firstword)))
				(if (= (rshift gcflag 2) 0)
					(begin
						; An unmarked cons cell, mark it and continue
						(gclog 77 ptr)	; M
						(store ptr (settag firstword (or gcflag 4)))
	
						; Check if we need to mark the first pointer
						($mark-recursive (first ptr))
					)
				)
			)

			; Check next node
			(assign ptr (rest ptr))
			(assign tag (gettag ptr))
		)
	)
)

(function $gc ()
	(begin
		(gclog 71 $wilderness-start)

		; Mark phase ;;;;;;;;;;;;;

		; clear flags 
		(for ptr $heapstart $wilderness-start 2
			(let ((val (load ptr)) (tag (gettag val)))
				(store ptr (settag val (and tag 3)))
			)
		)
		
		; Walk globals
		(for ptr 0 $heapstart 1
			($mark-recursive (load ptr))
		)

		; Walk stack
		(for ptr (getbp) $stacktop 1
			($mark-recursive (load ptr))		
		)
		
		; Sweep ;;;;;;;;;;;;;
		
		(assign $freelist 0)	; First clear the freelist so we don't double-add
		(for ptr $heapstart $wilderness-start 2
			(if (and (gettag (load ptr)) 16)
				()	; do nothing, this is in-use
				(begin
					(gclog 70 ptr) 	; 'F'

					; This is not used, stick it back in the free list.
					(store (+ 1 ptr) $freelist)
					(assign $freelist ptr)
				)
			)
		)
	)
)

(function $oom ()
	(begin
		(printchar 79)
		(printchar 79)
		(printchar 77)
		(printchar 10)
		(while 1 ())
	)
)

;
; Allocate a new cell and return a pointer to it
;
(function cons (first rest)
	(let ((ptr 0))
		(if $freelist

			; There are nodes on freelist, grab one.
			(begin
				(assign ptr $freelist)
				(assign $freelist (rest ptr))
			)

			; Nothing on freelist, try to expand frontier
			(begin
				(if (< $wilderness-start $max-heap)
					; Space is available in frontier, snag from there.
					(begin
						(assign ptr $wilderness-start)
						(assign $wilderness-start (+ $wilderness-start 2))
					)

					; No more space available, need to GC
					(begin
						($gc)
						(if (= $freelist 0)
							; GC gave us nothing, give up.
							($oom)
						
							; Got a block, assign it
							(begin
								(assign ptr $freelist)
								(assign $freelist (rest ptr))
							)
						)
					)
				)
			)
		)

		; Debug: print cell that has been allocated
		(gclog 65 ptr) 	; 'A'

		(store ptr first)
		(store (+ ptr 1) rest)
		(settag ptr 1)	; Mark this as a cons cell and return
	)
)

(function abs (x)
	(if (< x 0)
		(- 0 x)
		x
	)
)

(function $umul (multiplicand multiplier)
	(let ((product 0))
		(while multiplier
			(if (and multiplier 1)
				(assign product (+ product multiplicand))
			)

			(assign multiplier (rshift multiplier 1))
			(assign multiplicand (lshift multiplicand 1))
		)
		
		product
	)
)

(function * (multiplicand multiplier)
	(let ((uprod ($umul (abs multiplicand) (abs multiplier))))
		(if (= (< multiplicand 0) (< multiplier 0))
			uprod			; same sign
			(- 0 uprod)		; different signs
		)
	)
)

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
			0
		)

		; Need to do division
		(let ((quotient 0) (dnext dividend) (numbits 0))
			; Align remainder and divisor
			(while (<= dnext divisor)
				(assign dividend dnext)
				(assign numbits (+ numbits 1))
				(assign dnext (lshift dnext 1))
			)
	
			; Divide
			(while numbits
				(assign quotient (lshift quotient 1))
				(if (>= divisor dividend)
					(begin
						(assign divisor (- divisor dividend))
						(assign quotient (or quotient 1))
					)
				)
			
				(assign dividend (rshift dividend 1))
				(assign numbits (- numbits 1))		
			)
	
			(if getrem
				divisor
				quotient
			)
		)
	)
)

(function / (divisor dividend)
	(let ((uquotient ($udiv (abs divisor) (abs dividend) 0)))
		(if (= (< divisor 0) (< dividend 0))
			uquotient			; same sign
			(- 0 uquotient)		; different signs
		)
	)
)

(function mod (divisor dividend)
	(let ((uremainder ($udiv (abs divisor) (abs dividend) 1)))
		(if (< dividend 0)
			(- 0 uremainder)	
			uremainder
		)
	)
)

(function sqrt (num)
	(let ((guess num) (lastguess 0))
		(while (> (- lastguess guess) 2)
			(assign lastguess guess)
			(assign guess (/ (+ guess (/ num guess)) 2))
		)
		
		guess
	)
)

(function printchar (x)
	(write-register 0 x)
)

(function printstr (x)
	(foreach ch x
		(printchar ch)
	)
)

(function printhex (num)
	(for idx 0 16 4
		(let ((digit (and (rshift num (- 12 idx)) 15)))
			(if (< digit 10)
				(printchar (+ digit 48))
				(printchar (+ digit 55))	; - 10 + 'A'
			)
		)
	)
)

; Print a number in decimal format
(function printdec (num)
	(if num
		; Not zero
		(let ((str 0))
			(while num
				(assign str (cons (mod num 10) str))
				(assign num (/ num 10))
			)
	
			(foreach ch str
				(printchar (+ 48 ch))
			)
		)

		; Is zero
		(printchar 48)
	)
)

(function nth (list index)
	(begin
		(while (and (> index 0) (<> list 0))
			(assign list (rest list))
			(assign index (- index 1))
		)
	
		(if list
			(first list)
			0
		)
	)
)

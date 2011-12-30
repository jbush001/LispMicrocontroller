;
; Library of standard macros and runtime functions
;

(defmacro if (a b c)
	`(cond 
		(,a ,b)
		(1 ,c)
	)
)

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
	`(let ((,var ,start))
		(while (<> ,var ,end) 
			,expr
			(assign ,var (+ ,var ,step))
		)
	)
)

(defmacro write-register (index value)
	`(store (- ,index 128) ,value)
)

(defmacro read-register (index)
	`(load (- ,index 128))
)

; Note that $globalstart and $heapstart are variables created automatically
; by the compiler.  Wilderness is memory that has never been allocated and
; that we can simply slice off from.
(assign $wilderness-start $heapstart)
(assign $stacktop (getbp))	; This is called from top level main, so BP will be top of stack
(assign $max-heap (- $stacktop 1024)) 	
(assign $freelist 0)

(function $mark-recursive (ptr)
	(let ((tag (gettag ptr)))
		(if (and tag (= (and tag 7) 1))	; Check if this is a cons and is not null
			(let ((firstword (load ptr)) (gcflag (gettag firstword)))
				(if (= (rshift gcflag 3) 0)
					(begin
						; An unmarked cons cell, mark it and continue

						; Debug: print cell that is being marked
						; (printchar 77)		; 'M'
						; (printhex ptr)
						; (printchar 10)
		
						(store ptr (settag firstword (or gcflag 8)))
						($mark-recursive (first ptr))
						($mark-recursive (rest ptr))
					)
					()
				)
			)
			()
		)
	)
)

(function $clear-flags ()
	(for ptr $heapstart $wilderness-start 2
		(let ((val (load ptr)) (tag (gettag val)))
			(store ptr (settag val (and tag 7)))
		)
	)
)

(function $gc ()
	(begin
		; Debug: print start of GC
		; (printchar 71) ; 'G'
		; (printchar 10)

		; Mark phase: clear flags and recursively walk elements
		($clear-flags)
		
		; Walk globals
		(for ptr $globalstart $heapstart 1
			($mark-recursive (load ptr))
		)

		; Walk stack
		(for ptr (getbp) $stacktop 1
			($mark-recursive (load ptr))		
		)
		
		; Sweep
		(assign $freelist 0)	; First clear the freelist so we don't double-add
		(for ptr $heapstart $wilderness-start 2
			(if (and (gettag (load ptr)) 16)
				()	; do nothing, this is in-use
				(begin
					; Debug: print cell that is being freed
					; (printchar 70) ; 'F'
					; (printhex ptr)
					; (printchar 10)
					
					; This is not used, stick it back in the free list.
					(store (+ 1 ptr) $freelist)
					(assign $freelist ptr)
				)
			)
		)
	)
)

;
; Allocate a new cell and return a pointer to it
;
(function cons (first rest)
	(let ((ptr 0))
		(if $freelist
			(begin
				; There are nodes on freelist, grab one.
				(assign ptr $freelist)
				(assign $freelist (rest ptr))
			)
			(begin
				; Nothing on freelist, try to expand frontier
				(if (>= $wilderness-start $max-heap)
					($gc)	; No room, try to gc
					()
				)
	
				; XXX could fail here if OOM.  Now just goes into weeds.
	
				(assign ptr $wilderness-start)
				(assign $wilderness-start (+ $wilderness-start 2))
			)
		)

		; Debug: print cell that has been allocated
		; (printchar 65)	; 'A'
		; (printhex ptr)
		; (printchar 10)

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
				()
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
					()
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

(function % (divisor dividend)
	(let ((uremainder ($udiv (abs divisor) (abs dividend) 1)))
		(if (< dividend 0)
			(- 0 uremainder)	
			uremainder
		)
	)
)

(function sqrt (num)
	(let ((guess num) (lastguess 0))
		(while (<> lastguess guess)
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
				(assign str (cons (% num 10) str))
				(assign num (/ num 10))
			)
	
			(foreach ch str
				(printchar (+48 ch))
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

;
; Library of standard macros and runtime functions
;

(defmacro function (x y z)
	`(assign ,x (lambda ,y
		,z
	))
)

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
		(while (< ,var ,end) 
			,expr
			(assign ,var (+ ,var ,step))
		)
	)
)

(defmacro printchar (x)
	`(store 16383 ,x)
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

(assign $heapend $heapstart)
(assign $max-heap 512)
(assign $stacktop 4096)
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
	(for ptr $heapstart $heapend 2
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
		(for ptr ($bp) $stacktop 1
			(begin
				($mark-recursive (load ptr))		
			)
		)
		
		; Sweep
		(for ptr $heapstart $max-heap 2
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
				(if (>= $heapend $max-heap)
					($gc)	; No room, try to gc
					()
				)
	
				; XXX could fail here if OOM.  Now just goes into weeds.
	
				(assign ptr $heapend)
				(assign $heapend (+ $heapend 2))
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

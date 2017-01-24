;
; Copyright 2011-2016 Jeff Bush
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

(function make_between (low high)
    (function (value) (and (>= value low) (<= value high))))

(assign check (make_between 3 5))

(print check) ; CHECK: closure (3 5)

; Run a GC to ensure the closure is properly marked
($gc)

; If the GC did free the closure, this will clobber it
(cons 0 0)

; Now test that the closure works correctly
(for x 0 10 1
    (if (check x) ($printchar #\T) ($printchar #\F)))

; CHECK: FFFTTTFFFF


; Verify that, if a free variable is copied from a function outside the
; immediate parent, it is copied across all function (create shadow
; closures in intermediate functions).
(function foo (a)
    (function ()
        (function ()
            (function ()
                (print a)))))

((((foo 19))))  ; CHECK: 19

; Update variable inside a closure
; Because we capture by value and not reference, the updated value does
; not affect the closure.
(function make_func1 (a)
    (function ()
        (assign a (+ a 1))
        (print a)))

(assign func1 (make_func1 17))
(func1) ; CHECK: 18
(func1) ; CHECK: 18
(func1) ; CHECK: 18

; Update outer variable after creating closure. Ensure closure has old value.
(function make_func2 ()
    (let ((a 37) (b (function () (print a))))
        (assign a 2)
        b))

((make_func2)) ; CHECK: 37

; Update variable inside closure. Check that outer variable isn't affected
(function test_update_inside ()
    (let ((a 47))
        ((function () (assign a 51)))
        (print a)))

(test_update_inside)  ; CHECK 47

; Multiple closures share a variable.
; Calling the function only updates local copy
(function make_funcs1 ()
    (let ((funclist nil) (x 0))
        (while (< x 10)
            (assign funclist (cons (function () (print x)) funclist))
            (assign x (+ x 1)))
        funclist))

(foreach func (make_funcs1)
    (func))

; CHECK: 9876543210

; We can share a variable by creating a reference to a cons cell.
; When each closure runs, it updates the cell.
(function make_funcs2 ()
    (let ((funclist nil) (sharedref (cons 27 0)))
        (for x 0 5 1
            (assign funclist (cons (function ()
                (setfirst sharedref (+ (first sharedref) 1))
                (print (first sharedref))) funclist)))
        funclist))

(foreach func (make_funcs2)
    (func))

; CHECK: 2829303132

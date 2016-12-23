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


(write-register 3 160)
(write-register 6 1)            ; enable sprite 0 (player rocket)
(write-register 4 (- 240 30))    ; y coord (a little up from the bottom)
(assign x0 (- 160 8))

(while 1
    ; Wait for start of vblank
    (while (<> (read-register 1) 1)
        ())

    ; Set up sprite 0
    (write-register 3 x0)    ; X coord
    (write-register 5 animationFrame)    ; animation frame

    ; Set up missile
    (write-register 7 missile-x)
    (write-register 8 missile-y)
    (write-register 9 (+ 2 animationFrame))    ; animation frame
    (write-register 10 missile-active)

    ; Wait for end of vblank
    (while (read-register 1)
        ())

    ; Left?
    (if (<> (bitwise-and (read-register 0) 1) 0)
        (if (> x0 3)
            (assign x0 (- x0 3))))

    ; Move right?
    (if (<> (bitwise-and (read-register 0) 2) 0)
        (if (< x0 (- 320 (+ 16 3)))
            (assign x0 (+ x0 3))))

    ; Update missile
    (if missile-active
        ; Missile is active
        (begin
            (assign missile-y (- missile-y 2))
            (if (< missile-y -16)
                (assign missile-active 0)))        ; Missile off top of screen

        ; Missile is not active, test for firing
        (if (= (bitwise-and (read-register 0) 4) 0)    ; Not clear why this is inverted
            (begin
                (assign missile-active 1)
                (assign missile-y (- 240 32))
                (assign missile-x x0))))

    ; Animate
    (if (= animation-delay 0)
        ; Animate jet exhaust
        (begin
            (assign animationFrame (- 1 animationFrame))
            (assign animation-delay 3))
        (assign animation-delay (- animation-delay 1))))



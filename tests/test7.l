
(assign a 7)
(assign b -7)

(printhex (* -231 a))		; negative times positive
(printchar 10)
(printhex (* -231 b))		; negative times negative
(printchar 10)
(printhex (* 231 a))		; positive times positive
(printchar 10)
(printhex (* 231 b))		; positive times negative
(printchar 10)
(printhex (* 0 a))			; zero identity
(printchar 10)
(printhex (* a 0))			; zero identity
(printchar 10)

(printhex (/ -2317 a))		; negative / positive
(printchar 10)
(printhex (/ -2317 b))		; negative / negative
(printchar 10)
(printhex (/ 2317 a))		; positive / positive
(printchar 10)
(printhex (/ 2317 b))		; positive / negative
(printchar 10)
(printhex (/ a 2317))		; divisor < dividend
(printchar 10)
(printhex (/ 0 a))			; zero identity
(printchar 10)

(printhex (mod -2319 a))		; negative / positive
(printchar 10)
(printhex (mod -2319 b))		; negative / negative
(printchar 10)
(printhex (mod 2319 a))		; positive / positive
(printchar 10)
(printhex (mod 2319 b))		; positive / negative
(printchar 10)

(printhex (sqrt 1902))
(printchar 10)

; Expected output:
; F9AF
; 0651
; 0651
; F9AF
; 0000
; 0000
; FEB5
; 014B
; 014B
; FEB5
; 0000
; 0000
; 0002
; FFFE
; 0002
; FFFE
; 002B

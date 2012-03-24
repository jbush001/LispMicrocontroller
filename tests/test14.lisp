(printhex ((function (x y) (+ x y)) 2 3))
(printchar 10)

(function mkcomp () (function (z) (+ z 13)))
(printhex ((mkcomp) 19))
(printchar 10)

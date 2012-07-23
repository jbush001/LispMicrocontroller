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

; Use variables so the optimizer doesn't hard code these values
(assign true 1)
(assign false 0)

(printhex (and true true))	; 1
(printchar 10)

(printhex (and true false)) ; 0
(printchar 10)

(printhex (and false true)) ; 0
(printchar 10)

(printhex (and false false)) ; 0
(printchar 10)

(printhex (or true true)) ; 1
(printchar 10)

(printhex (or true false)) ; 1
(printchar 10)

(printhex (or false true)) ; 1
(printchar 10)

(printhex (or false false)) ; 0
(printchar 10)

(if (and true true) ; 1
	(printhex 1)
	(printhex 0)
)
(printchar 10)

(if (and true false) ; 0
	(printhex 1)
	(printhex 0)
)
(printchar 10)

(if (and false true) ; 0
	(printhex 1)
	(printhex 0)
)
(printchar 10)

(if (and false false) ; 0
	(printhex 1)
	(printhex 0)
)
(printchar 10)

(if (or true true) ; 1
	(printhex 1)
	(printhex 0)
)
(printchar 10)

(if (or true false) ; 1
	(printhex 1)
	(printhex 0)
)
(printchar 10)

(if (or false true) ; 1
	(printhex 1)
	(printhex 0)
)
(printchar 10)

(if (or 0 0) ; 0
	(printhex 1)
	(printhex 0)
)
(printchar 10)

; Now check that we short-circuit properly
(printhex (and true true)) ; 1
(printchar 10)

(printhex (and true false)) ; 0
(printchar 10)

; 0001
; 0000
; 0000
; 0000
; 0001
; 0001
; 0001
; 0000
; 0001
; 0000
; 0000
; 0000
; 0001
; 0001
; 0001
; 0000
; 0001
; 0000

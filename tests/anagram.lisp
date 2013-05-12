; 
; Copyright 2011-2013 Jeff Bush
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

(function removenth (list index)
	(if (and index list)
		(cons (first list) (removenth (rest list) (- index 1)))
		
		; At the index, return the next after
		(rest list)
	)
)

(function anagram (prefix suffix)
	(if suffix
		(for x 0 (length suffix) 1
			(anagram (append prefix (nth suffix x)) (removenth suffix x))
		)

		(begin
			(printstr prefix)
			(printchar 10)
		)
	)
)

(anagram () "lisp")
 
; CHECK: lisp
; CHECK: lips
; CHECK: lsip
; CHECK: lspi
; CHECK: lpis
; CHECK: lpsi
; CHECK: ilsp
; CHECK: ilps
; CHECK: islp
; CHECK: ispl
; CHECK: ipls
; CHECK: ipsl
; CHECK: slip
; CHECK: slpi
; CHECK: silp
; CHECK: sipl
; CHECK: spli
; CHECK: spil
; CHECK: plis
; CHECK: plsi
; CHECK: pils
; CHECK: pisl
; CHECK: psli
; CHECK: psil


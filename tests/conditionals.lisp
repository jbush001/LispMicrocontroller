; Use variables so the optimizer doesn't hard code these values
(assign yes 1)
(assign no 0)

(printdec (and no no)) ; CHECK: 0
(printdec (and no yes)) ; CHECK: 0
(printdec (and yes no)) ; CHECK: 0
(printdec (and yes yes)) ; CHECK: 1

(printdec (and no no no)) ; CHECK: 0
(printdec (and no no yes)) ; CHECK: 0
(printdec (and no yes no)) ; CHECK: 0
(printdec (and no yes yes)) ; CHECK: 0
(printdec (and yes no no)) ; CHECK: 0
(printdec (and yes no yes)) ; CHECK: 0
(printdec (and yes yes no)) ; CHECK: 0
(printdec (and yes yes yes)) ; CHECK: 1

(if (and no no) (printdec 1) (printdec 0)) ; CHECK: 0
(if (and no yes) (printdec 1) (printdec 0)) ; CHECK: 0
(if (and yes no) (printdec 1) (printdec 0)) ; CHECK: 0
(if (and yes yes) (printdec 1) (printdec 0)) ; CHECK: 1

(if (and no no no) (printdec 1) (printdec 0)) ; CHECK: 0
(if (and no no yes) (printdec 1) (printdec 0)) ; CHECK: 0
(if (and no yes no) (printdec 1) (printdec 0)) ; CHECK: 0
(if (and no yes yes) (printdec 1) (printdec 0)) ; CHECK: 0
(if (and yes no no) (printdec 1) (printdec 0)) ; CHECK: 0
(if (and yes no yes) (printdec 1) (printdec 0)) ; CHECK: 0
(if (and yes yes no) (printdec 1) (printdec 0)) ; CHECK: 0
(if (and yes yes yes) (printdec 1) (printdec 0)) ; CHECK: 1

(printdec (or no no)) ; CHECK: 0
(printdec (or no yes)) ; CHECK: 1
(printdec (or yes no)) ; CHECK: 1
(printdec (or yes yes)) ; CHECK: 1

(printdec (or no no no)) ; CHECK: 0
(printdec (or no no yes)) ; CHECK: 1
(printdec (or no yes no)) ; CHECK: 1
(printdec (or no yes yes)) ; CHECK: 1
(printdec (or yes no no)) ; CHECK: 1
(printdec (or yes no yes)) ; CHECK: 1
(printdec (or yes yes no)) ; CHECK: 1
(printdec (or yes yes yes)) ; CHECK: 1

(if (or no no) (printdec 1) (printdec 0)) ; CHECK: 0
(if (or no yes) (printdec 1) (printdec 0)) ; CHECK: 1
(if (or yes no) (printdec 1) (printdec 0)) ; CHECK: 1
(if (or yes yes) (printdec 1) (printdec 0)) ; CHECK: 1

(if (or no no no) (printdec 1) (printdec 0)) ; CHECK: 0
(if (or no no yes) (printdec 1) (printdec 0)) ; CHECK: 1
(if (or no yes no) (printdec 1) (printdec 0)) ; CHECK: 1
(if (or no yes yes) (printdec 1) (printdec 0)) ; CHECK: 1
(if (or yes no no) (printdec 1) (printdec 0)) ; CHECK: 1
(if (or yes no yes) (printdec 1) (printdec 0)) ; CHECK: 1
(if (or yes yes no) (printdec 1) (printdec 0)) ; CHECK: 1
(if (or yes yes yes) (printdec 1) (printdec 0)) ; CHECK: 1

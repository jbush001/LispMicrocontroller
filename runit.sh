iverilog -o core.vvp testbench.v lisp_core.v
./compile.py $1
vvp core.vvp

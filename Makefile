
VERILOG_SRCS =	ulisp.v \
		testbench.v \
		rom.v \
		ram.v \
		lisp_core.v

IVFLAGS=-Wall -Winfloop -Wno-sensitivity-entire-array

sim.vvp: $(VERILOG_SRCS)
	iverilog -o $@ $(IVFLAGS) $(VERILOG_SRCS)

clean:
	rm sim.vvp

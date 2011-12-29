`timescale 1us/1us

//`define TRACE 1

module testbench;

	reg 				clk;
	integer 			i;
	integer 			j;
	wire[6:0]			register_index;
	wire				register_read;
	wire				register_write;
	wire[15:0]			register_write_value;
	reg[15:0]			register_read_value = 0;
	
	lisp_core l(
		.clk(clk),
		.register_index(register_index),
		.register_read(register_read),
		.register_write(register_write),
		.register_write_value(register_write_value),
		.register_read_value(register_read_value));
	
	initial
	begin
		clk = 0;

		$dumpfile("trace.vcd");
		$dumpvars(100, l);
		
		for (i = 0; i < 27000000; i = i + 1)
		begin
			#5 clk = ~clk;

`ifdef TRACE
			if (clk) dumpstate;
`endif
		end
	end
	
	always @(posedge clk)
	begin
		if (register_write && register_index == 0)
			$write("%c", register_write_value);
		
		if (register_write && register_index == 1)
			$display("set leds %b", register_write_value);
	end

	task dumpstate;
	begin
		$write("%d ", l.instruction_pointer / 4);

		case (l.opcode)
			l.OP_NOP: 		$write("nop");
			l.OP_CALL: 		$write("call");
			l.OP_RETURN: 	$write("return");
			l.OP_POP: 		$write("pop");
			l.OP_LOAD: 		$write("load");
			l.OP_STORE: 	$write("store");
			l.OP_ADD: 		$write("add");
			l.OP_SUB: 		$write("sub");
			l.OP_REST: 		$write("rest");
			l.OP_GTR: 		$write("gtr");
			l.OP_GTE: 		$write("gte");
			l.OP_EQ: 		$write("eq");
			l.OP_NEQ: 		$write("new");
			l.OP_DUP: 		$write("dup");
			l.OP_GETTAG: 	$write("gettag");
			l.OP_SETTAG: 	$write("settag");
			l.OP_RESERVE:	$write("reserve");
			l.OP_PUSH: 		$write("push");
			l.OP_GOTO: 		$write("goto");
			l.OP_BFALSE: 	$write("bfalse");
			l.OP_GETLOCAL: 	$write("getlocal");
			l.OP_SETLOCAL: 	$write("setlocal");
			l.OP_CLEANUP: 	$write("cleanup");
			l.OP_AND: 		$write("and");
			l.OP_OR: 		$write("or");
			l.OP_XOR: 		$write("xor");
			l.OP_LSHIFT: 	$write("lshift");
			l.OP_RSHIFT: 	$write("rshift");
		endcase

		if (l.opcode[4:3] == 2'b11)
			$write(" %d", l.param);

		$write("\t");

		case (l.state)
			l.STATE_IADDR_ISSUE: 		$write("IADDR_ISSUE");
			l.STATE_DECODE: 			$write("DECODE");
			l.STATE_GOT_NOS: 			$write("GOT_NOS");
			l.STATE_LOAD_TOS1: 			$write("LOAD_TOS1");
			l.STATE_PUSH_MEM_RESULT: 	$write("PUSH_MEM_RESULT");
			l.STATE_GETLOCAL2: 			$write("GETLOCAL2");
			l.STATE_RETURN2: 			$write("RETURN2");
			l.STATE_CALL2: 				$write("CALL2");
			l.STATE_RETURN3: 			$write("RETURN3");
		endcase
	
		$write("\tstack(%d) ", l.stack_pointer);
		$write(" %d", l.top_of_stack);
		for (j = 0; j < 5; j = j + 1)
			$write(" %d", l.mem.data[l.stack_pointer + j]);
	
		$write("\n");
		if (l.mem_write_enable)
			$display(" mem %d <= %d", l.mem_addr, l.mem_write_value);

	end
	endtask


endmodule

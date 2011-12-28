`timescale 1us/1us

//`define TRACE 1

module testbench;

	reg clk;
	integer i;
	integer j;
	
	ulisp u(
		.clk(clk));
	
	initial
	begin
		clk = 0;

		$dumpfile("trace.vcd");
		$dumpvars(100, u);
		
		for (i = 0; i < 500000; i = i + 1)
		begin
			#5 clk = ~clk;

`ifdef TRACE
			if (clk) dumpstate;
`endif
		end
	end

	task dumpstate;
	begin
		$write("%d ", u.instruction_pointer / 4);

		case (u.opcode)
			u.OP_NOP: 		$write("nop");
			u.OP_CALL: 		$write("call");
			u.OP_RETURN: 	$write("return");
			u.OP_POP: 		$write("pop");
			u.OP_LOAD: 		$write("load");
			u.OP_STORE: 	$write("store");
			u.OP_ADD: 		$write("add");
			u.OP_SUB: 		$write("sub");
			u.OP_CDR: 		$write("cdr");
			u.OP_GTR: 		$write("gtr");
			u.OP_GTE: 		$write("gte");
			u.OP_EQ: 		$write("eq");
			u.OP_NEQ: 		$write("new");
			u.OP_DUP: 		$write("dup");
			u.OP_GETTAG: 	$write("gettag");
			u.OP_SETTAG: 	$write("settag");
			u.OP_RESERVE:	$write("reserve");
			u.OP_PUSH: 		$write("push");
			u.OP_GOTO: 		$write("goto");
			u.OP_BFALSE: 	$write("bfalse");
			u.OP_GETLOCAL: 	$write("getlocal");
			u.OP_SETLOCAL: 	$write("setlocal");
			u.OP_CLEANUP: 	$write("cleanup");
			u.OP_AND: 		$write("and");
			u.OP_OR: 		$write("or");
			u.OP_XOR: 		$write("xor");
			u.OP_LSHIFT: 	$write("lshift");
			u.OP_RSHIFT: 	$write("rshift");
		endcase

		if (u.opcode[4:3] == 2'b11)
			$write(" %d", u.param);

		$write("\t");

		case (u.state)
			u.STATE_IADDR_ISSUE: 		$write("IADDR_ISSUE");
			u.STATE_DECODE: 			$write("DECODE");
			u.STATE_GOT_NOS: 			$write("GOT_NOS");
			u.STATE_LOAD_TOS1: 			$write("LOAD_TOS1");
			u.STATE_PUSH_MEM_RESULT: 	$write("PUSH_MEM_RESULT");
			u.STATE_GETLOCAL2: 			$write("GETLOCAL2");
			u.STATE_RETURN2: 			$write("RETURN2");
			u.STATE_CALL2: 				$write("CALL2");
			u.STATE_RETURN3: 			$write("RETURN3");
		endcase
	
		$write("\tstack(%d) ", u.stack_pointer);
		$write(" %d", u.top_of_stack);
		for (j = 0; j < 5; j = j + 1)
			$write(" %d", u.mem.data[u.stack_pointer + j]);
	
		$write("\n");
		if (u.mem_write_enable)
			$display(" mem %d <= %d", u.mem_addr, u.mem_write_value);

	end
	endtask


endmodule

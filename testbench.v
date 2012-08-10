// 
// Copyright 2011-2012 Jeff Bush
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// 
//     http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// 

`timescale 1us/1us

//`define TRACE 1

module testbench;

	reg 				clk;
	integer 			i;
	integer 			j;
	wire[11:0]			register_index;
	wire				register_read;
	wire				register_write;
	wire[15:0]			register_write_value;
	reg[15:0]			register_read_value = 0;
	
	ulisp l(
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

		for (i = 0; i < 100000; i = i + 1)
		begin
			#5 clk = ~clk;

`ifdef TRACE
			if (clk) dumpstate;
`endif
		end
	end
	
	always @(posedge clk)
	begin	
		if (register_write)
		begin
			if (register_index == 0)
				$write("%c", register_write_value);
			else
				$display("set register %d <= %d", register_index, register_write_value);
		end
	end

	task dumpstate;
	begin
		if (l.c.opcode != 0)
		begin
			$write("%d ", l.c.instruction_pointer);
	
			case (l.c.opcode)
				l.c.OP_NOP: 		$write("nop");
				l.c.OP_CALL: 		$write("call");
				l.c.OP_RETURN: 	$write("return");
				l.c.OP_POP: 		$write("pop");
				l.c.OP_LOAD: 		$write("load");
				l.c.OP_STORE: 	$write("store");
				l.c.OP_ADD: 		$write("add");
				l.c.OP_SUB: 		$write("sub");
				l.c.OP_REST: 		$write("rest");
				l.c.OP_GTR: 		$write("gtr");
				l.c.OP_GTE: 		$write("gte");
				l.c.OP_EQ: 		$write("eq");
				l.c.OP_NEQ: 		$write("new");
				l.c.OP_DUP: 		$write("dup");
				l.c.OP_GETTAG: 	$write("gettag");
				l.c.OP_SETTAG: 	$write("settag");
				l.c.OP_RESERVE:	$write("reserve");
				l.c.OP_PUSH: 		$write("push");
				l.c.OP_GOTO: 		$write("goto");
				l.c.OP_BFALSE: 	$write("bfalse");
				l.c.OP_GETLOCAL: 	$write("getlocal");
				l.c.OP_SETLOCAL: 	$write("setlocal");
				l.c.OP_CLEANUP: 	$write("cleanup");
				l.c.OP_AND: 		$write("and");
				l.c.OP_OR: 		$write("or");
				l.c.OP_XOR: 		$write("xor");
				l.c.OP_LSHIFT: 	$write("lshift");
				l.c.OP_RSHIFT: 	$write("rshift");
				l.c.OP_GETBP:		$write("getbp");
			endcase
	
			if (l.c.opcode[4:3] == 2'b11)
				$write(" %d", l.c.param);
	
			$write(" ");
	
			case (l.c.state)
				l.c.STATE_DECODE: 			$write("DECODE");
				l.c.STATE_GOT_NOS: 			$write("GOT_NOS");
				l.c.STATE_PUSH_MEM_RESULT: 	$write("PUSH_MEM_RESULT");
				l.c.STATE_GETLOCAL2: 		$write("GETLOCAL2");
				l.c.STATE_RETURN2: 			$write("RETURN2");
				l.c.STATE_RETURN3: 			$write("RETURN3");
				l.c.STATE_GOT_STORE_VALUE:	$write("GOT_STORE_VALUE");
				l.c.STATE_GOT_NEW_TAG:		$write("GOT_NEW_TAG");
				l.c.STATE_BFALSE2:			$write("BFALSE2");
				
			endcase
		
			$write(" stack(%d) ", l.c.stack_pointer);
			$write(" %d", l.c.top_of_stack);
			for (j = 0; j < 5; j = j + 1)
				$write(" %d", l.data_mem.data[l.c.stack_pointer + j]);
		
			$write("\n");
			if (l.c.instruction_pointer_next != l.c.instruction_pointer)
				$write("\n");
			
//			if (l.mem_write_enable)
//				$display(" mem %d <= %d", l.mem_addr, l.mem_write_value);
		end
	end
	endtask


endmodule

`timescale 1us/1us

// Asynchronous ROM
module arom
	#(parameter MEM_SIZE = 4096,
	parameter WORD_SIZE = 20,
	parameter ADDR_SIZE = 16,
	parameter INIT_FILE="")

	(input [ADDR_SIZE - 1:0] addr_i,
	output [WORD_SIZE - 1:0] value_o);

	reg[WORD_SIZE - 1:0]		data[0:MEM_SIZE];

	initial
		$readmemh(INIT_FILE, data);

	assign value_o = data[addr_i];
endmodule

`timescale 1us/1us

module rom
	#(parameter MEM_SIZE = 4096,
	parameter WORD_SIZE = 20,
	parameter ADDR_SIZE = 16)

	(input 						clk,
	input[ADDR_SIZE - 1:0] 		addr_i,
	output reg[WORD_SIZE - 1:0] value_o);

	reg[WORD_SIZE - 1:0]		data[0:MEM_SIZE];
	integer 					i;

	initial
	begin
		// synthesis translate_off
		for (i = 0; i < MEM_SIZE; i = i + 1)
			data[i] = 0;
		// synthesis translate_on
		
		$readmemh("rom.hex", data);
	end

	always @(posedge clk)
		value_o <= data[addr_i];
endmodule

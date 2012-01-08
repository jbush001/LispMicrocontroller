module memory
	#(parameter MEM_SIZE = 4096,
	parameter WORD_SIZE = 20)

	(input 						clk,
	input[WORD_SIZE - 1:0] 		addr_i,
	input[WORD_SIZE - 1:0] 		value_i,
	input 						write_i,
	output reg[WORD_SIZE - 1:0] 	value_o);

	reg[15:0]					latched_addr = 0;
	reg[19:0]					data[0:MEM_SIZE];
	integer 					i;

	initial
	begin
		// synthesis translate_off
		for (i = 0; i < MEM_SIZE; i = i + 1)
			data[i] = 0;
		// synthesis translate_on
		
		$readmemh("ram.hex", data);
	end

	always @(posedge clk)
	begin
		if (write_i)
			data[addr_i] <= value_i;

		value_o <= data[addr_i];
	end
endmodule

module top(input clk,
	output reg[7:0] out = 0);

	wire[6:0]			register_index;
	wire				register_read;
	wire				register_write;
	wire[15:0]			register_write_value;
	reg[15:0]			register_read_value = 0;
	
	reg slowclk = 0;
	reg[10:0] counter = 0;
	
	lisp_core l(
		.clk(clk),
		.register_index(register_index),
		.register_read(register_read),
		.register_write(register_write),
		.register_write_value(register_write_value),
		.register_read_value(register_read_value));
	
	always @(posedge clk)
	begin
		if (register_write)
			out <= register_write_value[7:0];
	end

endmodule


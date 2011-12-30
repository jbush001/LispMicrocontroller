module top(
	input 				clk,
	output reg[7:0]		r_led = 0,
	output reg[6:0] 	digit3 = 0,
	output reg[6:0] 	digit2 = 0,
	output reg[6:0] 	digit1 = 0,
	output reg[6:0] 	digit0 = 0,
	input [3:0]			buttons);

	wire[6:0]			register_index;
	wire				register_read;
	wire				register_write;
	wire[15:0]			register_write_value;
	reg[15:0]			register_read_value = 0;
	reg[3:0]				buttons_sync0 = 0;
	reg[3:0]				buttons_sync1 = 0;
	
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
		begin
			case (register_index)
				1: r_led <= register_write_value[7:0];
				2: digit0 <= register_write_value[6:0];
				3: digit1 <= register_write_value[6:0];
				4: digit2 <= register_write_value[6:0];
				5: digit3 <= register_write_value[6:0];
			endcase
		end

		if (register_read && register_index == 6)
			register_read_value <= {12'd0, buttons_sync1 };

		buttons_sync0 <= buttons;
		buttons_sync1 <= buttons_sync0;
	end

endmodule


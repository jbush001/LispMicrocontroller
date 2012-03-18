module top(
	input 				clk50,
	output				hsync_o,
	output				vsync_o,
	output [3:0]		red_o,
	output [3:0]		green_o,
	output [3:0]		blue_o,
	input [3:0]			buttons);

	wire[11:0]			register_index;
	wire				register_read;
	wire				register_write;
	wire[15:0]			register_write_value;
	reg[15:0]			register_read_value = 0;
	reg[3:0]			buttons_sync0 = 0;
	reg[3:0]			buttons_sync1 = 0;
	reg					clk = 0;
	wire[5:0]			collision;
	
	// Divide 50 Mhz clock down to 25 Mhz
	always @(posedge clk50)
		clk <= ~clk;
	
	ulisp l(
		.clk(clk),
		.register_index(register_index),
		.register_read(register_read),
		.register_write(register_write),
		.register_write_value(register_write_value),
		.register_read_value(register_read_value));
	
	display_controller dc(
		.clk(clk),
		.hsync_o(hsync_o),
		.vsync_o(vsync_o),
		.red_o(red_o),
		.green_o(green_o),
		.blue_o(blue_o),
		.register_write_i(register_write),
		.register_index_i(register_index),
		.register_write_value_i(register_write_value),
		.in_vblank_o(in_vblank),
		.collision_o(collision));

	always @(posedge clk)
	begin
		if (register_read)
		begin
			case (register_index)
				0: register_read_value <= { 12'd0, buttons_sync1 };
				1: register_read_value <= in_vblank;
				2: register_read_value <= { 10'd0, collision };
			endcase
		end

		buttons_sync0 <= buttons;
		buttons_sync1 <= buttons_sync0;
	end

endmodule


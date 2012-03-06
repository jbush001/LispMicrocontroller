// Sprites are 16x16 pixels

module sprite_detect(
	input clk,
	input [9:0] raster_x,
	input [9:0] raster_y,
	input [9:0]	sprite_x,
	input [9:0] sprite_y,
	output sprite_active,
	output [7:0] sprite_address);

	wire[9:0] sprite_x_offset = raster_x - sprite_x;
	wire[9:0] sprite_y_offset = raster_y - sprite_y;
	assign sprite_active = sprite_x_offset[9:4] == 0 && sprite_y_offset[9:4] == 0;
	assign sprite_address = { sprite_y_offset[3:0], sprite_x_offset[3:0] };
endmodule

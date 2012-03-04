// Sprites are 16x16 pixels

module sprite_detect(
	input clk,
	input [7:0] raster_x,
	input [7:0] raster_y,
	input [7:0]	sprite_x,
	input [7:0] sprite_y,
	output sprite_active,
	output [7:0] sprite_address);

	reg sprite_h_active = 0;
	reg sprite_v_active = 0;
	reg[3:0] sprite_h_count = 0;
	reg[3:0] sprite_v_count = 0;

	assign sprite_active = sprite_h_active && sprite_v_active;
	assign sprite_address = { sprite_v_count, sprite_h_count };

	always @(posedge clk)
	begin
		if (raster_x == sprite_x)
			sprite_h_active <= 1;
		else 
		begin
			sprite_h_count <= sprite_h_count + 1;
			if (sprite_h_count == 4'hf)
				sprite_h_active <= 0;
		end

		if (raster_y == sprite_y)
			sprite_v_active <= 1;
		else 
		begin
			sprite_v_count <= sprite_v_count + 1;
			if (sprite_v_count == 4'hf)
				sprite_v_active <= 0;
		end
	end
endmodule

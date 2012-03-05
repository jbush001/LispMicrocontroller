module display_controller(
	input 			clk,
	output			hsync_o,
	output			vsync_o,
	output [3:0]	red_o,
	output [3:0]	green_o,
	output [3:0]	blue_o,
	input			register_write_i,
	input [6:0]		register_index_i,
	input [15:0]	register_write_value_i,
	output			in_vblank);

	wire[9:0] raster_x_native;
	wire[9:0] raster_y_native;
	wire[9:0] raster_x;
	wire[9:0] raster_y;
	wire in_visible_region;
	
	reg[8:0] sprite0_x = 0;
	reg[8:0] sprite0_y = 0;
	reg[3:0] sprite0_shape = 0;
	reg sprite0_enable = 0;
	wire sprite0_active;
	wire[7:0] sprite0_address;

	reg[8:0] sprite1_x = 0;
	reg[8:0] sprite1_y = 0;
	reg[3:0] sprite1_shape = 0;
	reg sprite1_enable = 0;
	wire sprite1_active;
	wire[7:0] sprite1_address;
	
	reg[11:0] sprite_addr = 0;	// Sprite shape + address
	wire[11:0] sprite_color;
	wire[3:0] sprite_color_index;

	wire sprite_is_active = (sprite0_active && sprite0_enable)
		|| (sprite1_active && sprite1_enable);
	
	reg[11:0] output_color = 0;
	assign { red_o, green_o, blue_o } = output_color;
	always @*
	begin
		if (in_visible_region)
		begin
			if (sprite_is_active && sprite_color_index != 0)
				output_color = sprite_color;
			else
				output_color = 12'b000000000100;	// Background color
		end
		else
			output_color = 12'd0;
	end
		
	vga_timing_generator vtg(
		.clk(clk), 
		.vsync_o(vsync_o), 
		.hsync_o(hsync_o), 
		.in_visible_region(in_visible_region),
		.x_coord(raster_x_native), 
		.y_coord(raster_y_native),
		.in_vblank(in_vblank));
		
	// Cut the resolution by half in each dimension
	assign raster_x = { 1'b0, raster_x_native[9:1] };
	assign raster_y = { 1'b0, raster_y_native[9:1] };

	sprite_detect sprite0(
		.clk(clk),
		.raster_x(raster_x),
		.raster_y(raster_y),
		.sprite_x(sprite0_x),
		.sprite_y(sprite0_y),
		.sprite_active(sprite0_active),
		.sprite_address(sprite0_address));

	sprite_detect sprite1(
		.clk(clk),
		.raster_x(raster_x),
		.raster_y(raster_y),
		.sprite_x(sprite1_x),
		.sprite_y(sprite1_y),
		.sprite_active(sprite1_active),
		.sprite_address(sprite1_address));
	
	arom #(4096, 4, 12, "sprites.hex") sprite_rom(
		.addr_i(sprite_addr),
		.value_o(sprite_color_index));
		
	arom #(16, 12, 4, "palette.hex") palette_rom(
		.addr_i(sprite_color_index),
		.value_o(sprite_color));

	// Sprite priority logic	
	always @*
	begin
		if (sprite0_active && sprite0_enable)
			sprite_addr = { sprite0_shape, sprite0_address };
		else /* sprite1 active or don't care */
			sprite_addr = { sprite1_shape, sprite1_address };
	end

	always @(posedge clk)
	begin
		if (register_write_i)
		begin
			case (register_index_i)
				2: sprite0_x <= register_write_value_i[9:0];
				3: sprite0_y <= register_write_value_i[9:0];
				4: sprite0_shape <= register_write_value_i[3:0];
				5: sprite0_enable <= register_write_value_i != 0;

				6: sprite1_x <= register_write_value_i[9:0];
				7: sprite1_y <= register_write_value_i[9:0];
				8: sprite1_shape <= register_write_value_i[3:0];
				9: sprite1_enable <= register_write_value_i != 0;
			endcase
		end
	end
endmodule

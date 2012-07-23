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

// Sprites are 16x16 pixels

module sprite_detect
	#(parameter BASE_INDEX = 0)
	(input 			clk,
	input [9:0] 	raster_x,
	input [9:0] 	raster_y,
	input			register_write_i,
	input [11:0]	register_index_i,
	input [15:0]	register_write_value_i,
	output 			sprite_active,
	output [11:0] 	sprite_address);

	reg[9:0] sprite_x = 0;
	reg[9:0] sprite_y = 0;
	reg[3:0] sprite_shape = 0;
	reg sprite_enable = 0;

	wire[9:0] sprite_x_offset = raster_x - sprite_x;
	wire[9:0] sprite_y_offset = raster_y - sprite_y;
	assign sprite_active = sprite_enable && sprite_x_offset[9:4] == 0 && sprite_y_offset[9:4] == 0;
	assign sprite_address = { sprite_shape, sprite_y_offset[3:0], sprite_x_offset[3:0] };

	always @(posedge clk)
	begin
		if (register_write_i)
		begin
			case (register_index_i)
				BASE_INDEX: sprite_x <= register_write_value_i[9:0];
				BASE_INDEX + 1: sprite_y <= register_write_value_i[9:0];
				BASE_INDEX + 2: sprite_shape <= register_write_value_i[3:0];
				BASE_INDEX + 3: sprite_enable <= register_write_value_i != 0;
			endcase
		end
	end
endmodule

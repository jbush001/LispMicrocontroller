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

module top(
	input 				clk50,
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
	reg[3:0]			buttons_sync0 = 0;
	reg[3:0]			buttons_sync1 = 0;
	reg					clk = 0;
	reg					reset = 1;
	reg[3:0]			reset_count = 7;
	
	// Divide 50 Mhz clock down to 25 Mhz
	always @(posedge clk50)
		clk <= ~clk;
	
	ulisp l(
		.clk(clk),
		.reset(reset),
		.register_index(register_index),
		.register_read(register_read),
		.register_write(register_write),
		.register_write_value(register_write_value),
		.register_read_value(register_read_value));
	
	always @(posedge clk)
	begin
		if (reset_count == 0)
			reset <= 0;
		else
			reset_count <= reset_count - 1;
	
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


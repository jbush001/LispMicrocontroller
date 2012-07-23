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

`timescale 1us/1us

module rom
	#(parameter MEM_SIZE = 4096,
	parameter WORD_SIZE = 20,
	parameter ADDR_SIZE = 16,
	parameter INIT_FILE="")

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
		
		$readmemh(INIT_FILE, data);
	end

	always @(posedge clk)
		value_o <= data[addr_i];
endmodule

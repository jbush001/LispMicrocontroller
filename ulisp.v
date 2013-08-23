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

module ulisp(
	input 					clk,
	input					reset,
	output [11:0]			register_index,
	output					register_read,
	output					register_write,
	output [15:0]			register_write_value,
	input [15:0]			register_read_value);

	localparam 				MEM_SIZE = 16'd4096;

	wire[15:0]				data_mem_address;
	wire[15:0]				instr_mem_address;
	wire[18:0] 				data_mem_read_value;
	wire[20:0] 				instr_mem_read_value;
	wire[18:0]				data_mem_write_value;
	wire 					data_mem_write_enable;
	reg[18:0] 				data_core_read_value = 0;

	wire is_hardware_register_access = data_mem_address[15:12] == 4'b1111;
	assign register_index = data_mem_address[11:0];
	assign register_write_value = data_mem_write_value[15:0];
	assign register_write = is_hardware_register_access && data_mem_write_enable;
	assign register_read = is_hardware_register_access && !data_mem_write_enable;
	reg	last_was_register_access = 0;

	always @*
	begin
		if (last_was_register_access)
			data_core_read_value = register_read_value;
		else
			data_core_read_value = data_mem_read_value;
	end

	lisp_core #(MEM_SIZE) c(
		.clk(clk),
		.reset(reset),
		.instr_mem_address(instr_mem_address),
		.instr_mem_read_value(instr_mem_read_value),
		.data_mem_address(data_mem_address),
		.data_mem_read_value(data_core_read_value),
		.data_mem_write_value(data_mem_write_value),
		.data_mem_write_enable(data_mem_write_enable));

	rom #(MEM_SIZE, 21, 16, "program.hex") instr_mem(
		.clk(clk),
		.addr_i(instr_mem_address),
		.value_o(instr_mem_read_value));
	
	ram #(MEM_SIZE, 19) data_mem(
		.clk(clk),
		.addr_i(data_mem_address),
		.value_i(data_mem_write_value),
		.write_i(data_mem_write_enable && !is_hardware_register_access),
		.value_o(data_mem_read_value));

	always @(posedge clk)
		last_was_register_access <= is_hardware_register_access;
endmodule

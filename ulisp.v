`timescale 1us/1us

module ulisp(
	input 					clk,
	output [6:0]			register_index,
	output					register_read,
	output					register_write,
	output [15:0]			register_write_value,
	input [15:0]			register_read_value);

	parameter 				MEM_SIZE = 16'd4096;

	wire[15:0]				data_mem_address;
	wire[15:0]				instr_mem_address;
	wire[18:0] 				data_mem_read_value;
	wire[20:0] 				instr_mem_read_value;
	wire[18:0]				data_mem_write_value;
	wire 					data_mem_write_enable;
	reg[18:0] 				data_core_read_value = 0;

	wire is_hardware_register_access = data_mem_address[15:7] == 16'b111111111;
	assign register_index = data_mem_address[6:0];
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

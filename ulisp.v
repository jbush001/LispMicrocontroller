module ulisp(
	input 					clk,
	output [6:0]			register_index,
	output					register_read,
	output					register_write,
	output [15:0]			register_write_value,
	input [15:0]			register_read_value);

	parameter 				MEM_SIZE = 8192;
	parameter 				WORD_SIZE = 20;

	wire[WORD_SIZE - 1:0]	memory_address;
	wire[WORD_SIZE - 1:0] 	mem_read_value;
	wire[WORD_SIZE - 1:0]	mem_write_value;
	wire 					mem_write_enable;
	reg[WORD_SIZE - 1:0] 	core_read_value = 0;

	wire is_hardware_register_access = memory_address[15:7] == 16'b111111111;
	assign register_index = memory_address[6:0];
	assign register_write_value = mem_write_value;
	assign register_write = is_hardware_register_access && mem_write_enable;
	assign register_read = is_hardware_register_access && !mem_write_enable;
	reg	last_was_register_access = 0;

	always @*
	begin
		if (last_was_register_access)
			core_read_value = register_read_value;
		else
			core_read_value = mem_read_value;
	end

	lisp_core #(MEM_SIZE, WORD_SIZE) c(
		.clk(clk),
		.memory_address(memory_address),
		.mem_read_value(core_read_value),
		.mem_write_value(mem_write_value),
		.mem_write_enable(mem_write_enable));
	
	memory #(MEM_SIZE, WORD_SIZE) mem(
		.clk(clk),
		.addr_i(memory_address),
		.value_i(mem_write_value),
		.write_i(mem_write_enable && !is_hardware_register_access),
		.value_o(mem_read_value));

	always @(posedge clk)
		last_was_register_access <= is_hardware_register_access;

endmodule

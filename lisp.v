module lisp(
	input 					clk,
	output [6:0]			register_index,
	output					register_read,
	output					register_write,
	output [15:0]			register_write_value,
	input [15:0]			register_read_value);
	
	
	parameter 				MEM_SIZE = 32640;	// 32k - 128 bytes for hardware regs
	parameter 				WORD_SIZE = 20;

	parameter				STATE_IADDR_ISSUE = 0;
	parameter				STATE_DECODE = 1;
	parameter				STATE_GOT_NOS = 2;
	parameter				STATE_LOAD_TOS1 = 3;
	parameter				STATE_PUSH_MEM_RESULT = 4;
	parameter				STATE_GETLOCAL2 = 5;
	parameter				STATE_RETURN2 = 6;
	parameter				STATE_CALL2 = 7;
	parameter				STATE_RETURN3 = 8;

	parameter				OP_NOP = 0;
	parameter				OP_CALL = 1;
	parameter				OP_RETURN = 2;
	parameter				OP_POP = 3;
	parameter				OP_LOAD = 4;
	parameter				OP_STORE = 5;
	parameter				OP_ADD = 6;
	parameter				OP_SUB = 7;
	parameter				OP_REST = 8;
	parameter				OP_GTR = 9;
	parameter				OP_GTE = 10;
	parameter				OP_EQ = 11;
	parameter				OP_NEQ = 12;
	parameter				OP_DUP = 13;
	parameter				OP_GETTAG = 14;
	parameter				OP_SETTAG = 15;
	parameter				OP_AND = 16;
	parameter				OP_OR = 17;
	parameter				OP_XOR = 18;
	parameter				OP_LSHIFT = 19;
	parameter				OP_RSHIFT = 20;
	parameter				OP_GETBP = 21;
	parameter				OP_RESERVE = 24;	
	parameter				OP_PUSH = 25;
	parameter				OP_GOTO = 26;
	parameter				OP_BFALSE = 27;
	parameter				OP_GETLOCAL = 29;
	parameter				OP_SETLOCAL = 30;
	parameter				OP_CLEANUP = 31;

	reg[3:0]				state = STATE_IADDR_ISSUE;
	reg[3:0]				state_next = STATE_IADDR_ISSUE;
	reg[WORD_SIZE - 1:0] 	top_of_stack = 0;
	reg[WORD_SIZE - 1:0] 	top_of_stack_next = 0;
	reg[WORD_SIZE - 1:0] 	stack_pointer = MEM_SIZE - 8;
	reg[WORD_SIZE - 1:0] 	stack_pointer_next = MEM_SIZE - 8;
	reg[WORD_SIZE - 1:0] 	base_pointer = MEM_SIZE - 4;
	reg[WORD_SIZE - 1:0] 	base_pointer_next = MEM_SIZE - 4;
	reg[WORD_SIZE + 1:0] 	instruction_pointer = -1;
	reg[WORD_SIZE + 1:0] 	instruction_pointer_next = 0;
	reg[WORD_SIZE - 1:0]	next_instruction = 0;
	reg[WORD_SIZE - 1:0] 	latched_instruction = 0;
	reg[WORD_SIZE - 1:0] 	current_instruction_word = 0;
	reg[4:0] 				opcode = 0;
	reg[WORD_SIZE - 1:0] 	param = 0;
	reg[WORD_SIZE - 1:0]	mem_addr = 0;
	wire[WORD_SIZE - 1:0] 	mem_read_value;
	reg[WORD_SIZE - 1:0]	mem_write_value = 0;
	reg						mem_write_enable = 0;
	reg[15:0]				alu_result = 0;
	reg						enable_memory_access = 0;
	reg						last_was_register_access = 0;

	wire is_hardware_register_access = mem_addr[15:7] == 16'b111111111;
	assign register_index = mem_addr[6:0];
	assign register_write_value = mem_write_value;
	assign register_write = is_hardware_register_access && mem_write_enable;
	assign register_read = is_hardware_register_access;

	memory #(MEM_SIZE, WORD_SIZE) mem(
		.clk(clk),
		.addr_i(mem_addr),
		.value_i(mem_write_value),
		.write_i(mem_write_enable && !is_hardware_register_access),
		.value_o(mem_read_value));

	//
	// Instruction alignment/Selection
	//
	always @*
	begin	
		if (state == STATE_DECODE)
			current_instruction_word = mem_read_value;
		else
			current_instruction_word = latched_instruction;

		case (instruction_pointer[1:0])
			0:	
			begin
				opcode = current_instruction_word[19:15];
				param = { {5{current_instruction_word[14]}}, current_instruction_word[14:0] };
			end

			1:
			begin
				opcode = current_instruction_word[14:10];
				param = { {11{current_instruction_word[9]}}, current_instruction_word[9:0] };
			end

			2:
			begin
				opcode = current_instruction_word[9:5];
				param = { {16{current_instruction_word[4]}}, current_instruction_word[4:0] };
			end

			3:
			begin
				opcode = current_instruction_word[4:0];
				param = 0;
			end
		endcase		
	end

	//
	// ALU
	//
	wire[15:0] alu_op0 = top_of_stack[15:0];
	wire[15:0] alu_op1 = mem_read_value[15:0];
	wire[15:0] diff = alu_op0 - alu_op1;
	wire zero = diff == 0;
	wire negative = diff[15];

	always @*
	begin
		case (opcode)
			OP_ADD: alu_result = alu_op0 + alu_op1; 
			OP_SUB: alu_result = alu_op0 - alu_op1; 
			OP_GTR: alu_result = !negative && !zero; 
			OP_GTE: alu_result = !negative; 
			OP_EQ: alu_result = zero; 
			OP_NEQ: alu_result = !zero; 
			OP_AND: alu_result = alu_op0 & alu_op1;
			OP_OR: alu_result = alu_op0 | alu_op1;
			OP_XOR: alu_result = alu_op0 ^ alu_op1;
			OP_LSHIFT: alu_result = alu_op0 << alu_op1;
			OP_RSHIFT: alu_result = alu_op0 >> alu_op1;
		endcase
	end

	always @*
	begin
		if (opcode[4:3] == 2'b11)	// Does this have a param?  If so, skip to next word
			next_instruction = { instruction_pointer[WORD_SIZE + 1:2], 2'b00 } + 4;
		else
			next_instruction = instruction_pointer + 1;
	end

	//
	// Main state machine
	//
	always @*
	begin
		mem_write_enable = 0;
		mem_write_value = 0;
		mem_addr = 0;
		enable_memory_access = 0;
		stack_pointer_next = stack_pointer;
		top_of_stack_next = top_of_stack;
		state_next = state;
		base_pointer_next = base_pointer;
		instruction_pointer_next = instruction_pointer;
	
		case (state)
			STATE_IADDR_ISSUE:
			begin
				// Fetch next instruction
				instruction_pointer_next = next_instruction;
				enable_memory_access = 1;
				mem_addr = instruction_pointer_next[WORD_SIZE + 1:2];
				state_next = STATE_DECODE;
			end			

			STATE_DECODE:
			begin
				case (opcode)
					OP_CALL:
					begin
						// the next instruction pointer logic will
						// use the top of stack as the call-to address, replacing
						// it.
						// Need to push the old base pointer on the stack
						// and stash the return value in TOS
						instruction_pointer_next =  { top_of_stack[15:0], 2'b00 };
						stack_pointer_next = stack_pointer - 1;
						enable_memory_access = 1;
						mem_addr = stack_pointer_next;
						mem_write_enable = 1;
						mem_write_value = base_pointer;
						base_pointer_next = stack_pointer_next;
						top_of_stack_next = { instruction_pointer[WORD_SIZE + 1:2], 2'b00 } + 4;
						state_next = STATE_CALL2;
					end

					OP_RETURN: 
					begin
						// A function must push its return value into TOS,
						// so we know PC is saved in memory.  First fetch that.
						mem_addr = base_pointer - 1;
						state_next = STATE_RETURN2;
					end

					OP_POP:	// pop
					begin
						mem_addr = stack_pointer;
						stack_pointer_next = stack_pointer + 1;
						state_next = STATE_PUSH_MEM_RESULT;
					end
					
					OP_GETTAG:
					begin
						top_of_stack_next = top_of_stack[19:16];

						// Fetch next instruction
						instruction_pointer_next = next_instruction;
						mem_addr = instruction_pointer_next[WORD_SIZE + 1:2];
						state_next = STATE_DECODE;
					end
					
					OP_GETBP:
					begin
						top_of_stack_next = base_pointer;

						// Fetch next instruction
						instruction_pointer_next = next_instruction;
						mem_addr = instruction_pointer_next[WORD_SIZE + 1:2];
						state_next = STATE_DECODE;
					end

					OP_LOAD:
					begin
						// This just replaces TOS.
						mem_addr = top_of_stack[15:0];
						state_next = STATE_PUSH_MEM_RESULT;
					end

					// binary operations
					OP_STORE, 
					OP_ADD,
					OP_SUB, 
					OP_GTR, 
					OP_GTE, 
					OP_EQ, 
					OP_NEQ,
					OP_SETTAG,
					OP_AND,
					OP_OR,
					OP_XOR,
					OP_LSHIFT,
					OP_RSHIFT: 
					begin
						// In the first cycle of a store, we need to fetch
						// the next value on the stack 
						mem_addr = stack_pointer;
						state_next = STATE_GOT_NOS;	
					end
					
					OP_REST:	// Just a load with an extra offset
					begin
						mem_addr = top_of_stack[15:0] + 1;
						state_next = STATE_PUSH_MEM_RESULT;
					end

					OP_DUP:	// Push TOS, but leave it untouched.
					begin
						stack_pointer_next = stack_pointer - 1;
						mem_addr = stack_pointer_next;
						mem_write_enable = 1;
						mem_write_value = top_of_stack;
						state_next = STATE_IADDR_ISSUE;
					end

					OP_RESERVE: 
					begin
						if (top_of_stack == 0)
						begin
							// Not reserving anything, jump to next instruction
							instruction_pointer_next = next_instruction;
							mem_addr = instruction_pointer_next[WORD_SIZE + 1:2];
							state_next = STATE_DECODE;
						end
						else
						begin
							// Store the current TOS to memory and update sp.
							// this has the side effect of pushing an 
							// extra zero on the stack.
							mem_addr = stack_pointer - 1;
							mem_write_enable = 1;
							mem_write_value = top_of_stack;
							stack_pointer_next = stack_pointer - (param + 1);
							top_of_stack_next = 0;
							state_next = STATE_IADDR_ISSUE;
						end
					end

					OP_PUSH:
					begin
						// Immediate Push.  Store the current 
						// TOS to memory and latch the value into the TOS reg.
						stack_pointer_next = stack_pointer - 1;
						mem_addr = stack_pointer_next;
						mem_write_enable = 1;
						mem_write_value = top_of_stack;
						top_of_stack_next = param;	// XXX set tag
						state_next = STATE_IADDR_ISSUE;
					end

					OP_GOTO:
					begin
						instruction_pointer_next = { instruction_pointer[WORD_SIZE + 1:2], 2'b00 } 
							+ { param, 2'b00 };
						mem_addr = instruction_pointer_next[WORD_SIZE + 1:2];
						state_next = STATE_DECODE;
					end

					OP_BFALSE:
					begin
						// Branch if top of stack is 0
						if (top_of_stack[15:0] == 0)
						begin
							instruction_pointer_next = { instruction_pointer[WORD_SIZE + 1:2], 2'b00 } 
							+ { param, 2'b00 };
						end
						else
						begin
							// Just go to next instruction
							instruction_pointer_next = next_instruction;
						end
						
						state_next = STATE_LOAD_TOS1;	// Restore TOS
					end
					
					OP_GETLOCAL:
					begin
						// First cycle, need to save current TOS into memory.
						stack_pointer_next = stack_pointer - 1;
						mem_addr = stack_pointer_next;
						mem_write_enable = 1;
						mem_write_value = top_of_stack;
						state_next = STATE_GETLOCAL2;
					end
					
					OP_SETLOCAL:
					begin
						// Write TOS value to appropriate local slot, then
						// fetch new TOS.
						mem_addr = base_pointer + param;
						mem_write_enable = 1;
						mem_write_value = top_of_stack;
						state_next = STATE_LOAD_TOS1;
					end
					
					OP_CLEANUP:
					begin
						// cleanup params.  The trick is that we leave TOS untouched,
						// so the return value will not be affected.
						stack_pointer_next = stack_pointer + param;

						// Fetch next instruction
						instruction_pointer_next = next_instruction;
						mem_addr = instruction_pointer_next[WORD_SIZE + 1:2];
						state_next = STATE_DECODE;
					end

					default:	// NOP or any other unknown op
					begin
						// Fetch next instruction
						instruction_pointer_next = next_instruction;
						mem_addr = instruction_pointer_next[WORD_SIZE + 1:2];
						state_next = STATE_DECODE;
					end
				endcase
			end
			
			// For any instruction with two stack operands, this is called
			// in the second cycle, when the NOS has been fetched.
			STATE_GOT_NOS:
			begin
				if (opcode == OP_SETTAG)
				begin
					top_of_stack_next = { alu_op1[3:0], top_of_stack[15:0] };
					stack_pointer_next = stack_pointer + 1;

					// Fetch next instruction
					instruction_pointer_next = next_instruction;
					mem_addr = instruction_pointer_next[WORD_SIZE + 1:2];
					state_next = STATE_DECODE;
				end
				else if (opcode == OP_STORE)
				begin
					// This is a binary op, but is a bit difference
					// because it doesn't leave anything on the stack
					mem_addr = top_of_stack[15:0];
					mem_write_enable = 1;
					mem_write_value = mem_read_value;	// next on stack
					stack_pointer_next = stack_pointer + 2;
					
					// Load top of stack
					state_next = STATE_LOAD_TOS1;
				end
				else
				begin
					// standard binary arithmetic.
					top_of_stack_next = { top_of_stack[19:16], alu_result[15:0] };
					stack_pointer_next = stack_pointer + 1;

					// Fetch next instruction
					instruction_pointer_next = next_instruction;
					mem_addr = instruction_pointer_next[WORD_SIZE + 1:2];
					state_next = STATE_DECODE;
				end
			end

			STATE_LOAD_TOS1:
			begin
				mem_addr = stack_pointer;
				state_next = STATE_PUSH_MEM_RESULT;
			end

			STATE_GETLOCAL2:
			begin
				// Issue memory read for local value
				mem_addr = base_pointer + param;
				state_next = STATE_PUSH_MEM_RESULT;
			end
			
			STATE_PUSH_MEM_RESULT:
			begin
				if (last_was_register_access)
					top_of_stack_next = register_read_value;
				else
					top_of_stack_next = mem_read_value;

				// Fetch next instruction
				// If we're finishing a branch, don't increment again
				// because we've already reloaded the new destination.
				if (opcode != OP_BFALSE)
					instruction_pointer_next = next_instruction;

				mem_addr = instruction_pointer_next[WORD_SIZE + 1:2];
				state_next = STATE_DECODE;
			end
			
			STATE_RETURN2:
			begin
				// Got the instruction pointer, now fetch old base pointer
				instruction_pointer_next = mem_read_value;
				mem_addr = base_pointer;
				stack_pointer_next = base_pointer + 1;
				state_next = STATE_RETURN3;
			end
			
			STATE_RETURN3:
			begin
				base_pointer_next = mem_read_value;

				// Fetch next instruction
				mem_addr = instruction_pointer[WORD_SIZE + 1:2];
				state_next = STATE_DECODE;
			end

			// Like fetch, except that it doesn't increment the instruction
			// pointer.
			STATE_CALL2:
			begin
				mem_addr = instruction_pointer[WORD_SIZE + 1:2];
				state_next = STATE_DECODE;
			end
			
			default:	stack_pointer_next = stack_pointer;
		endcase
	end

	always @(posedge clk)
	begin
		instruction_pointer <= instruction_pointer_next;
		state <= state_next;
		top_of_stack <= top_of_stack_next;
		stack_pointer <= stack_pointer_next;
		base_pointer <= base_pointer_next;
		last_was_register_access <= is_hardware_register_access;
		if (state == STATE_DECODE)
			latched_instruction <= mem_read_value;
	end
endmodule

module memory
	#(parameter MEM_SIZE = 4096,
	parameter WORD_SIZE = 20)

	(input 						clk,
	input[WORD_SIZE - 1:0] 		addr_i,
	input[WORD_SIZE - 1:0] 		value_i,
	input 						write_i,
	output [WORD_SIZE - 1:0] 	value_o);

	reg[15:0]					latched_addr = 0;
	reg[19:0]					data[0:MEM_SIZE];
	integer 					i;

	initial
	begin
		for (i = 0; i < MEM_SIZE; i = i + 1)
			data[i] = 0;

		$readmemh("ram.hex", data);
	end

	always @(posedge clk)
	begin
		if (write_i)
			data[addr_i] <= value_i;

		latched_addr <= addr_i;
	end
		
	assign value_o = data[latched_addr];
endmodule

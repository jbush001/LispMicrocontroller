module lisp_core(
	input 					clk,
	output [6:0]			register_index,
	output					register_read,
	output					register_write,
	output [15:0]			register_write_value,
	input [15:0]			register_read_value);
	
	
	parameter 				MEM_SIZE = 8192;	
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
	reg[WORD_SIZE - 1:0] 	stack_pointer = MEM_SIZE - 8;
	reg[WORD_SIZE - 1:0] 	base_pointer = MEM_SIZE - 4;
	reg[WORD_SIZE + 1:0] 	instruction_pointer = -1;
	reg[WORD_SIZE + 1:0] 	instruction_pointer_next = 0;
	reg[WORD_SIZE - 1:0]	next_instruction = 0;
	reg[WORD_SIZE - 1:0] 	latched_instruction = 0;
	reg[WORD_SIZE - 1:0] 	current_instruction_word = 0;
	reg[4:0] 				opcode = 0;
	reg[WORD_SIZE - 1:0] 	param = 0;
	reg[WORD_SIZE - 1:0]	memory_address = 0;
	wire[WORD_SIZE - 1:0] 	mem_read_value;
	reg[WORD_SIZE - 1:0]	mem_write_value = 0;
	reg						mem_write_enable = 0;
	reg[15:0]				alu_result = 0;
	reg						last_was_register_access = 0;

	wire is_hardware_register_access = memory_address[15:7] == 16'b111111111;
	assign register_index = memory_address[6:0];
	assign register_write_value = mem_write_value;
	assign register_write = is_hardware_register_access && mem_write_enable;
	assign register_read = is_hardware_register_access;

	memory #(MEM_SIZE, WORD_SIZE) mem(
		.clk(clk),
		.addr_i(memory_address),
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
	// Stack pointer next mux
	//
	parameter SP_CURRENT = 0;
	parameter SP_DECREMENT = 1;
	parameter SP_INCREMENT = 2;
	parameter SP_ALU = 3;

	reg[1:0] stack_pointer_select = SP_CURRENT;
	reg[WORD_SIZE - 1:0] stack_pointer_next = MEM_SIZE - 8;
	
	always @*
	begin
		case (stack_pointer_select)
			SP_CURRENT: 	stack_pointer_next = stack_pointer;
			SP_DECREMENT: 	stack_pointer_next = stack_pointer - 1;
			SP_INCREMENT: 	stack_pointer_next = stack_pointer + 1;
			SP_ALU: 		stack_pointer_next = alu_result[15:0];
		endcase
	end
	
	//
	// ALU op0 mux
	//
	parameter OP0_TOP_OF_STACK = 0;
	parameter OP0_STACK_POINTER = 1;
	parameter OP0_BASE_POINTER = 2;

	reg[1:0] alu_op0_select = OP0_TOP_OF_STACK;
	reg[15:0] alu_op0 = 0;

	always @*
	begin
		case (alu_op0_select)
			OP0_TOP_OF_STACK: 	alu_op0 = top_of_stack[15:0];
			OP0_STACK_POINTER: 	alu_op0 = stack_pointer;
			OP0_BASE_POINTER: 	alu_op0 = base_pointer;
			default:			alu_op0 = 0;
		endcase
	end
	
	//
	// ALU op1 mux
	//
	parameter OP1_MEM_READ_VALUE = 0;
	parameter OP1_PARAM = 1;
	parameter OP1_ONE = 2;

	reg[1:0] alu_op1_select = OP1_MEM_READ_VALUE;
	reg[15:0] alu_op1 = 0;
	
	always @*
	begin
		case (alu_op1_select)
			OP1_MEM_READ_VALUE: alu_op1 = mem_read_value[15:0];
			OP1_PARAM: 			alu_op1 = param;
			OP1_ONE: 			alu_op1 = 1;
			default:			alu_op1 = 0;
		endcase
	end

	//
	// ALU
	//
	reg[4:0] alu_op = 0;
	wire[15:0] diff = alu_op0 - alu_op1;
	wire zero = diff == 0;
	wire negative = diff[15];

	always @*
	begin
		case (alu_op)
			OP_ADD: alu_result = alu_op0 + alu_op1; 
			OP_SUB: alu_result = diff; 
			OP_GTR: alu_result = !negative && !zero; 
			OP_GTE: alu_result = !negative; 
			OP_EQ: alu_result = zero; 
			OP_NEQ: alu_result = !zero; 
			OP_AND: alu_result = alu_op0 & alu_op1;
			OP_OR: alu_result = alu_op0 | alu_op1;
			OP_XOR: alu_result = alu_op0 ^ alu_op1;
			OP_LSHIFT: alu_result = alu_op0 << alu_op1;
			OP_RSHIFT: alu_result = alu_op0 >> alu_op1;
			default: alu_result = 0;
		endcase
	end

	//
	// Top of stack next mux
	//
	parameter TOS_CURRENT = 0;
	parameter TOS_TAG = 1;
	parameter TOS_RETURN_ADDR = 2;
	parameter TOS_BASE_POINTER = 3;
	parameter TOS_PARAM = 4;
	parameter TOS_SETTAG = 5;
	parameter TOS_ALU_RESULT = 6;
	parameter TOS_MEMORY_RESULT = 7;
	parameter TOS_REGISTER_RESULT = 8;	// XXX move logic outside this module

	reg[3:0] tos_select = TOS_CURRENT;
	reg[WORD_SIZE - 1:0] top_of_stack_next = 0;
	
	always @*
	begin
		case (tos_select)
			TOS_CURRENT: 			top_of_stack_next = top_of_stack;
			TOS_TAG:				top_of_stack_next = top_of_stack[19:16];
			TOS_RETURN_ADDR:		top_of_stack_next = { instruction_pointer[WORD_SIZE + 1:2], 2'b00 } + 4;
			TOS_BASE_POINTER:		top_of_stack_next = base_pointer;
			TOS_PARAM:				top_of_stack_next = param;
			TOS_SETTAG:				top_of_stack_next = { mem_read_value[3:0], top_of_stack[15:0] };
			TOS_ALU_RESULT:			top_of_stack_next = { top_of_stack[19:16], alu_result[15:0] };
			TOS_MEMORY_RESULT:		top_of_stack_next = mem_read_value;
			TOS_REGISTER_RESULT: 	top_of_stack_next = register_read_value;
			default:				top_of_stack_next = 0;
		endcase
	end
	
	//
	// Memory address mux
	//
	parameter MA_INSTRUCTION_POINTER = 0;
	parameter MA_STACK_POINTER = 1;
	parameter MA_TOP_OF_STACK = 2;
	parameter MA_ALU = 3;
	parameter MA_BASE_POINTER = 4;
	parameter MA_STACK_POINTER_MINUS_ONE = 5;
	
	reg[2:0] ma_select = MA_INSTRUCTION_POINTER;
	
	always @*
	begin
		case (ma_select)
			MA_INSTRUCTION_POINTER: 	memory_address = instruction_pointer_next[WORD_SIZE + 1:2];
			MA_STACK_POINTER: 			memory_address = stack_pointer;
			MA_TOP_OF_STACK: 			memory_address = top_of_stack[15:0];
			MA_ALU:						memory_address = alu_result;
			MA_BASE_POINTER:			memory_address = base_pointer;
			MA_STACK_POINTER_MINUS_ONE:	memory_address = stack_pointer - 1;
			default:					memory_address = 0;
		endcase
	end
	
	//
	// Base pointer mux
	//
	parameter BP_CURRENT = 0;
	parameter BP_ALU = 1;
	parameter BP_MEM = 2;
	
	reg[WORD_SIZE - 1:0] base_pointer_next = MEM_SIZE - 4;
	reg[1:0] bp_select = BP_CURRENT;

	always @*
	begin
		case (bp_select)
			BP_CURRENT: 	base_pointer_next = base_pointer;
			BP_ALU:			base_pointer_next = alu_result;
			BP_MEM:			base_pointer_next = mem_read_value;
			default:		base_pointer_next = 0;
		endcase
	end
	
	//
	// Next instruction mux
	//
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
		state_next = state;
		stack_pointer_select = SP_CURRENT;
		tos_select = TOS_CURRENT;
		bp_select = BP_CURRENT;
		alu_op0_select = OP0_TOP_OF_STACK;
		alu_op1_select = OP1_MEM_READ_VALUE;
		alu_op = opcode;
		ma_select = MA_INSTRUCTION_POINTER;
		instruction_pointer_next = instruction_pointer;
	
		case (state)
			STATE_IADDR_ISSUE:
			begin
				// Fetch next instruction
				instruction_pointer_next = next_instruction;
				ma_select = MA_INSTRUCTION_POINTER;
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
						stack_pointer_select = SP_DECREMENT;
						ma_select = MA_ALU;
						alu_op0_select = OP0_STACK_POINTER;
						alu_op1_select = OP1_ONE;
						alu_op = OP_SUB;
						
						mem_write_value = base_pointer;
						mem_write_enable = 1;
						bp_select = BP_ALU;
						tos_select = TOS_RETURN_ADDR;
						state_next = STATE_CALL2;
					end

					OP_RETURN: 
					begin
						// A function must push its return value into TOS,
						// so we know PC is saved in memory.  First fetch that.
						ma_select = MA_ALU;
						alu_op0_select = OP0_BASE_POINTER;
						alu_op1_select = OP1_ONE;
						alu_op = OP_SUB;
						state_next = STATE_RETURN2;
					end

					OP_POP:	// pop
					begin
						ma_select = MA_STACK_POINTER;
						stack_pointer_select = SP_INCREMENT;
						state_next = STATE_PUSH_MEM_RESULT;
					end
					
					OP_GETTAG:
					begin
						tos_select = TOS_TAG;

						// Fetch next instruction
						instruction_pointer_next = next_instruction;
						ma_select = MA_INSTRUCTION_POINTER;
						state_next = STATE_DECODE;
					end

					OP_GETBP:
					begin
						stack_pointer_select = SP_DECREMENT;
						ma_select = MA_ALU;
						alu_op0_select = OP0_STACK_POINTER;
						alu_op1_select = OP1_ONE;
						alu_op = OP_SUB;

						mem_write_enable = 1;
						mem_write_value = top_of_stack;
						tos_select = TOS_BASE_POINTER;
						state_next = STATE_IADDR_ISSUE;
					end

					OP_LOAD:
					begin
						// This just replaces TOS.
						ma_select = MA_TOP_OF_STACK;
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
						ma_select = MA_STACK_POINTER;
						state_next = STATE_GOT_NOS;	
					end
					
					OP_REST:	// Just a load with an extra offset
					begin
						ma_select = MA_ALU;
						alu_op0_select = OP0_TOP_OF_STACK;
						alu_op1_select = OP1_ONE;
						alu_op = OP_ADD;
						state_next = STATE_PUSH_MEM_RESULT;
					end

					OP_DUP:	// Push TOS, but leave it untouched.
					begin
						stack_pointer_select = SP_DECREMENT;
						ma_select = MA_ALU;
						alu_op0_select = OP0_STACK_POINTER;
						alu_op1_select = OP1_ONE;
						alu_op = OP_SUB;

						mem_write_enable = 1;
						mem_write_value = top_of_stack;
						state_next = STATE_IADDR_ISSUE;
					end

					OP_RESERVE: 
					begin
						if (param == 0)
						begin
							// Not reserving anything, jump to next instruction
							instruction_pointer_next = next_instruction;

							ma_select = MA_INSTRUCTION_POINTER;
							state_next = STATE_DECODE;
						end
						else
						begin
							// Store the current TOS to memory and update sp.
							// this has the side effect of pushing an 
							// extra dummy value on the stack.
							ma_select = MA_STACK_POINTER_MINUS_ONE;
							mem_write_enable = 1;
							mem_write_value = top_of_stack;
							
							stack_pointer_select = SP_ALU;
							alu_op = OP_SUB;
							alu_op0_select = OP0_STACK_POINTER;
							alu_op1_select = OP1_PARAM;
							state_next = STATE_IADDR_ISSUE;
						end
					end

					OP_PUSH:
					begin
						// Immediate Push.  Store the current 
						// TOS to memory and latch the value into the TOS reg.
						stack_pointer_select = SP_DECREMENT;
						ma_select = MA_ALU;
						alu_op0_select = OP0_STACK_POINTER;
						alu_op1_select = OP1_ONE;
						alu_op = OP_SUB;

						mem_write_enable = 1;
						mem_write_value = top_of_stack;
						tos_select = TOS_PARAM;
						state_next = STATE_IADDR_ISSUE;
					end

					OP_GOTO:
					begin
						instruction_pointer_next = { instruction_pointer[WORD_SIZE + 1:2], 2'b00 } 
							+ { param, 2'b00 };
						ma_select = MA_INSTRUCTION_POINTER;
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
						
						// Read the next value from the stack
						stack_pointer_select = SP_INCREMENT;
						ma_select = MA_STACK_POINTER;
						state_next = STATE_PUSH_MEM_RESULT;
					end
					
					OP_GETLOCAL:
					begin
						// First cycle, need to save current TOS into memory.
						stack_pointer_select = SP_DECREMENT;
						ma_select = MA_ALU;
						alu_op0_select = OP0_STACK_POINTER;
						alu_op1_select = OP1_ONE;
						alu_op = OP_SUB;

						mem_write_enable = 1;
						mem_write_value = top_of_stack;
						state_next = STATE_GETLOCAL2;
					end
					
					OP_SETLOCAL:
					begin
						// Write TOS value to appropriate local slot, then
						// fetch new TOS.
						ma_select = MA_ALU;
						alu_op0_select = OP0_BASE_POINTER;
						alu_op1_select = OP1_PARAM;
						alu_op = OP_ADD;

						mem_write_enable = 1;
						mem_write_value = top_of_stack;
						state_next = STATE_LOAD_TOS1;
					end
					
					OP_CLEANUP:
					begin
						// cleanup params.  The trick is that we leave TOS untouched,
						// so the return value will not be affected.
						stack_pointer_select = SP_ALU;
						alu_op = OP_ADD;
						alu_op0_select = OP0_STACK_POINTER;
						alu_op1_select = OP1_PARAM;

						// Fetch next instruction
						instruction_pointer_next = next_instruction;
						ma_select = MA_INSTRUCTION_POINTER;
						state_next = STATE_DECODE;
					end

					default:	// NOP or any other unknown op
					begin
						// Fetch next instruction
						instruction_pointer_next = next_instruction;
						ma_select = MA_INSTRUCTION_POINTER;
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
					// This modifies in-place
					tos_select = TOS_SETTAG;
					stack_pointer_select = SP_INCREMENT;

					// Fetch next instruction
					instruction_pointer_next = next_instruction;
					ma_select = MA_INSTRUCTION_POINTER;
					state_next = STATE_DECODE;
				end
				else if (opcode == OP_STORE)
				begin
					// This is a binary op, but is a bit difference
					// because it doesn't leave anything on the stack
					ma_select = MA_TOP_OF_STACK;
					mem_write_enable = 1;
					mem_write_value = mem_read_value;	// next on stack
					stack_pointer_select = SP_INCREMENT;
					
					// Load top of stack
					state_next = STATE_LOAD_TOS1;
				end
				else
				begin
					// standard binary arithmetic.
					alu_op0_select = OP0_TOP_OF_STACK;
					alu_op1_select = OP1_MEM_READ_VALUE;
					alu_op = opcode;
					tos_select = TOS_ALU_RESULT;
					stack_pointer_select = SP_INCREMENT;

					// Fetch next instruction
					instruction_pointer_next = next_instruction;
					ma_select = MA_INSTRUCTION_POINTER;
					state_next = STATE_DECODE;
				end
			end

			STATE_LOAD_TOS1:
			begin
				ma_select = MA_STACK_POINTER;
				stack_pointer_select = SP_INCREMENT;
				state_next = STATE_PUSH_MEM_RESULT;
			end

			STATE_GETLOCAL2:
			begin
				// Issue memory read for local value
				ma_select = MA_ALU;
				alu_op0_select = OP0_BASE_POINTER;
				alu_op1_select = OP1_PARAM;
				alu_op = OP_ADD;

				state_next = STATE_PUSH_MEM_RESULT;
			end
			
			STATE_PUSH_MEM_RESULT:
			begin
				if (last_was_register_access)
					tos_select = TOS_REGISTER_RESULT;
				else
					tos_select = TOS_MEMORY_RESULT;

				// Fetch next instruction
				// If we're finishing a branch, don't increment again
				// because we've already reloaded the new destination.
				if (opcode != OP_BFALSE)
					instruction_pointer_next = next_instruction;

				ma_select = MA_INSTRUCTION_POINTER;
				state_next = STATE_DECODE;
			end
			
			STATE_RETURN2:
			begin
				// Got the instruction pointer, now fetch old base pointer
				instruction_pointer_next = mem_read_value;
				ma_select = MA_BASE_POINTER;
				
				stack_pointer_select = SP_ALU;
				alu_op = OP_ADD;
				alu_op0_select = OP0_BASE_POINTER;
				alu_op1_select = OP1_ONE;

				state_next = STATE_RETURN3;
			end
			
			STATE_RETURN3:
			begin
				bp_select = BP_MEM;

				// Fetch next instruction
				ma_select = MA_INSTRUCTION_POINTER;
				state_next = STATE_DECODE;
			end

			// Like fetch, except that it doesn't increment the instruction
			// pointer.
			STATE_CALL2:
			begin
				ma_select = MA_INSTRUCTION_POINTER;
				state_next = STATE_DECODE;
			end
			
			default:	
				;
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
	output reg[WORD_SIZE - 1:0] 	value_o);

	reg[15:0]					latched_addr = 0;
	reg[19:0]					data[0:MEM_SIZE];
	integer 					i;

	initial
	begin
		// synthesis translate_off
		for (i = 0; i < MEM_SIZE; i = i + 1)
			data[i] = 0;
		// synthesis translate_on
		
		$readmemh("ram.hex", data);
	end

	always @(posedge clk)
	begin
		if (write_i)
			data[addr_i] <= value_i;

		value_o <= data[addr_i];
	end
endmodule

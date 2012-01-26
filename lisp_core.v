`timescale 1us/1us

module lisp_core
	#(parameter 				DATA_MEM_SIZE = 8192)

	(input 						clk,
	
	output [15:0]				instr_mem_address,
	input [20:0] 				instr_mem_read_value,
	output reg[15:0]			data_mem_address = 0,
	input [18:0] 				data_mem_read_value,
	output reg[18:0]			data_mem_write_value = 0,
	output reg					data_mem_write_enable = 0);

	parameter					STATE_DECODE = 0;
	parameter					STATE_GOT_NOS = 1;
	parameter					STATE_LOAD_TOS1 = 2;
	parameter					STATE_PUSH_MEM_RESULT = 3;
	parameter					STATE_GETLOCAL2 = 4;
	parameter					STATE_RETURN2 = 5;
	parameter					STATE_RETURN3 = 6;
	parameter					STATE_GOT_STORE_VALUE = 7;
	parameter					STATE_GOT_NEW_TAG = 8;
	parameter					STATE_BFALSE2 = 9;

	parameter					OP_NOP = 5'd0;
	parameter					OP_CALL = 5'd1;
	parameter					OP_RETURN = 5'd2;
	parameter					OP_POP = 5'd3;
	parameter					OP_LOAD = 5'd4;
	parameter					OP_STORE = 5'd5;
	parameter					OP_ADD = 5'd6;
	parameter					OP_SUB = 5'd7;
	parameter					OP_REST = 5'd8;
	parameter					OP_GTR = 5'd9;
	parameter					OP_GTE = 5'd10;
	parameter					OP_EQ = 5'd11;
	parameter					OP_NEQ = 5'd12;
	parameter					OP_DUP = 5'd13;
	parameter					OP_GETTAG = 5'd14;
	parameter					OP_SETTAG = 5'd15;
	parameter					OP_AND = 5'd16;
	parameter					OP_OR = 5'd17;
	parameter					OP_XOR = 5'd18;
	parameter					OP_LSHIFT = 5'd19;
	parameter					OP_RSHIFT = 5'd20;
	parameter					OP_GETBP = 5'd21;
	parameter					OP_RESERVE = 5'd24;	
	parameter					OP_PUSH = 5'd25;
	parameter					OP_GOTO = 5'd26;
	parameter					OP_BFALSE = 5'd27;
	parameter					OP_GETLOCAL = 5'd29;
	parameter					OP_SETLOCAL = 5'd30;
	parameter					OP_CLEANUP = 5'd31;

	reg[3:0]					state = STATE_DECODE;
	reg[18:0]			 		top_of_stack = 0;
	reg[15:0] 					stack_pointer = DATA_MEM_SIZE - 16'd8;
	reg[15:0] 					base_pointer = DATA_MEM_SIZE - 16'd4;
	reg[15:0] 					instruction_pointer = 16'hffff;

	//
	// Instruction fields
	//
	wire[4:0] opcode = instr_mem_read_value[20:16];
	wire[15:0] param = instr_mem_read_value[15:0];

	//
	// Stack pointer next mux
	//
	parameter SP_CURRENT = 0;
	parameter SP_DECREMENT = 1;
	parameter SP_INCREMENT = 2;
	parameter SP_ALU = 3;

	reg[1:0] stack_pointer_select = SP_CURRENT;
	reg[15:0] stack_pointer_next = 0;
	
	always @*
	begin
		case (stack_pointer_select)
			SP_CURRENT: 	stack_pointer_next = stack_pointer;
			SP_DECREMENT: 	stack_pointer_next = stack_pointer - 16'd1;
			SP_INCREMENT: 	stack_pointer_next = stack_pointer + 16'd1;
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
			default:			alu_op0 = base_pointer;	// Make case full
		endcase
	end
	
	//
	// ALU op1 mux
	//
	parameter OP1_MEM_READ = 0;
	parameter OP1_PARAM = 1;
	parameter OP1_ONE = 2;

	reg[1:0] alu_op1_select = OP1_MEM_READ;
	reg[15:0] alu_op1 = 0;
	
	always @*
	begin
		case (alu_op1_select)
			OP1_MEM_READ: alu_op1 = data_mem_read_value[15:0];
			OP1_PARAM: 			alu_op1 = param;
			OP1_ONE: 			alu_op1 = 16'd1;
			default:			alu_op1 = 16'd1;		// Make case full
		endcase
	end

	//
	// ALU
	//
	reg[15:0] alu_result = 0;
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
			default: alu_result = diff;	// Make case full
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

	reg[2:0] tos_select = TOS_CURRENT;
	reg[18:0] top_of_stack_next = 0;
	
	always @*
	begin
		case (tos_select)
			TOS_CURRENT: 			top_of_stack_next = top_of_stack;
			TOS_TAG:				top_of_stack_next = top_of_stack[18:16];
			TOS_RETURN_ADDR:		top_of_stack_next = { 3'd0, instruction_pointer + 16'd1 };
			TOS_BASE_POINTER:		top_of_stack_next = { 3'd0, base_pointer };
			TOS_PARAM:				top_of_stack_next = { 3'd0, param };
			TOS_SETTAG:				top_of_stack_next = { data_mem_read_value[2:0], top_of_stack[15:0] };
			TOS_ALU_RESULT:			top_of_stack_next = { top_of_stack[18:16], alu_result[15:0] };
			TOS_MEMORY_RESULT:		top_of_stack_next = data_mem_read_value;
			default:				top_of_stack_next = top_of_stack;	// Make case full
		endcase
	end
	
	//
	// Memory address mux
	//
	parameter MA_STACK_POINTER = 0;
	parameter MA_TOP_OF_STACK = 1;
	parameter MA_ALU = 2;
	parameter MA_BASE_POINTER = 3;
	parameter MA_STACK_POINTER_MINUS_ONE = 4;
	
	reg[2:0] ma_select = MA_STACK_POINTER;
	
	always @*
	begin
		case (ma_select)
			MA_STACK_POINTER: 			data_mem_address = stack_pointer;
			MA_TOP_OF_STACK: 			data_mem_address = top_of_stack[15:0];
			MA_ALU:						data_mem_address = alu_result;
			MA_BASE_POINTER:			data_mem_address = base_pointer;
			MA_STACK_POINTER_MINUS_ONE:	data_mem_address = stack_pointer - 16'd1;
			default:					data_mem_address = 0;
		endcase
	end
	
	//
	// Mem write value mux
	//
	parameter MW_BASE_POINTER = 0;
	parameter MW_TOP_OF_STACK = 1;
	parameter MW_MEM_READ_RESULT = 2;
	
	reg[1:0] mw_select = MW_BASE_POINTER;
	
	always @*
	begin
		case (mw_select)
			MW_BASE_POINTER: data_mem_write_value = { 3'd0, base_pointer };
			MW_TOP_OF_STACK: data_mem_write_value = top_of_stack;
			MW_MEM_READ_RESULT: data_mem_write_value = data_mem_read_value;
			default: data_mem_write_value = data_mem_read_value; 	// Make full case
		endcase
	end
	
	//
	// Base pointer mux
	//
	parameter BP_CURRENT = 0;
	parameter BP_ALU = 1;
	parameter BP_MEM = 2;
	
	reg[15:0] base_pointer_next = 0;
	reg[1:0] bp_select = BP_CURRENT;

	always @*
	begin
		case (bp_select)
			BP_CURRENT: 	base_pointer_next = base_pointer;
			BP_ALU:			base_pointer_next = alu_result;
			BP_MEM:			base_pointer_next = data_mem_read_value[15:0];
			default:		base_pointer_next = base_pointer;	// Make full case
		endcase
	end
	
	//
	// Instruction pointer next mux
	//
	parameter IP_CURRENT = 0;
	parameter IP_NEXT = 1;
	parameter IP_BRANCH_TARGET = 2;
	parameter IP_MEM_READ_RESULT = 3;
	parameter IP_STACK_TARGET = 4;
	
	reg[15:0] instruction_pointer_next = 0;
	reg[2:0] ip_select = IP_CURRENT;
	assign instr_mem_address = instruction_pointer_next;
	
	always @*
	begin
		case (ip_select)
			IP_CURRENT: instruction_pointer_next = instruction_pointer;
			IP_NEXT: instruction_pointer_next = instruction_pointer + 16'd1;
			IP_BRANCH_TARGET: instruction_pointer_next = param;
			IP_MEM_READ_RESULT: instruction_pointer_next = data_mem_read_value[15:0];
			IP_STACK_TARGET: instruction_pointer_next =  top_of_stack[15:0];		
			default: instruction_pointer_next = instruction_pointer;	// Make full case
		endcase
	end

	//
	// Main state machine
	//
	reg[3:0] state_next = STATE_DECODE;

	always @*
	begin
		state_next = state;
		data_mem_write_enable = 0;
		ma_select = MA_STACK_POINTER;
		mw_select = MW_BASE_POINTER;
		stack_pointer_select = SP_CURRENT;
		tos_select = TOS_CURRENT;
		bp_select = BP_CURRENT;
		alu_op0_select = OP0_TOP_OF_STACK;
		alu_op1_select = OP1_MEM_READ;
		alu_op = opcode;
		ip_select = IP_CURRENT;
	
		case (state)
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
						ip_select = IP_STACK_TARGET;
						stack_pointer_select = SP_DECREMENT;
						ma_select = MA_ALU;
						alu_op0_select = OP0_STACK_POINTER;
						alu_op1_select = OP1_ONE;
						alu_op = OP_SUB;
						data_mem_write_enable = 1;
						mw_select = MW_BASE_POINTER;
						bp_select = BP_ALU;
						tos_select = TOS_RETURN_ADDR;
						state_next = STATE_DECODE;
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
						ip_select = IP_NEXT;
						state_next = STATE_DECODE;
					end

					OP_GETBP:
					begin
						stack_pointer_select = SP_DECREMENT;
						ma_select = MA_ALU;
						alu_op0_select = OP0_STACK_POINTER;
						alu_op1_select = OP1_ONE;
						alu_op = OP_SUB;
						data_mem_write_enable = 1;
						mw_select = MW_TOP_OF_STACK;
						tos_select = TOS_BASE_POINTER;
						ip_select = IP_NEXT;
						state_next = STATE_DECODE;
					end

					OP_LOAD:
					begin
						// This just replaces TOS.
						ma_select = MA_TOP_OF_STACK;
						state_next = STATE_PUSH_MEM_RESULT;
					end

					OP_STORE:
					begin
						// Top of stack is the store address, need to fetch
						// the store value from next-on-stack
						ma_select = MA_STACK_POINTER;
						state_next = STATE_GOT_STORE_VALUE;	
					end

					OP_SETTAG:
					begin
						// Need to fetch next-on-stack to get the new tag
						ma_select = MA_STACK_POINTER;
						state_next = STATE_GOT_NEW_TAG;
					end

					// binary operations
					OP_ADD,
					OP_SUB, 
					OP_GTR, 
					OP_GTE, 
					OP_EQ, 
					OP_NEQ,
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
						data_mem_write_enable = 1;
						mw_select = MW_TOP_OF_STACK;
						ip_select = IP_NEXT;
						state_next = STATE_DECODE;
					end

					OP_RESERVE: 
					begin
						if (param != 0)
						begin
							// Store the current TOS to memory and update sp.
							// this has the side effect of pushing an 
							// extra dummy value on the stack.
							ma_select = MA_STACK_POINTER_MINUS_ONE;
							data_mem_write_enable = 1;
							mw_select = MW_TOP_OF_STACK;
							stack_pointer_select = SP_ALU;
							alu_op = OP_SUB;
							alu_op0_select = OP0_STACK_POINTER;
							alu_op1_select = OP1_PARAM;
						end

						ip_select = IP_NEXT;
						state_next = STATE_DECODE;
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
						data_mem_write_enable = 1;
						mw_select = MW_TOP_OF_STACK;
						tos_select = TOS_PARAM;
						ip_select = IP_NEXT;
						state_next = STATE_DECODE;
					end

					OP_GOTO:
					begin
						ip_select = IP_BRANCH_TARGET;
						state_next = STATE_DECODE;
					end

					OP_BFALSE:
					begin
						// Branch if top of stack is 0
						if (top_of_stack[15:0] == 0)
							ip_select = IP_BRANCH_TARGET;
						else
							ip_select = IP_NEXT;
						
						// We popped TOS, so reload it from memory
						stack_pointer_select = SP_INCREMENT;
						ma_select = MA_STACK_POINTER;
						state_next = STATE_BFALSE2;
					end
					
					OP_GETLOCAL:
					begin
						// First cycle, need to save current TOS into memory.
						stack_pointer_select = SP_DECREMENT;
						ma_select = MA_ALU;
						alu_op0_select = OP0_STACK_POINTER;
						alu_op1_select = OP1_ONE;
						alu_op = OP_SUB;
						data_mem_write_enable = 1;
						mw_select = MW_TOP_OF_STACK;
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
						data_mem_write_enable = 1;
						mw_select = MW_TOP_OF_STACK;
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
						ip_select = IP_NEXT;
						state_next = STATE_DECODE;
					end

					default:	// NOP or any other unknown op
					begin
						// Fetch next instruction
						ip_select = IP_NEXT;
						state_next = STATE_DECODE;
					end
				endcase
			end
			
			STATE_GOT_NEW_TAG:
			begin
				tos_select = TOS_SETTAG;	// Unary, just replace top
				stack_pointer_select = SP_INCREMENT;

				// Fetch next instruction
				ip_select = IP_NEXT;
				state_next = STATE_DECODE;
			end
			
			STATE_GOT_STORE_VALUE:
			begin
				// Do the store in this cycle and leave the value on the TOS.
				data_mem_write_enable = 1;
				ma_select = MA_TOP_OF_STACK;
				mw_select = MW_MEM_READ_RESULT;
				tos_select = TOS_MEMORY_RESULT;	
				stack_pointer_select = SP_INCREMENT;
				ip_select = IP_NEXT;
				state_next = STATE_DECODE;
			end
			
			// For any instruction with two stack operands, this is called
			// in the second cycle, when the NOS has been fetched.
			STATE_GOT_NOS:
			begin
				// standard binary arithmetic.
				alu_op0_select = OP0_TOP_OF_STACK;
				alu_op1_select = OP1_MEM_READ;
				alu_op = opcode;
				tos_select = TOS_ALU_RESULT;
				stack_pointer_select = SP_INCREMENT;

				// Fetch next instruction
				ip_select = IP_NEXT;
				state_next = STATE_DECODE;
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
			
			STATE_BFALSE2:
			begin 
				// Latch top of stack and fetch next instruction
				// Note that we don't update IP here: it is already loaded
				// with the branch target
				tos_select = TOS_MEMORY_RESULT;
				state_next = STATE_DECODE;
			end
			
			STATE_PUSH_MEM_RESULT:
			begin
				// Store whatever was returned from memory to the top of stack.
				tos_select = TOS_MEMORY_RESULT;
				ip_select = IP_NEXT;
				state_next = STATE_DECODE;
			end
			
			STATE_RETURN2:
			begin
				// Got the instruction pointer, now fetch old base pointer
				ip_select = IP_MEM_READ_RESULT;
				ma_select = MA_BASE_POINTER;
				stack_pointer_select = SP_ALU;
				alu_op = OP_ADD;
				alu_op0_select = OP0_BASE_POINTER;
				alu_op1_select = OP1_ONE;
				state_next = STATE_RETURN3;
			end

			STATE_RETURN3:
			begin
				// Note: proper next PC has already been fetched, so don't 
				// increment here.
				bp_select = BP_MEM;
				state_next = STATE_DECODE;
			end
		endcase
	end

	always @(posedge clk)
	begin
		instruction_pointer <= instruction_pointer_next;
		state <= state_next;
		top_of_stack <= top_of_stack_next;
		stack_pointer <= stack_pointer_next;
		base_pointer <= base_pointer_next;
	end
endmodule


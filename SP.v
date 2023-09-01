`timescale 1 ns/10 ps
module SP(
	// INPUT SIGNAL
	clk,
	rst_n,
	in_valid,
	inst,
	mem_dout,
	// OUTPUT SIGNAL
	out_valid,
	inst_addr,
	mem_wen,
	mem_addr,
	mem_din
);
	
//------------------------------------------------------------------------
//   INPUT AND OUTPUT DECLARATION
//------------------------------------------------------------------------
//------------------------------------------------------------------------

input 					 clk, rst_n, in_valid;
input 			  [31:0] inst;
input  signed 	  [31:0] mem_dout;
output  			 	 out_valid;
output reg 		  [31:0] inst_addr;
output  		  		 mem_wen;
output  		  [11:0] mem_addr;
output signed 	  [31:0] mem_din;

//------------------------------------------------------------------------
//   DECLARATION
//------------------------------------------------------------------------

// REGISTER FILE, DO NOT EDIT THE NAME.
reg signed [31:0] r [0:31];

// format declaration
reg [5:0]  opcode;
reg [4:0]  rs;
reg [4:0]  rt;
reg [4:0]  rd;
reg [4:0]  shamt;
reg [5:0]  funct;
reg [15:0] imm; 

parameter INST_IN 	= 0;
parameter READ_r 	= 1;
parameter COMPUTE 	= 2;
parameter DATA_OUT 	= 3;
parameter DONE 		= 4;

reg [2:0] state, next_state;

//------------------------------------------------------------------------
// DESIGN
//------------------------------------------------------------------------

// FSM
always@(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		state <= INST_IN;
	end
	else begin
		state <= next_state; 
	end
end

// next state logic
always@(*) begin
	case(state) 
		INST_IN  : next_state = (in_valid == 1'b1) ? READ_r : INST_IN;
		READ_r 	 : next_state = COMPUTE;
		COMPUTE  : next_state = DATA_OUT;
		DATA_OUT : next_state = DONE;
		DONE 	 : next_state = INST_IN;
		default  : next_state = INST_IN;
	endcase
end

integer i;

reg signed [31:0] R_rd;
reg signed [31:0] R_rt;
reg signed [31:0] R_rs;

always@(posedge clk or negedge rst_n) begin
	if(!rst_n) begin
		inst_addr <= 32'd0;
		for(i=0; i<32; i=i+1) begin
			r[i] <= 32'd0;
		end
	end
	else begin
		case(state) 
			//IDLE :
			INST_IN : begin
				opcode 	<= inst[31:26];
				rs 		<= inst[25:21];
				rt 		<= inst[20:16];
				rd	 	<= inst[15:11];
				shamt 	<= inst[10:6];
				funct 	<= inst[5:0];
				imm 	<= inst[15:0];
			end
			READ_r : begin
				R_rd <= r[rd];
				R_rt <= r[rt];
				R_rs <= r[rs];
			end
			COMPUTE : begin
			
			end
			DATA_OUT : begin
				case(opcode) 
					// R-type
					6'd0 : r[rd] <= result;
					// I-type
					6'd1 : r[rt] <= result; // andi
					6'd2 : r[rt] <= result; // ori
					6'd3 : r[rt] <= result; // addi
					6'd4 : r[rt] <= result; // subi
					6'd5 : r[rt] <= mem_dout; // lw 
					//6'd6 : mem_din <= R_rt; // sw
					6'd7 : inst_addr <= (R_rs == R_rt) ? result : inst_addr;
					6'd8 : inst_addr <= (R_rs != R_rt) ? result : inst_addr;
					6'd9 : r[rt] <= result; // lui
				endcase
				inst_addr = inst_addr + 32'd4; // not well coding stytle
			end
			DONE : begin
			
			end
			default : begin
				
			end
		endcase
	end
end

assign mem_din = (mem_wen == 1'b0) ? R_rt : 32'd0;
assign out_valid = (state == DONE) ? 1'b1 : 1'b0;
assign mem_wen  = (opcode == 6'd6 && (state == COMPUTE || state == DATA_OUT)) ? 1'b0 : 1'b1; // 1'b1 for read, 1'b1 for write 
assign mem_addr = result;

wire 		[15:0] ZE_imm;
wire signed [15:0] SE_imm;
reg signed [31:0] result;

assign ZE_imm = imm;
assign SE_imm = imm;

always@(*) begin
	case(opcode) 
		// R-type
		6'd0 : begin
			case(funct)
				6'd0 : result = R_rs & R_rt; 					// and
				6'd1 : result = R_rs | R_rt; 					// or
				6'd2 : result = R_rs + R_rt; 					// add
				6'd3 : result = R_rs - R_rt; 					// sub
				6'd4 : result = (R_rs < R_rt) ? 32'd1 : 32'd0; 	// slt
				6'd5 : result = R_rs << shamt; 					// sll
				6'd6 : result = ~(R_rs | R_rt); 				// nor
				default: result = 32'd87; // for checking
			endcase
		end
		// I-type
		6'd1 : result = R_rs & ZE_imm; // andi
		6'd2 : result = R_rs | ZE_imm; // ori
		6'd3 : result = R_rs + SE_imm; // addi
		6'd4 : result = R_rs - SE_imm; // subi
		6'd5 : result = R_rs + SE_imm; // lw : mem addr
		6'd6 : result = R_rs + SE_imm; // sw : mem addr
		6'd7 : result = (SE_imm[15] == 1'b0) ? (inst_addr + 32'd4 + {14'b00_0000_0000_0000, SE_imm, 2'b00}) : 
											   (inst_addr + 32'd4 + {14'b11_1111_1111_1111, SE_imm, 2'b00}); // beq
		6'd8 : result = (SE_imm[15] == 1'b0) ? (inst_addr + 32'd4 + {14'b00_0000_0000_0000, SE_imm, 2'b00}) : 
											   (inst_addr + 32'd4 + {14'b11_1111_1111_1111, SE_imm, 2'b00}); // bne
		6'd9 : result = {imm, 16'h0000}; // lui
		default : result = 32'd88; // for checking
	endcase
end

endmodule

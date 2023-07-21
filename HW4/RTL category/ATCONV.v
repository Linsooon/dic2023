`timescale 1ns/10ps
module  ATCONV(
	input		clk,
	input		reset,
	output	reg	busy,	
	input		ready,	
			
	output reg	[11:0]	iaddr,
	input signed [12:0]	idata,
	
	output	reg 	cwr,
	output  reg	[11:0]	caddr_wr,
	output reg 	[12:0] 	cdata_wr,
	
	output	reg 	crd,		 // identify to read (?should complement to cwr?)
	output reg	[11:0] 	caddr_rd, // read addr of MEM
	input 	[12:0] 	cdata_rd,	// read data from MEM
	
	output reg 	csel // choose the which layer MEM to operate
	);

//=================================================
//            write your design below
//=================================================
// Quick notes =====
// the data to be written should be set at postive edge
// atrous convolusion/L0 only do 9 pixels at  
// ??possible to read from Layer 0 MEM and write to Layer 1 MEM at the same time ??
// clk issue 
// 目前先嘗試一次 load 9 pixel 進來，再處理(不用額外空間去暫存圖片在 conv 這邊)
// 存 boundry?

// Question lefted =====
// How to detect edge ?
// MEM index 
// 0,1..., 63
// 64
// 128
// ...
// 4032, 4031, ..., 4095
// mod64 == 0 left_edge, == 63 right edge,
// divide64 = 0 : top edge , == 63 butto, edge

	// state 
	//  === Layer 0 ====
	localparam IDLE = 4'd0;
	localparam BUSY_UP = 4'd1;
	//localparam IADDR_LOAD = 4'd2;
	localparam DATA_IN = 4'd2;
	
	//localparam DECODE  = 4'd3;
	localparam CONV = 4'd3;
	//localparam SUM = 4'd5;
	//localparam BIAS = 4'd6;
	localparam RELU = 4'd4;
	localparam W_L0 = 4'd5;
	
	//  === Layer 1 ====
	localparam RADDR_L0_GEN = 4'd6;
	localparam MAXPOOL = 4'd7;
	localparam W_L1 = 4'd8;

	reg [3:0] state, nextstate;
	
	// ===== Layer 0 =====
	reg [11:0] src_addr, next_iaddr; // 
	reg [2:0] conv_idx;
	// reg [7:0] conv_src [8:0];
	reg [12:0] conv_src; //  conv_sum = conv_sum - src
	reg [12:0] conv_sum;
	reg new_src_addr; // flag
	
	// ===== Layer 1 =====
	reg [2:0] max_idx;
	reg [12:0] max_res;
	reg [11:0] caddr_rd_coor;
	

wire TOP_edge, BUTTOM_edge, LEFT_edge, RIGHT_edge;

// ==== EDGE DETECTION ====
// the kernel 3*3 dilates 2 => 5*5 so 2 rows/cols 2 with use the padded elements
assign TOP_edge = ((src_addr >> 6) == 12'd0) || ((src_addr >> 6) == 12'd1); // pre_iaddr/64 
assign BUTTOM_edge = ((src_addr >> 6) == 12'd63) || ((src_addr >> 6) == 12'd62);
assign LEFT_edge = ((src_addr & 12'b111111) == 12'd0)  || ((src_addr & 12'b111111) == 12'd1); // pre_iaddr % 64
assign RIGHT_edge = ((src_addr & 12'b111111) == 12'd63) || ((src_addr & 12'b111111) == 12'd62);

always @(posedge clk) begin
    if(reset) state <= IDLE;
    else state <= nextstate;
end

// ===== NEXT STATE LOGIC =====
always @(*)begin
	case(state)
		IDLE:begin
			if(ready)begin
				nextstate = BUSY_UP;
			end
			else begin
				nextstate = IDLE;
			end
		end
		
		BUSY_UP:begin
			nextstate = DATA_IN;
		end
		
		// ===== ======= =====
		// ===== Layer 0 =====
		// ===== ======= =====
		
		DATA_IN:begin
			if(new_src_addr)nextstate = DATA_IN; //IADDR_LOAD; //NEXT_IADDR_GEN;
			else nextstate = CONV;
		end
			
		CONV:begin
			if(conv_idx == 3'd7) nextstate = RELU; //BIAS;
			else nextstate = DATA_IN; //IADDR_LOAD; //NEXT_IADDR_GEN;
		end
		RELU:begin
			nextstate = W_L0;
		end
		
		W_L0:begin
			if(caddr_wr == 12'd4095) nextstate = RADDR_L0_GEN; //IDLE; // 4095
			else nextstate = DATA_IN; //NEXT_IADDR_GEN;
		end
		
		
		// ===== ======= =====
		// ===== Layer 1 =====
		// ===== ======= =====
		RADDR_L0_GEN:begin
			nextstate = MAXPOOL;
		end
		MAXPOOL:begin
			if(max_idx == 3'd3) nextstate = W_L1; 
			else nextstate = MAXPOOL;
		end
		W_L1:begin
			if(caddr_wr == 12'd1023) nextstate = IDLE; //1023
			else nextstate = RADDR_L0_GEN;
		end
		
	endcase	
end

// ===== NEXT_IADDR_GEN Logic =====
always@(*)begin
	if(conv_idx == 3'd0 && new_src_addr)begin
		iaddr = src_addr;
	end
	//  conv_idx			  Mapping 				  NOT-USED-SHIT
	// |0|-|1|-|2|    |x-128|-|x-126|-|x-124|     |x-138|-|x-136|-|x-134|
	// |-|-|-|-|-|    |-----|-|-----|-|-----|     |-    |-|-    |-|-    | 
	// |3|-|s|-|4| => |x - 2|-|  x  |-|x + 2| XX  |x-2  |-| x   |-|x+2  |
	// |-|-|-|-|-|    |-----|-|-----|-|-----|     |-    |-|-    |-|-    |
	// |5|-|6|-|7|    |x+126|-|x+128|-|x+130|     |x+134|-|x+136|-|x+138|
	else begin
		case({TOP_edge, BUTTOM_edge, LEFT_edge, RIGHT_edge}) // if the clock cycle is too long, separte them to small states	
			// ==== Top Left ====
			4'b1010:begin 
				// src_addr  
				// 0, 1
				// 64, 65
				case(conv_idx)
					3'b000: iaddr = 12'd0;
					3'b001: iaddr = src_addr & 12'h03f; // 12'b0000_0011_1111 
						// 0  1	 
						// ^  ^ 
						// 64 65
					3'b010: iaddr = (src_addr + 12'd2) & 12'h03f; 
					3'd3: iaddr = src_addr & 12'hfc0; // 12'b1111_1100_0000
						// 0 < 1
						// 64 < 65
					3'd4: iaddr = src_addr + 12'd2;
					3'd5: iaddr = ((src_addr + 12'd128) & 12'hfc0); // 12'b1111_1100_0000
						// iaddr 
						// 128, <- 129
						// 192, <- 193
					3'd6: iaddr = src_addr + 12'd128;
					default: begin // 3d'7
						iaddr = src_addr + 12'd130;
					end
				endcase
			end
			
			// ==== Top ====
			4'b1000:begin 
				// src_addr 
				// 2, 3, 4 ..., 61 (# 60)
				// 66, 67, ..., 125
				case(conv_idx)
					// only top three elements of conv_src needs adjusted
					3'd0: iaddr = (src_addr - 12'd2) & 12'b111111;
					3'd1: iaddr = src_addr & 12'b111111;
					3'd2: iaddr = (src_addr + 12'd2) & 12'b111111;
					
					3'd3: iaddr = src_addr - 12'd2;
					3'd4: iaddr = src_addr + 12'd2;
					3'd5: iaddr = src_addr + 12'd126;
					3'd6: iaddr = src_addr + 12'd128;
					default: // 3d'7
						iaddr = src_addr + 12'd130;
				endcase
			end
			
			// ==== Top right ====
			4'b1001:begin 
				// src_addr 
				// 62, 63
				// 126, 127
				case(conv_idx)
					3'd0: iaddr = (src_addr - 12'd2) & 12'b111111;
					3'd1: iaddr = src_addr & 12'b111111;
					3'd2: iaddr = 12'd63;
					
					3'd3: iaddr = src_addr - 12'd2;
					3'd4: iaddr = src_addr | 12'd63; 
					// iaddr
					// 62  > 63
					// 126 > 127
					3'd5: iaddr = src_addr + 12'd126;
					3'd6: iaddr = src_addr + 12'd128;
					default: // 3d'7
						iaddr = (src_addr + 12'd128) | 12'd63;
				endcase
			end
			
			// ==== Left ====
			4'b0010:begin
				// 0, 3, 5
				case(conv_idx)
					3'd0: iaddr = (src_addr - 12'd128) & 12'hfc0;
					3'd1: iaddr = src_addr - 12'd128;
					3'd2: iaddr = src_addr - 12'd126;
					
					3'd3: iaddr = src_addr & 12'hfc0;
					3'd4: iaddr = src_addr + 12'd2;
					
					3'd5: iaddr = (src_addr + 12'd128) & 12'hfc0;
					3'd6: iaddr = src_addr + 12'd128;
					default: // 3d'7
						iaddr = src_addr + 12'd130;
				endcase
			end
			
			
			// ==== Right ====
			4'b0001:begin
				// 2, 4, 7
				case(conv_idx)
					3'd0: iaddr = src_addr - 12'd130;
					3'd1: iaddr = src_addr - 12'd128;
					3'd2: iaddr = (src_addr - 12'd128) | 12'd63;
					
					3'd3: iaddr = src_addr - 12'd2;
					3'd4: iaddr = src_addr | 12'd63;
					
					3'd5: iaddr = src_addr + 12'd126;
					3'd6: iaddr = src_addr + 12'd128;
					default: // 3d'7
						iaddr = (src_addr + 12'd128)| 12'd63;
				endcase
			end
			
			// ==== Buttom left ====
			4'b0110:begin 
				// src_addr 
				// 3968, 3989
				// 4032, 4033
				case(conv_idx)
					3'd0: iaddr = ((src_addr - 12'd128) & 12'hfc0); // 12'b1111_1100_0000
					3'd1: iaddr = src_addr - 12'd128;
					3'd2: iaddr = src_addr - 12'd126;
					3'd3: iaddr = (src_addr & 12'hfc0); // 12'b1111_1100_0000
					
					3'd4: iaddr = src_addr + 12'd2;
					
					3'd5: iaddr = 12'd4032;
					3'd6: iaddr = src_addr | 12'd64;
					default: // 3d'7
						iaddr = (src_addr + 12'd2) | 12'd64;
						// 3970, 3971
						//  ˇ     ˇ 
						// 4034, 4035
				endcase
			end
			
			// ==== Buttom ====
			4'b0100:begin 
				// src_addr 
				// 3970, 3971, ... 4029
				// 4034, 4035, ... 4093
				case(conv_idx)
					3'd0: iaddr = src_addr - 12'd130;
					3'd1: iaddr = src_addr - 12'd128;
					3'd2: iaddr = src_addr - 12'd126;
					3'd3: iaddr = src_addr - 12'd2;
					3'd4: iaddr = src_addr + 12'd2;
					// only buttom three elements of conv_src needs adjusted
					3'd5: iaddr = (src_addr - 12'd2) | 12'd64;
					// ..., 4028, 4029
					// ...,  ˇ      ˇ 
					// ..., 4092, 4093
					3'd6: iaddr = src_addr | 12'd64;
					default: // 3d'7
						iaddr = (src_addr + 12'd2) | 12'd64;					
				endcase
			end
			
			// ==== Buttom right ====
			4'b0101:begin 
				// src_addr 
				// 4030, 4031
				// 4094, 4095
				case(conv_idx)
					3'd0: iaddr = src_addr - 12'd130;
					3'd1: iaddr = src_addr - 12'd128;
					3'd2: iaddr = (src_addr - 12'd128) | 12'd63;
					// 3902 > 3903
					// 3966 > 3967
					
					3'd3: iaddr = src_addr - 12'd2;
					3'd4: iaddr = src_addr | 12'd63; 
					// 4030 > 4031
					
					3'd5: iaddr = (src_addr - 12'd2) | 12'd64;
					// ..., 4028, 4029
					// ...,  ˇ      ˇ 
					// ..., 4092, 4093
					3'd6: iaddr = src_addr | 12'd64;
					default: // 3d'7
						iaddr = 12'd4095;
				endcase
			end
			
			default:begin // normal case src_addr in middle
				case(conv_idx)
					3'd0: iaddr = src_addr - 12'd130;
					3'd1: iaddr = src_addr - 12'd128;
					3'd2: iaddr = src_addr - 12'd126;
					
					3'd3: iaddr = src_addr - 12'd2;
					3'd4: iaddr = src_addr + 12'd2;
					
					3'd5: iaddr = src_addr + 12'd126;
					3'd6: iaddr = src_addr + 12'd128;
					default: // 3d'7
						iaddr = src_addr + 12'd130;
				endcase
			end
		endcase 
	end
end

// ===== Main Logic =====
always @(posedge clk or posedge reset) begin
    if(reset)begin
		src_addr <= 12'd0;
		//iaddr <= 12'd0;
		
		new_src_addr <= 1;
		conv_src <= 13'd0;
		conv_idx <= 3'd0;
		conv_sum <= 13'd0;
		
		busy <= 0;
		cwr <= 0;
		caddr_wr <= 12'd0;
		cdata_wr <= 12'd0;
		crd <= 0;
		
		caddr_rd <= 12'd0;
		csel <= 0; 
		caddr_rd_coor <= 12'd0;
		
		max_idx <= 3'd0;
		max_res <= 13'd0;
	
	end
	
	else begin
		case(state)
			IDLE:begin
				busy <= 0;
			end
			
			// ===== ======= =====
			// ===== Layer 0 =====
			// ===== ======= =====
			BUSY_UP:begin // generates the src_addr
				busy <= 1;
			end
			
			DATA_IN:begin
				// s|interger|frac
				// 12|11...4|3..0
				if((conv_idx == 3'd0) && new_src_addr)begin
					conv_sum <= idata; // 1, 4(fractions)
					new_src_addr <= 0;
				end
				else begin 
					conv_src <= idata;
				end
				
			end
			
			CONV: begin
				//if((conv_idx == 3'd0) || (conv_idx == 3'd2) || (conv_idx == 3'd5) || (conv_idx == 3'd7)) begin
				if((conv_idx == 3'd0) || (conv_idx == 3'd2) || (conv_idx == 3'd5)) begin
					// -0.0625
					conv_sum <= conv_sum - (conv_src >> 4);
				end
				else if ((conv_idx == 3'd1) || (conv_idx == 3'd6)) begin
					// -0.125
					conv_sum <= conv_sum - (conv_src >> 3);
				end
				else begin
					// -0.25
					conv_sum <= conv_sum - (conv_src >> 2);
				end

				conv_idx <= conv_idx + 3'd1;
				
				if(conv_idx == 3'd7) begin
					src_addr <= src_addr + 12'd1;
					new_src_addr <= 1;
					caddr_wr <= src_addr;
					// do bias
					conv_sum <= conv_sum - (conv_src >> 4) - 13'b1100;
					//cdata_wr <= (conv_sum - (conv_src >> 4) > 13'b1100) ? conv_sum - (conv_src >> 4) - 13'b1100: 13'd0;
					//cwr <= 1;
				end
				else src_addr <= src_addr; 
			end
			
			RELU:begin
				cdata_wr <= conv_sum[12] ? 13'd0 : conv_sum;
				cwr <= 1;
			end
			
			W_L0:begin
				cwr <= 0;
				conv_sum <= 13'd0;
			end
		
		
			// ===== ======= =====
			// ===== Layer 1 =====
			// ===== ======= =====
			RADDR_L0_GEN:begin
				cwr <= 0;
				crd <= 1;
				csel <= 0;
				if((caddr_rd_coor & 12'b1111111) == 12'd62) begin // 127
					caddr_rd_coor <= caddr_rd_coor + 66;
				end
				else caddr_rd_coor <= caddr_rd_coor + 2;
				caddr_rd <= caddr_rd_coor; 
			end
			
			MAXPOOL:begin
				csel <= 0;
				crd <= 1;
				cwr <= 0;
				max_idx <= max_idx + 1;
				caddr_rd <= caddr_rd[0] ? caddr_rd + 63 : caddr_rd + 1; 
				max_res <= (max_res > cdata_rd) ? max_res : cdata_rd; 
			end
			
			W_L1:begin
				max_idx <= 3'd0;
				csel <= 1;
				cwr <= 1;
				crd <= 0;
				cdata_wr <= ((max_res & 13'b0000000001111) == 13'd0)? max_res : (max_res & 13'b1111111110000) + 13'b0000000010000;
				// rounding up
				caddr_wr <= caddr_wr + 1; 
				max_res <= 13'd0;
			end
			
		endcase
	end
end

endmodule
module demosaic(clk, reset, in_en, data_in, wr_r, addr_r, wdata_r, rdata_r, wr_g, addr_g, wdata_g, rdata_g, wr_b, addr_b, wdata_b, rdata_b, done);
input clk;
input reset;
input in_en;
input [7:0] data_in;
output reg wr_r;
output reg [13:0] addr_r;
output reg [7:0] wdata_r;
input [7:0] rdata_r;
output reg wr_g;
output reg [13:0] addr_g;
output reg [7:0] wdata_g;
input [7:0] rdata_g;
output reg wr_b;
output reg [13:0] addr_b;
output reg [7:0] wdata_b;
input [7:0] rdata_b;
output reg done;

// ======= 
// basiclally is to compute the miss color channel
// methods: 
// nearst "padded with the nearest value
// bilinear interploation : recommended by TA
// only 4 cases considering with the Bayen filiter result within 9-grids
// |0|1|2|
// |3|4|5|
// |6|7|8|

// G in the center (2 cases)
// |G|R|G|  |G|B|G|   the other channel value of the center
// |B|G|B|  |R|G|R|   R = (R_top + R_buttom)/2, B = (B_right + B_left)/2
// |G|R|G|  |G|B|G|   B = (B_top + B_buttom)/2, R = (R_right + R_left)/2

// R in the center
// |B|G|B|  G = (G_top + G_buttom + G_left + G_right)/4 
// |G|R|G| 	B = (B_topL + B_buttomL + G_topR + G_topR)/4
// |B|G|B|

// B in the center
// |R|G|R|  G = (G_top + G_buttom + G_left + G_right)/4 
// |G|B|G| 	R = (R_topL + R_buttomL + R_topR + R_topR)/4
// |R|G|R|

// ====== PESUDOCODE ======
// DATA_IN : read data from Input Patter Mem and write back to according color Mem
// should use a iterator to count current read in pixel

// G_CENTER :
// compute G in center from 
// 129, 131, 133, ...., 253 (#63) +5
//   258, 260 ...,      382 (#63) +3
// 385					
// ...,					16254 row:126

// R_CENTER :
// 257, 259, ..., 381  (addr = addr + 128 + 4)
// 513, 515, ..., 637
// ..., 		  16253


// B_CENTER : 
// 130, 132, ..., 254
// 386, 388, ..., 510
// ...,			, 16126 row:125

	reg [13:0] addr;
	reg [3:0] state, nextstate;
	reg [7:0] delayed_data_in;
	
	// ===== G center =====
	reg G_CEN_idx; //G_EVEN_ROW, next_G_EVEN_ROW;
	reg [13:0] G_addr, next_G_addr;
	reg [8:0] G_R_sum, G_B_sum;
	wire G_EVEN_ROW;
	
	// ===== R center =====
	reg [1:0] R_CEN_idx; // 4 sources 
	reg [13:0] R_addr, next_R_addr;
	reg [9:0] R_G_sum, R_B_sum; // 10 bits possible case 255*4 = 1020
	
	// ===== B center =====
	reg [1:0] B_CEN_idx; // 4 sources 
	reg [13:0] B_addr, next_B_addr;
	reg [9:0] B_G_sum, B_R_sum; // 10 bits possible case 255*4 = 1020
	
	
	// ===== States =====
	localparam IDLE		= 4'd0; // wait for in_en high
	
	localparam DATA_IN	= 4'd1;
	localparam G_CEN_GEN_ADDR = 4'd2;
	localparam G_CEN_SUM 	  = 4'd3;
	localparam G_CEN_RES 	  = 4'd4; // can write back at the same state
								
	localparam R_CEN_GEN_ADDR = 4'd5;
	localparam R_CEN_SUM 	  = 4'd6;
	localparam R_CEN_RES 	  = 4'd7; // can write back at the same state
								
	localparam B_CEN_GEN_ADDR = 4'd8;
	localparam B_CEN_SUM 	  = 4'd9;
	localparam B_CEN_RES 	  = 4'd10; // can write back at the same state
	
	localparam DONE		= 4'd11;
	
	// ===== save_Mem_select =====
	// select which color of Mem to save back
	wire GR_Row, BG_Row, S_G_Mem, S_R_Mem, S_B_Mem; // Save_color_Mem
	// 1. addr mod128 [0] == 0 && (addr / 128)[0] == 0 (even row e.g. 0, 2, ...)
	// 2. addr mod128 [0] == 1 && (addr / 128)[0] == 1 (odd row)
	assign GR_Row = ((addr >> 7) & 14'd1) == 0; // odd or even check bit0 < failed wired
	assign BG_Row = ((addr >> 7) & 14'd1) == 1;
	// assign GR_Row = ~BG_Row;
	//assign S_G_Mem = ((addr & 14'b00_0000_0111_1111)[0] == 0) && GR_Row;
	assign S_G_Mem = (((addr & 14'd1) == 0) && GR_Row) || (((addr & 14'd1) == 1) && BG_Row);
	assign S_R_Mem = (((addr & 14'd1) == 1) && GR_Row);
	assign S_B_Mem = (((addr & 14'd1) == 0) && BG_Row);
	

	// ===== Next State Logic =====
	always@(*)begin
		case(state)
			IDLE:begin
				if(in_en)begin
					nextstate = DATA_IN; //WRITE_UP;
				end
			end
			
			DATA_IN:begin
				if(addr == 14'd16383) nextstate	= G_CEN_GEN_ADDR; //DONE;
				else nextstate = DATA_IN;
			end
			
			G_CEN_GEN_ADDR:begin
				nextstate = G_CEN_SUM;
			end
			
			G_CEN_SUM:begin
				nextstate = G_CEN_RES;
			end
			
			G_CEN_RES:begin
				if(G_addr == 14'd16254) begin 
					nextstate = R_CEN_GEN_ADDR; //DONE; 
				end
				else begin
					nextstate = G_CEN_GEN_ADDR;
				end 
			end
			
			// ===== R center ====
			R_CEN_GEN_ADDR:begin
				nextstate = R_CEN_SUM;
			end
			
			R_CEN_SUM:begin
				nextstate = R_CEN_RES;
			end				
			
			R_CEN_RES:begin
				if(R_addr == 14'd16253) begin
					nextstate = B_CEN_GEN_ADDR; // DONE;
				end
				else begin 
					nextstate = R_CEN_GEN_ADDR;
				end
			end			

			// ===== B center ====
			B_CEN_GEN_ADDR:begin
				nextstate = B_CEN_SUM;
			end
			
			B_CEN_SUM:begin
				nextstate = B_CEN_RES;
			end				
			
			B_CEN_RES:begin
				if(B_addr == 14'd16126) begin
					nextstate = DONE;
				end
				else begin 
					nextstate = B_CEN_GEN_ADDR;
				end
			end	
			
			DONE:begin
				
			end
		endcase
	end


	// ==== Next G_CEN_addr Logic ====
	always@(*)begin
		case(G_addr & 14'd127)
			14'd125: begin
				next_G_addr = G_addr + 14'd5;
				//next_G_EVEN_ROW = G_EVEN_ROW + 1;
			end
			14'd126: begin
				next_G_addr = G_addr + 14'd3;
				//next_G_EVEN_ROW = G_EVEN_ROW + 1;
			end
			default:
				next_G_addr = G_addr + 14'd2;
		endcase
	end
	assign G_EVEN_ROW = ((G_addr >> 7) & 14'd1) == 0; // select GR_Row

	// ==== Next R center Logic ====
	always@(*)begin
		if((R_addr & 14'd127) == 14'd125)begin // last R in row i.e. col 125
			next_R_addr = R_addr + 14'd132;
		end
		else begin
			next_R_addr = R_addr + 14'd2;
		end
	end
	
	// ==== Next B center Logic ====
	always@(*)begin
		if((B_addr & 14'd127) == 14'd126)begin // last B in row i.e. col 126
			next_B_addr = B_addr + 14'd132;
		end
		else begin
			next_B_addr = B_addr + 14'd2;
		end
	end

	

	// ===== state transition =====
	always @(posedge clk) begin
		if(reset) state <= DATA_IN; //IDLE;
		else state <= nextstate;
	end

	// ===== Sequential =====
	always@(posedge clk)begin
		if(reset)begin
			addr <= 14'd0;
			
			wr_r <= 1;
			wr_g <= 1;
			wr_b <= 1;
			
			//wr_r <= 0;
			addr_r <= 14'd0;
			wdata_r <= 8'd0;
			
			//wr_g <= 0;
			addr_g <= 14'd0;
			wdata_g <= 8'd0;
			
			//wr_b <= 0;
			addr_b <= 14'd0;
			wdata_b <= 8'd0;
			// ==== G Center ====
			G_CEN_idx <= 0;
			//G_EVEN_ROW <= 0;
			//next_G_EVEN_ROW <= 0;
			G_addr <= 14'd129;
			G_R_sum <= 9'd0;
			G_B_sum <= 9'd0;
			
			// ==== R Center ====
			R_CEN_idx <= 2'd3; // -1 + 1
			R_addr <= 14'd257;
			R_G_sum <= 9'd0;
			R_B_sum <= 9'd0;
			
			// ==== B Center ====
			B_CEN_idx <= 2'd3; // -1 + 1
			B_addr <= 14'd130;
			B_G_sum <= 9'd0;
			B_R_sum <= 9'd0;			
			
			done <= 0;
		end
		else begin
			case(state)
				IDLE:begin
					done <= 0;
					// Save the data_in to right mem and others save 0;
				end
				
				DATA_IN:begin
					/*
					// Save the data_in to right mem and others save 0;
					wr_r <= 1;
					wr_g <= 1;
					wr_b <= 1;
					*/
					addr <= addr + 14'd1;
					case({S_R_Mem, S_G_Mem, S_B_Mem})
						3'b100:begin
							addr_r <= addr;
							wdata_r <= data_in;
							addr_g <= addr;
							wdata_g <= 8'd0;
							addr_b <= addr;
							wdata_b <= 8'd0;
						end
						3'b010:begin
							addr_r <= addr;
							wdata_r <= 8'd0;
							addr_g <= addr;
							wdata_g <= data_in;
							addr_b <= addr;
							wdata_b <= 8'd0;
						end
						3'b001:begin
							addr_r <= addr;
							wdata_r <= 8'd0;
							addr_g <= addr;
							wdata_g <= 8'd0;
							addr_b <= addr;
							wdata_b <= data_in;
						end
					endcase
				end
				
				G_CEN_GEN_ADDR:begin
					wr_r <= 0;
					wr_b <= 0;
				
					if(!G_EVEN_ROW)begin
						// G_center is on odd row, i.e. R is on top
						if(G_CEN_idx) begin
							addr_r <= G_addr + 14'd128;
							addr_b <= G_addr + 14'd1;
						end
						else begin
							addr_r <= G_addr - 14'd128;
							addr_b <= G_addr - 14'd1;
						end
					end
					else begin
						// G_center is on even row, i.e. B is on top
						if(G_CEN_idx) begin
							addr_b <= G_addr + 14'd128;
							addr_r <= G_addr + 14'd1;
						end
						else begin
							addr_b <= G_addr - 14'd128;
							addr_r <= G_addr - 14'd1;
						end
					end
					G_CEN_idx <= G_CEN_idx + 1;
				
					// just for color check
					wr_g <= 0;
					addr_g <= G_addr;
				end
				
				G_CEN_SUM:begin
					G_R_sum <= G_R_sum + rdata_r;
					G_B_sum <= G_B_sum + rdata_b;
				end
				
				G_CEN_RES:begin
					if(G_CEN_idx == 0)begin
						// write back setup
						wr_r <= 1;
						wr_b <= 1;
						addr_r <= G_addr;
						addr_b <= G_addr;
					
						wdata_r <= G_R_sum[8:1]; // shift 1 (div2)
						wdata_b <= G_B_sum[8:1];
						
						// reset
						G_R_sum <= 14'd0;
						G_B_sum <= 14'd0;
						// next iteration
						G_addr <= next_G_addr; // next G_Center
						//G_EVEN_ROW <= next_G_EVEN_ROW;
					end
					else begin
						// not change
						G_R_sum <= G_R_sum;
						G_B_sum <= G_B_sum;
					end
				end
				
				// ===== R center ====
				R_CEN_GEN_ADDR:begin
					wr_g <= 0;
					wr_b <= 0;
					
					case(R_CEN_idx)
						2'd0:begin
							addr_g <= R_addr - 14'd128;
							addr_b <= R_addr - 14'd129;
						end
						2'd1:begin
							addr_g <= R_addr - 14'd1;
							addr_b <= R_addr - 14'd127;
						end
						2'd2:begin
							addr_g <= R_addr + 14'd1;
							addr_b <= R_addr + 14'd127;
						end
						2'd3:begin
							addr_g <= R_addr + 14'd128;
							addr_b <= R_addr + 14'd129;
						end
					endcase
					R_CEN_idx <= R_CEN_idx + 2'd1;
				
					// just for color check
					wr_r <= 0;
					addr_r <= R_addr;
				end
				
				R_CEN_SUM:begin
					R_G_sum <= R_G_sum + rdata_g;
					R_B_sum <= R_B_sum + rdata_b;
				end				
				
				R_CEN_RES:begin
					if(R_CEN_idx == 2'd3)begin
						// write back setup
						wr_g <= 1;
						wr_b <= 1;
						addr_g <= R_addr;
						addr_b <= R_addr;
					
						wdata_g <= R_G_sum[9:2]; // shift 2 (div4)
						wdata_b <= R_B_sum[9:2];
						
						// reset
						R_G_sum <= 14'd0;
						R_B_sum <= 14'd0;
						// next iteration
						R_addr <= next_R_addr;
					end
					else begin
						// not change
						R_G_sum <= R_G_sum;
						R_B_sum <= R_B_sum;
					end
				end				
				
				
				// ===== B center ====
				B_CEN_GEN_ADDR:begin
					wr_g <= 0;
					wr_r <= 0;
					
					case(B_CEN_idx)
						2'd0:begin
							addr_g <= B_addr - 14'd128;
							addr_r <= B_addr - 14'd129;
						end
						2'd1:begin
							addr_g <= B_addr - 14'd1;
							addr_r <= B_addr - 14'd127;
						end
						2'd2:begin
							addr_g <= B_addr + 14'd1;
							addr_r <= B_addr + 14'd127;
						end
						2'd3:begin
							addr_g <= B_addr + 14'd128;
							addr_r <= B_addr + 14'd129;
						end
					endcase
					B_CEN_idx <= B_CEN_idx + 2'd1;
				
					// just for color check
					wr_b <= 0;
					addr_b <= B_addr;
				end
				
				B_CEN_SUM:begin
					B_G_sum <= B_G_sum + rdata_g;
					B_R_sum <= B_R_sum + rdata_r;				
				end				
				
				B_CEN_RES:begin
					if(B_CEN_idx == 2'd3)begin
						// write back setup
						wr_g <= 1;
						wr_r <= 1;
						addr_g <= B_addr;
						addr_r <= B_addr;
					
						wdata_g <= B_G_sum[9:2]; // shift 2 (div4)
						wdata_r <= B_R_sum[9:2];
						
						// reset
						B_G_sum <= 14'd0;
						B_R_sum <= 14'd0;
						// next iteration
						B_addr <= next_B_addr;
					end
					else begin
						// not change
						B_G_sum <= B_G_sum;
						B_R_sum <= B_R_sum;
					end
				end
				
				DONE:begin
					done <= 1;
				end
					
			endcase
		end
	end


endmodule

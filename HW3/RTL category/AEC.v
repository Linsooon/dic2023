module AEC(clk, rst, ascii_in, ready, valid, result);
	// Input signal
	input clk;
	input rst;
	input ready;
	input [7:0] ascii_in;

	// Output signal
	output reg valid;
	output reg [6:0] result;
	
//===== Your design ===== //
localparam DATA_IN = 3'd0;
localparam IN2POST = 3'd1;
localparam CAL = 3'd2;
localparam CHECK = 3'd3;
localparam OUT = 3'd4;
localparam IDLE = 3'd5;

reg [2:0] state, next_state;
reg [7:0] infix_string [15:0], op_stack [15:0], postfix_string [15:0];
reg [7:0] cal_stack [15:0]; // can further improve by reuse the stack.

reg [4:0]  in_str_len, post_str_len;
reg [3:0]  in_idx, op_idx, post_str_idx, cal_idx; 

integer i; // reset use 
// reg [3:0] i; // reset use 

wire [3:0] op_idx_minus_one = op_idx - 4'd1; // top


// ====== NEXT STATE LOGIC ======
always @(posedge clk) begin
    if(rst) state <= DATA_IN;
    else state <= next_state;
end


always @(*) begin
    case(state)
        DATA_IN:begin
            if(ascii_in == 8'd61) next_state = IN2POST;
            else next_state = DATA_IN;
        end
        IN2POST:begin
            if(in_idx < in_str_len) next_state = IN2POST; // keep pop
            else begin
				if(op_idx == 0) next_state = CAL;
				else next_state = IN2POST;
			end
		end
		CAL:begin 
			if(post_str_idx < post_str_len) next_state = CAL;
			else next_state = OUT;
		end
		
        OUT:begin
            next_state = IDLE;
        end
		
		IDLE:begin 
			next_state = DATA_IN;
		end
        default:begin
            next_state = DATA_IN;
        end
    endcase
end

// ====== OUTPUT LOGIC =======
always @(posedge clk or posedge rst) begin
    if(rst)begin
		
        for(i = 0; i <= 4'd15; i = i + 1) begin	
			infix_string[i] <=  8'h00;
			op_stack[i] <= 8'h00;
			postfix_string[i] <= 8'h00;
			cal_stack[i] <= 8'h00;
		end
		
        valid <= 1'b0;
        result <= 7'b0;
        
		in_str_len <= 5'd0;
		post_str_len <= 5'd0;
		
        in_idx <= 4'd0;
        op_idx <= 4'd0;
        post_str_idx <= 4'd0;
		cal_idx <= 4'd0;
    end
	
    else begin
		case(state)
			DATA_IN:begin 
				if(ascii_in == 8'd61)begin 
					in_str_len <= in_idx; 
					in_idx <= 0;
				end
				else begin 
					valid <= 1'b0;
					result <= 7'b0;
					
					infix_string[in_idx] <= ascii_in;
					in_idx <= in_idx + 1;
				end
			end
			
			IN2POST:begin
				if(in_idx < in_str_len)begin 
					if ((8'd48 <= infix_string[in_idx] && infix_string[in_idx] <= 8'd57) 
							|| (8'd97 <= infix_string[in_idx] && infix_string[in_idx] <= 8'd102)) begin
							postfix_string[post_str_idx] <= infix_string[in_idx];
							post_str_idx <= post_str_idx + 1;
							in_idx <= in_idx + 1;
					end
					else begin 
						case(infix_string[in_idx])
							8'd40:begin // '('
								op_stack[op_idx] <= infix_string[in_idx];
								op_idx <= op_idx + 1;
								in_idx <= in_idx + 1;
							end
							8'd41:begin // ')'
								if(op_stack[op_idx_minus_one] == 8'd40)begin
									// pop '('
									op_idx <= op_idx - 1;
									// 檢查 infix 下一個
									in_idx <= in_idx + 1; 
								end
								else begin 
									// pop before '('
									postfix_string[post_str_idx] <= op_stack[op_idx_minus_one];
									op_idx <= op_idx - 1;
									post_str_idx <= post_str_idx + 1;
								end
							end
							
							8'd42:begin // '*'
								if(op_stack[op_idx_minus_one] == 8'd42)begin // top is '*' itself
									// pop
									postfix_string[post_str_idx] = op_stack[op_idx_minus_one];
									//op_idx <= op_idx - 1;
									// no need to cover '*' in the stack.
									post_str_idx <= post_str_idx + 1; // 匴出下個 post 存放位置
									in_idx <= in_idx + 1;
								end
								else begin 
									op_stack[op_idx] = infix_string[in_idx]; // push '*' to stack
									op_idx <= op_idx + 1;
									in_idx <= in_idx + 1;
								end
							end
							
							8'd43:begin // '+'
								if(op_idx == 0) begin 
									// empty just push
									op_stack[op_idx] <= infix_string[in_idx];
									op_idx <= op_idx + 1;
									in_idx <= in_idx + 1;
								end
								else begin 
									// pop until empty or meet '('
									if(op_stack[op_idx_minus_one] == 8'd40) begin
										// push '+'
										op_stack[op_idx] <= infix_string[in_idx];
										in_idx <= in_idx + 1;
										op_idx <= op_idx + 1;
									end
									else begin 
										postfix_string[post_str_idx] = op_stack[op_idx_minus_one];
										op_idx <= op_idx - 1;
										post_str_idx <= post_str_idx + 1;
									end
								end
							end
							8'd45:begin // '-'
								if(op_idx == 0) begin 
									// empty just push
									op_stack[op_idx] <= infix_string[in_idx];
									op_idx <= op_idx + 1;
									in_idx <= in_idx + 1;
								end
								else begin 
									// pop until empty or meet '('
									if(op_stack[op_idx_minus_one] == 8'd40) begin
										// push '-'
										op_stack[op_idx] <= infix_string[in_idx];
										in_idx <= in_idx + 1;
										op_idx <= op_idx + 1;
									end
									else begin 
										postfix_string[post_str_idx] = op_stack[op_idx_minus_one];
										post_str_idx <= post_str_idx + 1;
										op_idx <= op_idx - 1;
									end
								end
							end
						endcase
					end
				end
				
				else begin 
					if(op_idx == 0)begin 
						post_str_len <= post_str_idx;
						post_str_idx <= 0;
					end
					else begin 
						postfix_string[post_str_idx] = op_stack[op_idx_minus_one];
						op_idx <= op_idx - 1;
						post_str_idx <= post_str_idx + 1;
					end
				end
			end
			
			CAL:begin 
				if(post_str_idx < post_str_len)begin 
					if (8'd48 <= postfix_string[post_str_idx] && postfix_string[post_str_idx] <= 8'd57) begin // 0~9
						cal_stack[cal_idx] <= postfix_string[post_str_idx] - 8'd48;
						cal_idx <= cal_idx + 1;
						post_str_idx <= post_str_idx + 1;
					end
					else if (8'd97 <= postfix_string[post_str_idx] && postfix_string[post_str_idx] <= 8'd102) begin
						cal_stack[cal_idx] <= postfix_string[post_str_idx] - 8'd87;
						cal_idx <= cal_idx + 1;
						post_str_idx <= post_str_idx + 1;
					end
					else begin 
						case(postfix_string[post_str_idx])
							/* 
								|  | <- cal_idx
								|v1|
								|v2|
							after calculation
								|  | 
								|  | <- cal_idx
								|re|
							
							*/ 
							8'd42:begin // '*'
								cal_idx <= cal_idx - 1;
								cal_stack[cal_idx-2]  <= cal_stack[cal_idx-1] * cal_stack[cal_idx - 2];
								post_str_idx <= post_str_idx + 1;
							end
							8'd43:begin // '+'
								cal_idx <= cal_idx - 1;
								cal_stack[cal_idx-2]  <= cal_stack[cal_idx-1] + cal_stack[cal_idx - 2];
								post_str_idx <= post_str_idx + 1;
							end
							8'd45:begin // '-'
								cal_idx <= cal_idx - 1;
								// ristriction shows there is no negative value during calculation
								// order of oprands matter.
								cal_stack[cal_idx-2]  <= cal_stack[cal_idx - 2] - cal_stack[cal_idx - 1];
								post_str_idx <= post_str_idx + 1;
							end
						endcase
					end	
				end
				else begin 
					/// ?? 
				end
			end
			
			OUT: begin 
				if(cal_idx == 1) begin 
					valid = 1;
					result <= cal_stack[0];
				end
				else begin // failed
					valid = 1;
					result <= 7'hFF;
				end
			end
			
			IDLE:begin
				for(i = 0; i <= 4'd15; i = i + 1) begin	
					infix_string[i] <=  8'h00;
					op_stack[i] <= 8'h00;
					postfix_string[i] <= 8'h00;
					cal_stack[i] <= 8'h00;
				end
				
				valid <= 1'b0;
				result <= 7'b0;
        
				in_str_len <= 5'd0;
				post_str_len <= 5'd0;
		
				in_idx <= 4'd0;
				op_idx <= 4'd0;
				post_str_idx <= 4'd0;
				cal_idx <= 4'd0;
			end
		endcase
	end
end
endmodule
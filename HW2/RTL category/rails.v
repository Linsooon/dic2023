// test is executed at negative edge.
// number of incoming train[0], expecting departure order
// 6 2 4 1 3 6 5 
// 1, 2		// top : 2    
// 1	    // train 1 leave
// 1,3		// push : 3, top 3
// 1,3,4	// push : 4, top : 4
// 1,3      // train 4 leave
// 1,3      // top(3) > pop(1), vaild up train 1 cant leave before 3 
// valid 1 result 0
// TEST CASE 
// 5 4 3 2 5 1
// 1, 2, 3, 4 // top : 4 pop 4 >= top > vaild
// 1, 2, 3,   // 
// 1, 2, 	  // 
// 1, 5		  // top : 5
// 1
// vaild 1 result 1 

/* 
bool validateStackSequences(int* pushed, int pushedSize, int* popped, int poppedSize) {
    int stack[pushedSize];
    int top = -1;
    int j = 0;
    for(int i = 0; i < pushedSize; i++){
        top++;
        stack[top] = pushed[i];
        while(top >= 0 && stack[top] == popped[j]) {
            j += 1;
            top--;
        }
    }
    return j == poppedSize;
}
*/

`define SET_SIZE 2'b00
`define SAVE_SEQ 2'b01
`define CHECK	2'b10
`define IDLE	2'b11 // after check state

module rails(clk, reset, data, valid, result);

	input        clk;
	input        reset;
	input  [3:0] data;
	output reg   valid;
	output reg   result; 

	/*
		Write Your Design Here ~
	*/
	reg [3:0] stack_size; // number of coming trains ranges from 3 to 10.
	reg [3:0] state, next_state; 
	reg [3:0] popseq [9:0], stack [9:0];
	reg [3:0] seq_idx;
	
	integer i,top, j;
	
	always @(posedge clk or posedge reset) begin 
		if (reset) begin 
			valid <= 0;
			result <= 0;
			stack_size <= 4'b0;
			state <= `IDLE;
			next_state <= `IDLE;
			seq_idx <= 0;
			for (i = 0; i <= 3'd10; i = i + 1) 
            begin
				popseq[i] <= 4'd0;
                stack[i] <= 4'd0;
            end
		end
		else begin
			state <= next_state;
		end
	end

	always @(*) begin 
		case(state) 
			`SET_SIZE : begin
				valid = 0;
				if (stack_size == 0) begin
					stack_size = data;
					next_state = `SAVE_SEQ;
				end
			end
			
			`SAVE_SEQ : begin
				if(seq_idx < stack_size)begin
					popseq[seq_idx] = data;
					seq_idx = seq_idx + 1;
				end
				else begin
					next_state = `CHECK;
				end
			end
			
			`CHECK : begin // main check logic
				/*
				top = -1;
				j = 0;
				*/
				for(i = 0; i < stack_size; i = i+1) begin
					top = top + 1;
					stack[top] = i+1; // push train number
					while (top >= 0 && stack[top] == popseq[j]) begin 
						j = j + 1;
						top = top - 1;
					end
				end
				if(j == stack_size) begin
					valid = 1;
					result = 1;
					next_state = `IDLE;
				end
				else begin
					valid = 1;
					result = 0;
					next_state = `IDLE;
				end				
			end
			
			`IDLE : begin 
				top = -1;
				j = 0;
				if(data)begin
					stack_size = 0;
					seq_idx = 0;
					next_state = `SET_SIZE;
				end
			end
		endcase
	end

endmodule
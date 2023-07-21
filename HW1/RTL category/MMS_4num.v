module cmp(res, num_a, num_b);
	input [7:0] num_a, num_b;
	output reg res;
	always @* begin
		if(num_a < num_b) begin
			assign res = 1'b1;
		end
		else begin
			assign res = 1'b0;
		end 
	end
endmodule

module muxMM(res, input1, input2, sel_cmp);
	input [7:0] input1, input2;
	input [1:0] sel_cmp;
	output reg [7:0] res;
	always @* begin
		case(sel_cmp)
		2'b00: assign res = input1;
		2'b01: assign res = input2;
		2'b10: assign res = input2;
		2'b11: assign res = input1;
		endcase
	end
endmodule

// if the select is 1, than return minimum
module MMS_4num(result, select, number0, number1, number2, number3);
	input        select;
	input  [7:0] number0;
	input  [7:0] number1;
	input  [7:0] number2;
	input  [7:0] number3;
	output [7:0] result; 
	// connecting wires
	wire cmpS0_0_muxS0_0, cmpS0_1_muxS0_1, cmpS1_0_muxS1_0;
	wire [7:0] muxS0_0_cmpS1, muxS0_1_cmpS1; 
	
	cmp cmpS0_0(.res(cmpS0_0_muxS0_0), .num_a(number0), .num_b(number1));
	cmp cmpS0_1(.res(cmpS0_1_muxS0_1), .num_a(number2), .num_b(number3));
	muxMM muxS0_0(.res(muxS0_0_cmpS1), .input1(number0), .input2(number1), .sel_cmp({select, cmpS0_0_muxS0_0}));
	muxMM muxS0_1(.res(muxS0_1_cmpS1), .input1(number2), .input2(number3), .sel_cmp({select, cmpS0_1_muxS0_1}));
	
	cmp cmpS1_0(.res(cmpS1_0_muxS1_0), .num_a(muxS0_0_cmpS1), .num_b(muxS0_1_cmpS1));
	muxMM muxS1_0(.res(result), .input1(muxS0_0_cmpS1), .	input2(muxS0_1_cmpS1), .sel_cmp({select, cmpS1_0_muxS1_0}));
endmodule
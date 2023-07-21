
module MMS_8num(result, select, number0, number1, number2, number3, number4, number5, number6, number7);

	input        select;
	input  [7:0] number0;
	input  [7:0] number1;
	input  [7:0] number2;
	input  [7:0] number3;
	input  [7:0] number4;
	input  [7:0] number5;
	input  [7:0] number6;
	input  [7:0] number7;
	output [7:0] result; 
	// connecting wires
	wire [7:0] MMS4S0_0_cmpS1_0, MMS4S0_1_cmpS1_0;
	wire cmpS1_0_muxS1_0;

	MMS_4num MMS4S0_0(.result(MMS4S0_0_cmpS1_0), .select(select), .number0(number0), .number1(number1), .number2(number2), .number3(number3));
	MMS_4num MMS4S0_1(.result(MMS4S0_1_cmpS1_0), .select(select), .number0(number4), .number1(number5), .number2(number6), .number3(number7));
	
	cmp cmpS1_0(.res(cmpS1_0_muxS1_0), .num_a(MMS4S0_0_cmpS1_0), .num_b(MMS4S0_1_cmpS1_0));
	muxMM muxS1_0(.res(result), .input1(MMS4S0_0_cmpS1_0), .input2(MMS4S0_1_cmpS1_0), .sel_cmp({select, cmpS1_0_muxS1_0}));

endmodule
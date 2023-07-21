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

localparam LOAD = 2'd0;
localparam WRITE = 2'd1;
localparam FINISH = 2'd2;

reg [1:0] state, next;
reg [7:0] buffer1 [0:127];
reg [7:0] buffer2 [0:127];
reg [7:0] buffer3 [0:2];
reg [8:0] count;
reg [13:0] addr;

/* bayer pattern
G1 R
B G2
*/
wire [7:0] avg[0:3]; // average value can be divided into 4 cases
assign avg[0] = (({2'd0, buffer1[1]} + {2'd0, buffer2[0]}) + ({2'd0, buffer2[2]} + {2'd0, buffer3[1]})) >> 2; // G on R or G on B
assign avg[1] = ({1'd0, buffer1[1]} + {1'd0, buffer3[1]}) >> 1; // B on G1 or R on G2
assign avg[2] = ({1'd0, buffer2[0]} + {1'd0, buffer2[2]}) >> 1; // R on G1 or B on G2
assign avg[3] = (({2'd0, buffer1[0]} + {2'd0, buffer1[2]}) + ({2'd0, buffer3[0]} + {2'd0, buffer3[2]})) >> 2; // B on R or R on B

integer i;

always @ (posedge clk or posedge reset) begin // keep the last 259 pixels
    if(reset) begin
        count <= 0;
        for(i = 0; i < 128; i = i + 1) begin 
            buffer1[i] <= 0;
            buffer2[i] <= 0;
        end
        buffer3[0] <= 0;
        buffer3[1] <= 0;
        buffer3[2] <= 0;
    end
    else begin
        if(in_en) begin
            for(i = 0; i < 127; i = i + 1) begin 
                buffer1[i] <= buffer1[i+1];
                buffer2[i] <= buffer2[i+1];
            end
            buffer1[127] <= buffer2[0];
            buffer2[127] <= buffer3[0];
            buffer3[0] <= buffer3[1];
            buffer3[1] <= buffer3[2];
            buffer3[2] <= data_in;

            count <= count + 1;
        end
    end
end

always @ (posedge clk or posedge reset) begin
    if(reset) state <= LOAD;
    else state <= next;
end

always @ (posedge clk or posedge reset) begin
    if(reset) begin
        addr <= 129; // first output address
        wr_r <= 0;
        wr_g <= 0;
        wr_b <= 0;
        done <= 0;
    end
    else begin
        case(state) 
            WRITE: begin
                wr_r <= 1;
                wr_g <= 1;
                wr_b <= 1;
                addr_r <= addr;
                addr_g <= addr;
                addr_b <= addr;
                addr <= addr + 1;
                case({addr[7], addr[0]})
                    2'b00: begin // G1
                        wdata_r <= avg[2];
                        wdata_g <= buffer2[1];
                        wdata_b <= avg[1];
                    end
                    2'b01: begin // R
                        wdata_r <= buffer2[1];
                        wdata_g <= avg[0];
                        wdata_b <= avg[3];
                    end
                    2'b10: begin // B
                        wdata_r <= avg[3];
                        wdata_g <= avg[0];
                        wdata_b <= buffer2[1];
                    end
                    2'b11: begin // G2
                        wdata_r <= avg[1];
                        wdata_g <= buffer2[1];
                        wdata_b <= avg[2];
                    end
                endcase
            end
            FINISH: begin
                wr_r <= 0;
                wr_g <= 0;
                wr_b <= 0;
                done <= 1;
            end
        endcase
    end
end

always @ (*) begin
    case(state)
        LOAD: begin
            if(count == 258) next = WRITE;
            else next = LOAD;
        end
        WRITE: begin
            if(addr == 16254) next = FINISH;
            else next = WRITE;
        end
        default: next = FINISH;
    endcase
end

endmodule
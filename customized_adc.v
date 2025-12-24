`timescale 1ns / 1ps

module customized_adc(sck, ws, sd, rst, start, data, flag_in, flag_out);
input [23:0] sd;
input rst, sck, ws, start, flag_in;
output data, flag_out;

wire flag_in;
(* keep = "true" *) reg [31:0]      data;
reg [4:0]       bit_count = 5'd0;
reg [1:0]       delay;
reg [0:0] state;
reg flag_out;
reg flag_in_d1;// flag_in_d2;
wire flag_in_negedge;
//assign flag_in_negedge = flag_in_d2 & ~flag_in_d1;
assign flag_in_negedge = flag_in_d1 & ~flag_in;

initial begin
    bit_count <=  5'd0;
    delay   <=  1'b0;
    flag_out <= 1'b0;
    state <= 1'b0;
end

always @(posedge sck or posedge rst)begin
    if(rst)begin
            bit_count <=  5'd0;
            delay   <=  1'b0;
            flag_out <= 1'b0;
            flag_in_d1 <= 1'b0;
            //flag_in_d2 <= 1'b0;
            state<=1'b0;
        end 
    else begin
        flag_in_d1 <= flag_in;
        //flag_in_d2 <= flag_in_d1;
        if(start)begin
            state <= 1'b1;
        end 
        if (flag_in_negedge) begin
            flag_out <= 1'b0;
        end
        if(state)begin
            //flag_out <= flag_in;
            if(~ws && !flag_out)begin
                    if(delay == 1'b0) begin
                        delay <= 1'b1;
                        flag_out <= 1'b0;
                    end
                    else begin
                        if(bit_count < 6'd24) begin
                            bit_count <=  bit_count + 5'b1;
                        end
                        else begin
                            if(bit_count == 6'd24) begin
                                data[31:8] <= sd; // if all data in one channel is loaded, buffer to output data(32bit) 
                                flag_out <= 1'b1; // tell mux the data is ready
                                bit_count <=  bit_count + 5'b1;
                            end
                        end
                    end
            end
            else begin
                bit_count <= 5'd0;
                delay   <=  1'b0;
            end
        end
    end
end


endmodule

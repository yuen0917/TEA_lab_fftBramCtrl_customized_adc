`timescale 1ns / 1ps

module fftBramCtrl (
    input  wire         clk,
    input  wire         rst_n,

    // AXI Stream Input (from FFT)
    input  wire [383:0] s_axis_tdata,
    input  wire         s_axis_tvalid,
    input  wire         s_axis_tlast,
    output wire         s_axis_tready,

    // BRAM Port A Output
    output wire [ 31:0] bram_addr,
    output wire [ 31:0] bram_din_re,
    output wire [ 31:0] bram_din_im,
    output reg  [  3:0] bram_we,
    output wire         bram_en,
    output wire         bram_rst
);

    reg [ 3:0] micCount;
    reg [31:0] dataRegReal,dataRegImag;
    reg [12:0] addr_counter;
    // bram depth is currently 2048
    // 256 bit fft * 8 channels = 2048

    reg [383:0] s_axis_tdata_reg;
    // reg         s_axis_tready_reg;
    reg         busy;

    assign s_axis_tready = ~busy;

    // BRAM assignments
    assign bram_rst = ~rst_n;
    assign bram_en  = 1'b1;

    assign bram_din_re = dataRegReal;
    assign bram_din_im = dataRegImag;
    assign bram_addr   = addr_counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            addr_counter     <= -13'd4;
            micCount         <=   4'd0;
            dataRegImag      <=  32'd0;
            dataRegReal      <=  32'd0;
            bram_we          <=   4'd0;
            busy             <=   1'b0;
            s_axis_tdata_reg <= 384'd0;
        end else begin
            if(!busy) begin
                bram_we <= 4'd0;
                if (s_axis_tvalid) begin
                    busy             <= 1'b1;
                    micCount         <= 4'd0;
                    s_axis_tdata_reg <= s_axis_tdata;
                end
            end
            else begin
                case(micCount)
                    4'd0: begin
                        dataRegImag  <= {{8{s_axis_tdata_reg[47]}},s_axis_tdata_reg[47:24]};
                        dataRegReal  <= {{8{s_axis_tdata_reg[23]}},s_axis_tdata_reg[23:0]};
                        micCount     <= micCount + 1;
                        bram_we      <= 4'b1111;
                        addr_counter <= addr_counter + 4;
                    end
                    4'd1: begin
                        dataRegImag  <= {{8{s_axis_tdata_reg[95]}},s_axis_tdata_reg[95:72]};
                        dataRegReal  <= {{8{s_axis_tdata_reg[71]}},s_axis_tdata_reg[71:48]};
                        micCount     <= micCount + 1;
                        bram_we      <= 4'b1111;
                        addr_counter <= addr_counter + 4;
                    end
                    4'd2: begin
                        dataRegImag  <= {{8{s_axis_tdata_reg[143]}},s_axis_tdata_reg[143:120]};
                        dataRegReal  <= {{8{s_axis_tdata_reg[119]}},s_axis_tdata_reg[119:96]};
                        micCount     <= micCount + 1;
                        bram_we      <= 4'b1111;
                        addr_counter <= addr_counter + 4;
                    end
                    4'd3: begin
                        dataRegImag  <= {{8{s_axis_tdata_reg[191]}},s_axis_tdata_reg[191:168]};
                        dataRegReal  <= {{8{s_axis_tdata_reg[167]}},s_axis_tdata_reg[167:144]};
                        micCount     <= micCount + 1;
                        bram_we      <= 4'b1111;
                        addr_counter <= addr_counter + 4;
                    end
                    4'd4: begin
                        dataRegImag  <= {{8{s_axis_tdata_reg[239]}},s_axis_tdata_reg[239:216]};
                        dataRegReal  <= {{8{s_axis_tdata_reg[215]}},s_axis_tdata_reg[215:192]};
                        micCount     <= micCount + 1;
                        bram_we      <= 4'b1111;
                        addr_counter <= addr_counter + 4;
                    end
                    4'd5: begin
                        dataRegImag  <= {{8{s_axis_tdata_reg[287]}},s_axis_tdata_reg[287:264]};
                        dataRegReal  <= {{8{s_axis_tdata_reg[263]}},s_axis_tdata_reg[263:240]};
                        micCount     <= micCount + 1;
                        bram_we      <= 4'b1111;
                        addr_counter <= addr_counter + 4;
                    end
                    4'd6: begin
                        dataRegImag  <= {{8{s_axis_tdata_reg[335]}},s_axis_tdata_reg[335:312]};
                        dataRegReal  <= {{8{s_axis_tdata_reg[311]}},s_axis_tdata_reg[311:288]};
                        micCount     <= micCount + 1;
                        bram_we      <= 4'b1111;
                        addr_counter <= addr_counter + 4;
                    end
                    4'd7: begin
                        dataRegImag  <= {{8{s_axis_tdata_reg[383]}},s_axis_tdata_reg[383:360]};
                        dataRegReal  <= {{8{s_axis_tdata_reg[359]}},s_axis_tdata_reg[359:336]};
                        micCount     <= micCount + 1;
                        bram_we      <= 4'b1111;
                        addr_counter <= addr_counter + 4;
                    end
                    4'd8: begin
                        busy     <= 1'b0;
                        micCount <= 4'd0;
                        bram_we  <= 4'b0000;
                    end
                    default: begin
                        dataRegImag <= 32'd0;
                        dataRegReal <= 32'd0;
                        busy        <= 1'b0;
                    end
                endcase
            end
        end
    end

endmodule
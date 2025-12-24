`timescale 1ns / 1ps

module fftBramCtrl_v2 (
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
    localparam S_IDLE = 2'b00;
    localparam S_BUSY = 2'b01;
    localparam S_DONE = 2'b10;

    reg [1:0] state;
    reg [1:0] next_state;

    reg [ 3:0] micCount;
    reg [31:0] dataRegReal,dataRegImag;
    reg [12:0] addr_counter;
    // bram depth is currently 2048
    // 256 bit fft * 8 channels = 2048

    reg [383:0] s_axis_tdata_reg;
    reg         s_axis_tready_reg;
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
            state <= S_IDLE;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
      case(state)
        S_IDLE: begin
          next_state <= (s_axis_tvalid) ? S_BUSY : S_IDLE;
        end
        S_BUSY: begin
          next_state <= (micCount == 4'd8) ? S_DONE : S_BUSY;
        end
        S_DONE: begin
          next_state <= S_IDLE;
        end
        default: begin
            next_state <= S_IDLE;
        end
      endcase
    end

    always @(posedge clk or negedge rst_n) begin
    end


endmodule
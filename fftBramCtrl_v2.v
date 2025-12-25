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
          next_state <= (micCount == 4'd7) ? S_DONE : S_BUSY;
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
      if(!rst_n) begin
        addr_counter      <= -13'd4;
        micCount          <=  4'd0;
        dataRegReal       <= 32'd0;
        dataRegImag       <= 32'd0;
        s_axis_tready_reg <=  1'b0;
        busy              <=  1'b0;    
        bram_we           <=  4'b0;   
      end else begin
        case(state)
          S_IDLE: begin
            bram_we <= 4'b0;
            if(s_axis_tvalid) begin
              busy             <=  1'b1;
              micCount         <=  4'd0;
              s_axis_tdata_reg <= s_axis_tdata;
            end
          end
          S_BUSY: begin
            dataRegReal      <= {{8{s_axis_tdata_reg[23]}}, s_axis_tdata_reg[23:0]};
            dataRegImag      <= {{8{s_axis_tdata_reg[47]}}, s_axis_tdata_reg[47:24]};
            s_axis_tdata_reg <= s_axis_tdata_reg >> 48;
            micCount         <= (micCount == 4'd7) ? 4'd0 : micCount + 1;
            bram_we          <= 4'b1111;
            addr_counter     <= addr_counter + 4;
          end
          S_DONE: begin
            busy         <= 1'b0;
            micCount     <= 4'd0;
            bram_we      <= 4'd0;
          end
          default: begin
            addr_counter      <= -13'd4;
            micCount          <=  4'd0;
            dataRegReal       <= 32'd0;
            dataRegImag       <= 32'd0;
            s_axis_tready_reg <=  1'b0;
            busy              <=  1'b0;    
            bram_we           <=  4'b0;   
          end
        endcase
      end
    end

endmodule
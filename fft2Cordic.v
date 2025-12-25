`timescale 1ns / 1ps

module cutHalf #(
    parameter DATA_WIDTH = 48, // Matches the cordic_0 input width in your design
    parameter FFT_LENGTH = 512
) (
    input  wire                  aclk,
    input  wire                  aresetn,

    // Slave Interface (Input from FFT or Width Converter)
    input  wire [383:0] s_axis_tdata,
    input  wire                  s_axis_tvalid,
    input  wire                  s_axis_tlast, // From FFT (asserted at 511)
    output wire                  s_axis_tready,

    // Master Interface (Output to CORDIC)
    output wire [47:0] m_axis_tdata,
    output wire                  m_axis_tvalid,
    output wire                  m_axis_tlast, // Generates new tlast at 255
    input  wire                  m_axis_tready
);

    // Calculate half length
    localparam KEEP_LENGTH = FFT_LENGTH / 2;
    
    // Counter to track the sample index (need 9 bits for 0-511)
    reg [8:0] sample_cnt;

    //-------------------------------------------------------------------------
    // Sample Counter Logic
    //-------------------------------------------------------------------------
    always @(posedge aclk) begin
        if (!aresetn) begin
            sample_cnt <= 0;
        end else begin
            // Increment counter only when a transaction occurs (valid & ready)
            if (s_axis_tvalid && s_axis_tready) begin
                if (s_axis_tlast || sample_cnt == (FFT_LENGTH - 1)) begin
                    sample_cnt <= 0;
                end else begin
                    sample_cnt <= sample_cnt + 1;
                end
            end
        end
    end

    //-------------------------------------------------------------------------
    // Filtering Logic
    //-------------------------------------------------------------------------
    
    // Determine if we are in the "Keep" zone (first half)
    wire keep_data;
    assign keep_data = (sample_cnt < KEEP_LENGTH);

    // Data path: Pass data through directly
    assign m_axis_tdata = s_axis_tdata[47:0];

    // Valid signal: Assert only if upstream is valid AND we are in the keep zone
    assign m_axis_tvalid = s_axis_tvalid && keep_data;

    // TLAST Generation:
    // The CORDIC needs to know the frame ends at 255, not 511.
    // Assert tlast when we are at index 255 and the transaction is valid.
    assign m_axis_tlast = (sample_cnt == (KEEP_LENGTH - 1)) && m_axis_tvalid;

    //-------------------------------------------------------------------------
    // Backpressure (TREADY) Logic
    //-------------------------------------------------------------------------
    // This is the most critical part. 
    // 1. If we are in the "Keep" zone, we pass the CORDIC's readiness (m_axis_tready) to the FFT.
    // 2. If we are in the "Discard" zone (sample_cnt >= 256), we MUST assert ready (1'b1) 
    //    to the FFT so it can dump the rest of the frame. If we don't, the FFT will stall.
    
    assign s_axis_tready = keep_data ? m_axis_tready : 1'b1;

endmodule
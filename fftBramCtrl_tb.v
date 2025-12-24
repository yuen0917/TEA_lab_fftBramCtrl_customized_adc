`timescale 1ns / 1ps

module fftBramCtrl_tb;

    // =========================================================================
    // 1. Signals & Constants
    // =========================================================================
    reg clk;
    reg rst_n;

    // DUT Interface
    reg [383:0] s_axis_tdata;
    reg s_axis_tvalid;
    reg s_axis_tlast;
    wire s_axis_tready;

    wire [31:0] bram_addr;
    wire [31:0] bram_din_re;
    wire [31:0] bram_din_im;
    wire [3:0]  bram_we;
    wire bram_en;
    wire bram_rst;

    // Simulation Control
    parameter CLK_PERIOD = 10;
    parameter NUM_PACKETS = 1000; // Stress test with 1000 packets (8000 writes)

    integer error_count = 0;
    integer success_count = 0;
    integer transaction_count = 0;

    // =========================================================================
    // 2. DUT Instantiation
    // =========================================================================
    fftBramCtrl uut (
        .clk(clk),
        .rst_n(rst_n),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tlast(s_axis_tlast),
        .s_axis_tready(s_axis_tready),
        .bram_addr(bram_addr),
        .bram_din_re(bram_din_re),
        .bram_din_im(bram_din_im),
        .bram_we(bram_we),
        .bram_en(bram_en),
        .bram_rst(bram_rst)
    );

    // =========================================================================
    // 3. Clock Generation
    // =========================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // =========================================================================
    // 4. Scoreboard / FIFO Logic
    // =========================================================================
    // We need to store the sent 384-bit packets to compare against the
    // slower serial output. We use a simple circular buffer as a FIFO.

    reg [383:0] data_fifo [0:255]; // Store up to 256 pending packets
    integer fifo_write_ptr = 0;
    integer fifo_read_ptr = 0;
    integer fifo_count = 0;

    task push_fifo(input [383:0] data);
        begin
            data_fifo[fifo_write_ptr] = data;
            fifo_write_ptr = (fifo_write_ptr + 1) % 256;
            fifo_count = fifo_count + 1;
        end
    endtask

    // =========================================================================
    // 5. Main Stimulus Process (Driver)
    // =========================================================================
    initial begin
        // Init
        rst_n = 0;
        s_axis_tdata = 0;
        s_axis_tvalid = 0;
        s_axis_tlast = 0;

        $display("\n==================================================");
        $display("   STARTING SELF-CHECKING TESTBENCH");
        $display("==================================================\n");

        // Reset Sequence
        repeat(5) @(posedge clk);
        rst_n = 1;
        repeat(5) @(posedge clk);

        // --- STRESS TEST LOOP ---
        while (transaction_count < NUM_PACKETS) begin

            // 1. Randomize Data
            s_axis_tdata = {$random, $random, $random, $random,
                            $random, $random, $random, $random,
                            $random, $random, $random, $random};

            // 2. Drive AXI Stream
            s_axis_tvalid = 1;
            s_axis_tlast  = 1;

            // --- FIX STARTS HERE ---
            // Wait for handshake
            @(posedge clk);
            while (s_axis_tready == 0) begin
                @(posedge clk);
            end
            // --- FIX ENDS HERE ---

            // 3. Handshake occurred: Push to Scoreboard
            push_fifo(s_axis_tdata);
            transaction_count = transaction_count + 1;

            // 4. Randomize idle time
            s_axis_tvalid = 0;
            s_axis_tlast  = 0;

            if ($random % 2 == 0) begin
                repeat (($random % 5) + 1) @(posedge clk);
            end
        end

        // Wait for FIFO to empty (Monitor to finish)
        wait(fifo_count == 0);
        repeat(20) @(posedge clk); // Allow last writes to finish

        // --- FINAL REPORT ---
        $display("\n==================================================");
        if (error_count == 0) begin
            $display("   TEST PASSED: ALL CHECKS SUCCESSFUL");
            $display("   Packets Processed: %d", NUM_PACKETS);
            $display("   Total Writes Verified: %d", success_count);
        end else begin
            $display("   TEST FAILED");
            $display("   Errors Found: %d", error_count);
        end
        $display("==================================================\n");
        $finish;
    end

    // =========================================================================
    // 6. Monitor & Self-Check Process
    // =========================================================================

    // Shadow Address Counter to verify circular logic
    reg [12:0] expected_addr;

    // Internal variable to track which of the 8 slices we are checking
    integer slice_idx = 0;

    // Variables for comparison
    reg [383:0] current_golden_packet;
    reg [23:0]  raw_slice_re;
    reg [23:0]  raw_slice_im;
    reg [31:0]  exp_re;
    reg [31:0]  exp_im;

    initial begin
        expected_addr = -13'd4; // Match DUT initialization

        forever begin
            @(negedge clk); // Check on negative edge to ensure stability

            if (bram_we[0] == 1'b1) begin

                // 1. Get Golden Data
                if (slice_idx == 0) begin
                    // Retrieve the oldest packet from FIFO
                    current_golden_packet = data_fifo[fifo_read_ptr];
                end

                // 2. Calculate Expected Address
                // Simulate the -4 init and +4 increment of the DUT
                // Note: We perform the math using 13 bits to mimic overflow behavior
                expected_addr = expected_addr + 4;

                // 3. Check Address
                if (bram_addr[12:0] !== expected_addr) begin
                    $display("ERROR at time %t: Address Mismatch. Exp: %h, Got: %h",
                             $time, expected_addr, bram_addr);
                    error_count = error_count + 1;
                end

                // 4. Calculate Expected Data (Bit Slicing & Sign Ext)
                // Slice logic: [Index*48 +: 48]
                // Imag is upper 24, Real is lower 24
                raw_slice_im = current_golden_packet[(slice_idx*48 + 24) +: 24];
                raw_slice_re = current_golden_packet[(slice_idx*48 + 0)  +: 24];

                // Perform Sign Extension (Match DUT logic)
                exp_im = {{8{raw_slice_im[23]}}, raw_slice_im};
                exp_re = {{8{raw_slice_re[23]}}, raw_slice_re};

                // 5. Compare Data
                if (bram_din_re !== exp_re) begin
                    $display("ERROR at time %t: Real Data Mismatch (Packet %d, Slice %d). Exp: %h, Got: %h",
                             $time, fifo_read_ptr, slice_idx, exp_re, bram_din_re);
                    error_count = error_count + 1;
                end

                if (bram_din_im !== exp_im) begin
                    $display("ERROR at time %t: Imag Data Mismatch (Packet %d, Slice %d). Exp: %h, Got: %h",
                             $time, fifo_read_ptr, slice_idx, exp_im, bram_din_im);
                    error_count = error_count + 1;
                end

                // Track success
                success_count = success_count + 1;

                // 6. Index Management
                if (slice_idx == 7) begin
                    // Packet Done
                    slice_idx = 0;
                    fifo_read_ptr = (fifo_read_ptr + 1) % 256;
                    fifo_count = fifo_count - 1;
                end else begin
                    slice_idx = slice_idx + 1;
                end
            end
        end
    end

endmodule
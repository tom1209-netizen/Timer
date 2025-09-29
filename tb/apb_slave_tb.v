`timescale 1ns / 1ps

module apb_slave_tb;
    reg  sys_clk;
    reg  sys_rst_n;
    reg  tim_psel;
    reg  tim_pwrite;
    reg  tim_penable;
    reg  reg_error_flag;

    wire tim_pready;
    wire tim_pslverr;
    wire wr_en;
    wire rd_en;

    // Instantiate the Design Under Test (DUT)
    apb_slave dut (
        .sys_clk (sys_clk),
        .sys_rst_n (sys_rst_n),
        .tim_psel (tim_psel),
        .tim_pwrite (tim_pwrite),
        .tim_penable (tim_penable),
        .reg_error_flag (reg_error_flag),
        .tim_pready (tim_pready),
        .tim_pslverr (tim_pslverr),
        .wr_en (wr_en),
        .rd_en (rd_en)
    );

    // Clock Generator
    // Generate a 100MHz clock (10ns period)
    initial begin
        sys_clk = 0;
        forever #50 sys_clk = ~sys_clk;
    end

    // Test Sequence
    initial begin
        $display("------------------------------------");
        $display("--- Starting APB Slave Testbench ---");
        $display("------------------------------------");

        // --- Reset Sequence ---
        $display("Applying Reset...");
        tim_psel       <= 0;
        tim_pwrite     <= 0;
        tim_penable    <= 0;
        reg_error_flag <= 0;
        sys_rst_n      <= 0; // Assert active-low reset
        #25;
        sys_rst_n      <= 1; // De-assert reset
        $display("Reset Released.");
        #10;

        // --- SCENARIO 1: APB Write Transaction (Successful) ---
        $display("TEST 1: Starting APB Write Transaction...");
        // SETUP Phase
        @(posedge sys_clk);
        tim_psel   <= 1;
        tim_pwrite <= 1; // It's a write
        // ACCESS Phase
        @(posedge sys_clk);
        tim_penable <= 1;
        // Wait for transaction to complete (pready is high)
        @(posedge sys_clk);
        if (tim_pready === 1 && wr_en === 1) begin
            $display("PASS: Write transaction successful (pready and wr_en asserted).");
        end else begin
            $display("FAIL: Write transaction failed.");
        end
        // Return to IDLE
        tim_psel    <= 0;
        tim_penable <= 0;
        #20;

        // --- SCENARIO 2: APB Read Transaction (Successful) ---
        $display("TEST 2: Starting APB Read Transaction...");
        // SETUP Phase
        @(posedge sys_clk);
        tim_psel   <= 1;
        tim_pwrite <= 0; // It's a read
        // ACCESS Phase
        @(posedge sys_clk);
        tim_penable <= 1;
        // Wait for transaction to complete
        @(posedge sys_clk);
        if (tim_pready === 1 && rd_en === 1) begin
            $display("PASS: Read transaction successful (pready and rd_en asserted).");
        end else begin
            $display("FAIL: Read transaction failed.");
        end
        // Return to IDLE
        tim_psel    <= 0;
        tim_penable <= 0;
        #20;

        // --- SCENARIO 3: APB Write with Slave Error ---
        $display("TEST 3: Starting APB Write with Error...");
        @(posedge sys_clk);
        tim_psel       <= 1;
        tim_pwrite     <= 1;
        reg_error_flag <= 1; // Trigger an error
        @(posedge sys_clk);
        tim_penable    <= 1;
        @(posedge sys_clk);
        if (tim_pslverr === 1) begin
            $display("PASS: Slave error correctly asserted (pslverr is high).");
        end else begin
            $display("FAIL: Slave error not asserted.");
        end
        tim_psel       <= 0;
        tim_penable    <= 0;
        reg_error_flag <= 0;
        #20;

        // --- SCENARIO 4: Aborted Transaction ---
        $display("TEST 4: Starting Aborted Transaction...");
        @(posedge sys_clk);
        tim_psel <= 1; // Start a transaction
        @(posedge sys_clk);
        // Abort by de-selecting before penable goes high
        tim_psel <= 0;
        @(posedge sys_clk);
        if (tim_pready === 0) begin
             $display("PASS: Transaction correctly aborted (pready remained low).");
        end else begin
             $display("FAIL: Transaction was not aborted.");
        end
        #20;

        $display("--- All tests complete. Finishing simulation. ---");
        $finish;
    end

endmodule
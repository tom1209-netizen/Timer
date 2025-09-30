`timescale 1ns / 1ps

// Color Codes for Console Output
`define RED     "\033[1;31m"
`define GREEN   "\033[1;32m"
`define YELLOW  "\033[1;33m"
`define CYAN    "\033[1;36m"
`define RESET   "\033[0m"

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
    initial begin
        sys_clk = 0;
        forever #50 sys_clk = ~sys_clk;
    end

    // Test Sequence
    initial begin
        $display(`CYAN);
        $display("------------------------------------");
        $display("--- Starting APB Slave Testbench ---");
        $display("------------------------------------", `RESET);

        // --- Reset Sequence ---
        $display(`YELLOW, "Applying Reset...", `RESET);
        tim_psel <= 0;
        tim_pwrite <= 0;
        tim_penable <= 0;
        reg_error_flag <= 0;
        sys_rst_n <= 0;
        #25;
        sys_rst_n <= 1;
        $display(`GREEN, "Reset Released.", `RESET);
        #10;

        // --- SCENARIO 1: APB Write Transaction (Successful) ---
        $display(`CYAN, "TEST 1: Starting APB Write Transaction...", `RESET);
        // SETUP Phase
        @(posedge sys_clk);
        tim_psel <= 1;
        tim_pwrite <= 1; 

        // ACCESS Phase
        @(posedge sys_clk);
        tim_penable <= 1;

        // Wait
        @(posedge sys_clk); 
        @(posedge sys_clk);

        if (tim_pready === 1 && wr_en === 1)
            $display(`GREEN, "PASS: Write transaction successful (pready and wr_en asserted).", `RESET);
        else
            $display(`RED, "FAIL: Write transaction failed.", `RESET);

        // Return to IDLE
        tim_psel    <= 0;
        tim_penable <= 0;
        #20;

        // --- SCENARIO 2: APB Read Transaction (Successful) ---
        $display(`CYAN, "TEST 2: Starting APB Read Transaction...", `RESET);
        // SETUP Phase
        @(posedge sys_clk);
        tim_psel   <= 1;
        tim_pwrite <= 0; 

        // ACCESS Phase
        @(posedge sys_clk);
        tim_penable <= 1;

        // Wait
        @(posedge sys_clk); 
        @(posedge sys_clk);

        if (tim_pready === 1 && rd_en === 1)
            $display(`GREEN, "PASS: Read transaction successful (pready and rd_en asserted).", `RESET);
        else
            $display(`RED, "FAIL: Read transaction failed.", `RESET);

        tim_psel    <= 0;
        tim_penable <= 0;
        #20;

        // --- SCENARIO 3: APB Write with Slave Error ---
        $display(`CYAN, "TEST 3: Starting APB Write with Error...", `RESET);
        @(posedge sys_clk);
        tim_psel       <= 1;
        tim_pwrite     <= 1;
        reg_error_flag <= 1; 

        @(posedge sys_clk);
        tim_penable    <= 1;

        @(posedge sys_clk);
        @(posedge sys_clk);

        if (tim_pslverr === 1)
            $display(`GREEN, "PASS: Slave error correctly asserted (pslverr is high).", `RESET);
        else
            $display(`RED, "FAIL: Slave error not asserted.", `RESET);

        tim_psel       <= 0;
        tim_penable    <= 0;
        reg_error_flag <= 0;
        #20;

        // --- SCENARIO 4: Aborted Transaction ---
        $display(`CYAN, "TEST 4: Starting Aborted Transaction...", `RESET);
        @(posedge sys_clk);
        tim_psel <= 1;

        @(posedge sys_clk);
        tim_psel <= 0; // Abort

        @(posedge sys_clk);

        if (tim_pready === 0)
            $display(`GREEN, "PASS: Transaction correctly aborted (pready remained low).", `RESET);
        else
            $display(`RED, "FAIL: Transaction was not aborted.", `RESET);

        $display(`CYAN, "--- All tests complete. Finishing simulation. ---", `RESET);
        $finish;
    end

endmodule

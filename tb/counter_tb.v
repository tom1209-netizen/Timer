`timescale 1ns / 1ps

// Color Codes for Console Output
`define RED     "\033[1;31m"
`define GREEN   "\033[1;32m"
`define YELLOW  "\033[1;33m"
`define CYAN    "\033[1;36m"
`define RESET   "\033[0m"

module counter_tb;
    // --- Testbench Signals ---
    reg  sys_clk;
    reg  sys_rst_n;

    // Inputs to the DUT
    reg  cnt_en;
    reg  counter_clear;
    reg  [31:0] counter_write_data;
    reg  [1:0]  counter_write_sel;

    // Outputs from the DUT
    wire [63:0] cnt_val;

    // Test bench variables
    reg [63:0] expected_val;

    // --- Instantiate the Design Under Test (DUT) ---
    counter dut (
        .sys_clk(sys_clk),
        .sys_rst_n(sys_rst_n),
        .cnt_en(cnt_en),
        .counter_clear(counter_clear),
        .counter_write_data(counter_write_data),
        .counter_write_sel(counter_write_sel),
        .cnt_val(cnt_val)
    );
    
    // --- Clock Generator ---
    initial begin
        sys_clk = 0;
        forever #50 sys_clk = ~sys_clk; // 100ns period clock
    end

    // --- Test Sequence ---
    initial begin
        $display(`CYAN);
        $display("----------------------------------");
        $display("--- Starting Counter Testbench ---");
        $display("----------------------------------", `RESET);

        // --- Reset Sequence ---
        $display(`YELLOW, "Applying Reset...", `RESET);
        cnt_en             <= 0;
        counter_clear      <= 0;
        counter_write_data <= 32'h0;
        counter_write_sel  <= 2'b00;
        sys_rst_n          <= 0;
        #25;
        sys_rst_n          <= 1;
        @(posedge sys_clk); // Wait for first clock edge after reset release
        if (cnt_val === 64'd0)
            $display(`GREEN, "PASS: Counter correctly reset to 0.", `RESET);
        else
            $display(`RED, "FAIL: Counter did not reset to 0. Value: %h", cnt_val, `RESET);
        #10;

        // --- SCENARIO 1: Basic Increment (cnt_en) ---
        $display(`CYAN, "TEST 1: Verifying basic increment...", `RESET);
        cnt_en <= 1;
        repeat (5) @(posedge sys_clk); // Let it count for 5 cycles
        cnt_en <= 0;
        @(posedge sys_clk); // Let the last value settle
        
        if (cnt_val === 64'd5)
            $display(`GREEN, "PASS: Counter correctly incremented to 5.", `RESET);
        else
            $display(`RED, "FAIL: Expected counter value 5, got %d.", cnt_val, `RESET);
        #20;

        // --- SCENARIO 2: Synchronous Clear ---
        $display(`CYAN, "TEST 2: Verifying synchronous clear...", `RESET);
        // At this point, counter value is 5.
        counter_clear <= 1;
        @(posedge sys_clk); // Apply the clear
        counter_clear <= 0;
        @(posedge sys_clk); 
        
        if (cnt_val === 64'd0)
            $display(`GREEN, "PASS: Counter correctly cleared by counter_clear.", `RESET);
        else
            $display(`RED, "FAIL: Expected counter value 0 after clear, got %d.", cnt_val, `RESET);
        #20;

        // --- SCENARIO 3: Direct Write (Lower and Upper) ---
        $display(`CYAN, "TEST 3: Verifying direct writes...", `RESET);
        // Write lower half
        counter_write_data <= 32'hDEADBEEF;
        counter_write_sel  <= 2'b01;
        @(posedge sys_clk);
        counter_write_sel  <= 2'b00;
        @(posedge sys_clk);
        
        // Write upper half
        counter_write_data <= 32'hAAAABBBB;
        counter_write_sel  <= 2'b10;
        @(posedge sys_clk);
        counter_write_sel  <= 2'b00;
        @(posedge sys_clk);
        
        expected_val = 64'hAAAABBBBDEADBEEF;
        if (cnt_val === expected_val)
            $display(`GREEN, "PASS: Counter correctly updated by direct writes.", `RESET);
        else
            $display(`RED, "FAIL: Expected %h after writes, got %h.", expected_val, cnt_val, `RESET);
        #20;

        // --- SCENARIO 4: Write Priority Over Increment ---
        $display(`CYAN, "TEST 4: Verifying write has priority over increment...", `RESET);
        // Current value is 64'hAAAABBBBDEEDBEEF
        
        // Enable increment AND a write in the same cycle
        cnt_en             <= 1;
        counter_write_data <= 32'h12345678;
        counter_write_sel  <= 2'b01;
        @(posedge sys_clk);
        cnt_en             <= 0;
        counter_write_sel  <= 2'b00;
        @(posedge sys_clk);

        // Expected result: the write happens, the increment is ignored for that cycle.
        expected_val = 64'hAAAABBBB12345678; 
        if (cnt_val === expected_val)
            $display(`GREEN, "PASS: Write correctly took priority over increment.", `RESET);
        else
            $display(`RED, "FAIL: Priority failed. Expected %h, got %h.", expected_val, cnt_val, `RESET);

        // Check that the next increment works correctly from the new value
        cnt_en <= 1;
        @(posedge sys_clk);
        cnt_en <= 0;
        @(posedge sys_clk);
        
        expected_val = 64'hAAAABBBB12345679;
        if (cnt_val === expected_val)
            $display(`GREEN, "PASS: Increment works correctly after a prioritized write.", `RESET);
        else
            $display(`RED, "FAIL: Increment failed after write. Expected %h, got %h.", expected_val, cnt_val, `RESET);
        #20;

        $display(`CYAN, "--- All tests complete. Finishing simulation. ---", `RESET);
        $finish;
    end

endmodule
`timescale 1ns / 1ps

// Color Codes for Console Output
`define RED     "\033[1;31m"
`define GREEN   "\033[1;32m"
`define YELLOW  "\033[1;33m"
`define CYAN    "\033[1;36m"
`define RESET   "\033[0m"

module interrupt_tb;
    // --- Testbench Signals ---
    reg  sys_clk;
    reg  sys_rst_n;

    // Inputs to the DUT
    reg  [63:0] cnt_val;
    reg  [63:0] compare_val;
    reg  interrupt_en;
    reg  interrupt_pending_clear;

    // Outputs from the DUT
    wire interrupt_status;
    wire tim_int;

    // DUT
    interrupt dut (
        .sys_clk(sys_clk),
        .sys_rst_n(sys_rst_n),
        .cnt_val(cnt_val),
        .compare_val(compare_val),
        .interrupt_en(interrupt_en),
        .interrupt_pending_clear(interrupt_pending_clear),
        .interrupt_status(interrupt_status),
        .tim_int(tim_int)
    );

    // --- Clock Generator ---
    initial begin
        sys_clk = 0;
        forever #50 sys_clk = ~sys_clk; // 100ns period clock
    end

    // --- Test Sequence ---
    initial begin
        $display(`CYAN);
        $display("---------------------------------------");
        $display("--- Starting Interrupt Logic Testbench ---");
        $display("---------------------------------------", `RESET);

        // --- Reset Sequence ---
        $display(`YELLOW, "Applying Reset...", `RESET);
        cnt_val <= 64'd0;
        compare_val <= 64'd5; // Set a compare value for the test
        interrupt_en <= 0;
        interrupt_pending_clear <= 0;
        sys_rst_n <= 0;
        #25;
        sys_rst_n <= 1;
        $display(`GREEN, "Reset Released.", `RESET);
        #10;

        // --- SCENARIO 1: Interrupt Trigger and Sticky Behavior ---
        $display(`CYAN, "TEST 1: Triggering interrupt and verifying sticky behavior...", `RESET);
        
        // Enable the interrupt output
        interrupt_en <= 1;

        // Increment counter up to the match value
        repeat (5) @(posedge sys_clk) cnt_val <= cnt_val + 1;

        @(posedge sys_clk); // Cycle where cnt_val == 5 (match condition is true)
        
        // On the NEXT clock edge, the status should be set
        @(posedge sys_clk);
        if (interrupt_status === 1'b1 && tim_int === 1'b1) begin
            $display(`GREEN, "PASS: Interrupt status and output correctly SET on match.", `RESET);
        end else begin
            $display(`RED, "FAIL: Interrupt did not set on match. Status=%b, tim_int=%b", interrupt_status, tim_int, `RESET);
        end

        // Now, increment the counter PAST the match value
        cnt_val <= cnt_val + 1;
        @(posedge sys_clk);
        
        // The interrupt status MUST remain high (sticky behavior)
        if (interrupt_status === 1'b1 && tim_int === 1'b1) begin
            $display(`GREEN, "PASS: Interrupt status correctly REMAINED HIGH (sticky).", `RESET);
        end else begin
            $display(`RED, "FAIL: Interrupt status did not remain high. Status=%b, tim_int=%b", interrupt_status, tim_int, `RESET);
        end
        #20;

        // --- SCENARIO 2: Clearing the Interrupt ---
        $display(`CYAN, "TEST 2: Clearing the interrupt...", `RESET);

        // Assert the clear signal for one cycle
        @(posedge sys_clk);
        interrupt_pending_clear <= 1'b1;
        @(posedge sys_clk);
        interrupt_pending_clear <= 1'b0;
        @(posedge sys_clk);

        // The interrupt status and output should now be low
        if (interrupt_status === 1'b0 && tim_int === 1'b0) begin
            $display(`GREEN, "PASS: Interrupt status and output correctly CLEARED.", `RESET);
        end else begin
            $display(`RED, "FAIL: Interrupt did not clear. Status=%b, tim_int=%b", interrupt_status, tim_int, `RESET);
        end
        #20;
        
        // --- SCENARIO 3: Interrupt Masking ---
        $display(`CYAN, "TEST 3: Verifying interrupt masking (interrupt_en = 0)...", `RESET);

        // Increment counter to match again, but with interrupt_en = 0
        interrupt_en <= 0;
        cnt_val <= 4; // Set up for the next match

        @(posedge sys_clk) cnt_val <= cnt_val + 1; // cnt_val is now 5
        @(posedge sys_clk); // Let the match happen
        @(posedge sys_clk); // Let the status register update

        if (interrupt_status === 1'b1 && tim_int === 1'b0) begin
            $display(`GREEN, "PASS: Interrupt was correctly masked. Status is high, but tim_int is low.", `RESET);
        end else begin
            $display(`RED, "FAIL: Interrupt masking failed. Status=%b, tim_int=%b", interrupt_status, tim_int, `RESET);
        end
        
        // Don't forget to clear the pending status for the next test
        @(posedge sys_clk) interrupt_pending_clear <= 1;
        @(posedge sys_clk) interrupt_pending_clear <= 0;
        #20;

        $display(`CYAN, "--- All tests complete. Finishing simulation. ---", `RESET);
        $finish;
    end

endmodule
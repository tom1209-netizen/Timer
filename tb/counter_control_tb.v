`timescale 1ns / 1ps

// Color Codes for Console Output
`define RED     "\033[1;31m"
`define GREEN   "\033[1;32m"
`define YELLOW  "\033[1;33m"
`define CYAN    "\033[1;36m"
`define RESET   "\033[0m"

module counter_control_tb;

    // --- Testbench Signals ---
    reg  sys_clk;
    reg  sys_rst_n;

    // Inputs to the DUT
    reg  timer_en;
    reg  div_en;
    reg  [3:0] div_val;
    reg  halt_req;
    reg  dbg_mode;

    // Outputs from the DUT
    wire cnt_en;
    wire halt_ack_status;

    // Test variables
    integer pulse_count;
    integer i;

    // --- Instantiate the Design Under Test (DUT) ---
    counter_control dut (
        .sys_clk(sys_clk),
        .sys_rst_n(sys_rst_n),
        .timer_en(timer_en),
        .div_en(div_en),
        .div_val(div_val),
        .halt_req(halt_req),
        .dbg_mode(dbg_mode),
        .cnt_en(cnt_en),
        .halt_ack_status(halt_ack_status)
    );
    
    // --- Clock Generator ---
    initial begin
        sys_clk = 0;
        forever #50 sys_clk = ~sys_clk; // 100ns period clock
    end

    // --- Test Sequence ---
    initial begin
        $display(`CYAN);
        $display("-------------------------------------------");
        $display("--- Starting Counter Control Testbench ---");
        $display("-------------------------------------------", `RESET);

        // --- Reset Sequence ---
        $display(`YELLOW, "Applying Reset...", `RESET);
        timer_en <= 0;
        div_en   <= 0;
        div_val  <= 4'd0;
        halt_req <= 0;
        dbg_mode <= 0;
        sys_rst_n <= 0;
        #25;
        sys_rst_n <= 1;
        $display(`GREEN, "Reset Released.", `RESET);
        #10;

        // --- SCENARIO 1: Default Mode (div_en = 0) ---
        $display(`CYAN, "TEST 1: Verifying Default Mode (div_en = 0)...", `RESET);
        timer_en <= 1;
        div_en   <= 0;

        @(posedge sys_clk);
        @(posedge sys_clk);

        if (cnt_en === 1'b1)
            $display(`GREEN, "PASS: cnt_en is high when timer_en is high.", `RESET);
        else
            $display(`RED, "FAIL: cnt_en should be high when timer_en is high.", `RESET);

        timer_en <= 0;
        @(posedge sys_clk);
        if (cnt_en === 1'b0)
            $display(`GREEN, "PASS: cnt_en is low when timer_en is low.", `RESET);
        else
            $display(`RED, "FAIL: cnt_en should be low when timer_en is low.", `RESET);
        #20;

        // --- SCENARIO 2: Control Mode (div_en = 1, div_val = 2 -> div/4) ---
        $display(`CYAN, "TEST 2: Verifying Control Mode (div/4)...", `RESET);
        timer_en <= 1;
        div_en   <= 1;
        div_val  <= 4'd2; // Divide by 4 (counts 0, 1, 2, 3)

        pulse_count = 0; // Initialize before use
        @(posedge sys_clk); // Let settings settle
        
        // Wait for 10 cycles and count the pulses on cnt_en
        for (i = 0; i < 10; i = i + 1) begin
            @(posedge sys_clk);
            if (cnt_en) pulse_count = pulse_count + 1;
        end
        
        if (pulse_count == 2)
            $display(`GREEN, "PASS: Correct number of cnt_en pulses observed (2 pulses in 10 cycles for div/4).", `RESET);
        else
            $display(`RED, "FAIL: Incorrect number of pulses. Expected 2, got %0d.", pulse_count, `RESET);
        #20;

        // --- SCENARIO 3: Halt Behavior ---
        $display(`CYAN, "TEST 3: Verifying Halt functionality...", `RESET);
        timer_en <= 1;
        div_en   <= 1;
        div_val  <= 4'd2;
        
        halt_req <= 1;
        dbg_mode <= 1;
        
        @(posedge sys_clk);
        
        if (halt_ack_status === 1'b1)
            $display(`GREEN, "PASS: halt_ack_status correctly asserted.", `RESET);
        else
            $display(`RED, "FAIL: halt_ack_status was not asserted.", `RESET);

        pulse_count = 0;
        for (i = 0; i < 10; i = i + 1) begin
            @(posedge sys_clk);
            if (cnt_en) pulse_count = pulse_count + 1;
        end
        
        if (pulse_count == 0)
            $display(`GREEN, "PASS: cnt_en was correctly suppressed during halt.", `RESET);
        else
            $display(`RED, "FAIL: cnt_en was not suppressed during halt. Saw %0d pulses.", pulse_count, `RESET);

        halt_req <= 0;
        dbg_mode <= 0;
        pulse_count = 0; // Re-initialize before next loop
        @(posedge sys_clk); 
        for (i = 0; i < 10; i = i + 1) begin
            @(posedge sys_clk);
            if (cnt_en) pulse_count = pulse_count + 1;
        end

        if (pulse_count > 0)
            $display(`GREEN, "PASS: cnt_en correctly resumed after halt was de-asserted.", `RESET);
        else
            $display(`RED, "FAIL: cnt_en did not resume after halt.", `RESET);
        #20;

        // --- SCENARIO 4: Reset of Internal Divisor Counter ---
        $display(`CYAN, "TEST 4: Verifying reset of internal counter...", `RESET);
        timer_en <= 1;
        div_en   <= 1;
        div_val  <= 4'd2;
        @(posedge sys_clk); 
        @(posedge sys_clk); 
        @(posedge sys_clk); 
        
        timer_en <= 0;
        @(posedge sys_clk);
        
        timer_en <= 1;
        pulse_count = 0;
        for (i = 0; i < 10; i = i + 1) begin
            @(posedge sys_clk);
            if (cnt_en) pulse_count = pulse_count + 1;
        end

        if (pulse_count == 2)
            $display(`GREEN, "PASS: Internal divisor counter appears to reset correctly.", `RESET);
        else
            $display(`RED, "FAIL: Internal divisor counter did not reset correctly. Saw %0d pulses.", pulse_count, `RESET);
        #20;

        $display(`CYAN, "--- All tests complete. Finishing simulation. ---", `RESET);
        $finish;
    end

endmodule
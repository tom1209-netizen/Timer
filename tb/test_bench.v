`timescale 1ns / 1ps

// Color Codes for Console Output
`define RED     "\033[1;31m"
`define GREEN   "\033[1;32m"
`define YELLOW  "\033[1;33m"
`define CYAN    "\033[1;36m"
`define RESET   "\033[0m"

module test_bench;

    // --- Testbench Signals ---
    // Inputs to DUT
    reg  sys_clk;
    reg  sys_rst_n;
    reg  tim_psel;
    reg  tim_pwrite;
    reg  tim_penable;
    reg  [11:0] tim_paddr;
    reg  [31:0] tim_pwdata;
    reg  [3:0]  tim_pstrb;
    reg  dbg_mode;

    // Outputs from DUT
    wire [31:0] tim_prdata;
    wire tim_pready;
    wire tim_pslverr;
    wire tim_int;

    // --- Register Address Map ---
    localparam TCR_ADDR   = 12'h000;
    localparam TDR0_ADDR  = 12'h004;
    localparam TDR1_ADDR  = 12'h008;
    localparam TCMP0_ADDR = 12'h00C;
    localparam TCMP1_ADDR = 12'h010;
    localparam TIER_ADDR  = 12'h014;
    localparam TISR_ADDR  = 12'h018;
    localparam THCSR_ADDR = 12'h01C;
    localparam INVALID_ADDR = 12'hFFE;

    reg [31:0] tcr, tcmp0, tcmp1, tier, thcsr, data, before, after, count, tdr0, tdr1;
    reg [31:0] c1, c2, c3;

    // --- Instantiate the Design Under Test (DUT) ---
    timer_top dut (
        .sys_clk(sys_clk),
        .sys_rst_n(sys_rst_n),
        .tim_psel(tim_psel),
        .tim_pwrite(tim_pwrite),
        .tim_penable(tim_penable),
        .tim_paddr(tim_paddr),
        .tim_pwdata(tim_pwdata),
        .tim_pstrb(tim_pstrb),
        .dbg_mode(dbg_mode),
        .tim_prdata(tim_prdata),
        .tim_pready(tim_pready),
        .tim_pslverr(tim_pslverr),
        .tim_int(tim_int)
    );

    // --- Clock Generator ---
    initial begin
        sys_clk = 0;
        forever #50 sys_clk = ~sys_clk; // 100ns period
    end

    // --- Testbench Helper Tasks ---
    task do_write;
        input [11:0] addr;
        input [31:0] data;
        input [3:0]  strb;
        begin
            @(posedge sys_clk);
            tim_psel <= 1'b1; tim_pwrite <= 1'b1; tim_penable <= 1'b0;
            tim_paddr <= addr; tim_pwdata <= data; tim_pstrb <= strb;
            @(posedge sys_clk);
            tim_penable <= 1'b1;
            while (tim_pready === 1'b0) @(posedge sys_clk);
            @(posedge sys_clk);
            tim_psel <= 1'b0; tim_penable <= 1'b0;
        end
    endtask

    task do_read;
        input [11:0] addr;
        output [31:0] captured_data;
        begin
            @(posedge sys_clk);
            tim_psel <= 1'b1; tim_pwrite <= 1'b0; tim_penable <= 1'b0;
            tim_paddr <= addr;
            @(posedge sys_clk);
            tim_penable <= 1'b1;
            while (tim_pready === 1'b0) @(posedge sys_clk);
            captured_data = tim_prdata;
            @(posedge sys_clk);
            tim_psel <= 1'b0; tim_penable <= 1'b0;
        end
    endtask

    task wait_cycles;
        input integer num_cycles;
        integer i;
        begin
            for(i=0; i<num_cycles; i=i+1) @(posedge sys_clk);
        end
    endtask
    
    task set_dbg_mode;
        input val;
        begin
            dbg_mode <= val;
        end
    endtask

    // --- Main Test Sequence ---
    initial begin
        $display(`CYAN, "--- Starting Timer Top Full Verification ---", `RESET);

        // // --- Reset Sequence ---
        // tim_psel <= 0; tim_pwrite <= 0; tim_penable <= 0; tim_paddr <= 0; 
        // tim_pwdata <= 0; tim_pstrb <= 0; dbg_mode <= 0;
        // sys_rst_n <= 0; #25; sys_rst_n <= 1;
        // $display(`GREEN, "System Reset Applied and Released.", `RESET); #10;
        
        // // --- TEST: RESET_DEFAULTS ---
        // $display(`CYAN, "TEST: RESET_DEFAULTS...", `RESET);
        // do_read(TCR_ADDR, tcr); do_read(TCMP0_ADDR, tcmp0); do_read(TCMP1_ADDR, tcmp1); 
        // do_read(TIER_ADDR, tier); do_read(THCSR_ADDR, thcsr);
        // if (tcr === 32'h00000100 && tcmp0 === 32'hFFFFFFFF && tcmp1 === 32'hFFFFFFFF && tier === 32'h0 && thcsr === 32'h0)
        //     $display(`GREEN, "PASS: All registers reset to correct default values.", `RESET);
        // else 
        //     $display(`RED, "FAIL: Register default values incorrect.", `RESET);
        
        // // --- TEST: RW_ACCESS_TCMP ---
        // $display(`CYAN, "TEST: RW_ACCESS_TCMP...", `RESET);
        // do_write(TCMP0_ADDR, 32'hDEADBEEF, 4'hF); do_read(TCMP0_ADDR, data);
        // if (data === 32'hDEADBEEF) $display(`GREEN, "PASS: RW_ACCESS_TCMP successful.", `RESET);
        // else $display(`RED, "FAIL: RW_ACCESS_TCMP failed.", `RESET);
        
        // // --- TEST: BYTE_ACCESS_TCR ---
        // $display(`CYAN, "TEST: BYTE_ACCESS_TCR...", `RESET);
        // do_read(TCR_ADDR, before); do_write(TCR_ADDR, 32'hxxxx05xx, 4'b0010); do_read(TCR_ADDR, after);
        // if (after[11:8] === 4'h5 && after[7:0] === before[7:0] && after[31:12] === before[31:12])
        //     $display(`GREEN, "PASS: BYTE_ACCESS_TCR successful.", `RESET);
        // else $display(`RED, "FAIL: BYTE_ACCESS_TCR failed.", `RESET);

        // // --- TEST: RO_READ_TDR ---
        // $display(`CYAN, "TEST: RO_READ_TDR...", `RESET);
        // do_write(TDR1_ADDR, 32'hAAAABBBB, 4'hF); do_write(TDR0_ADDR, 32'h12345678, 4'hF);
        // do_read(TDR0_ADDR, tdr0); do_read(TDR1_ADDR, tdr1);
        // if (tdr0 === 32'h12345678 && tdr1 === 32'hAAAABBBB) $display(`GREEN, "PASS: RO_READ_TDR successful.", `RESET);
        // else $display(`RED, "FAIL: RO_READ_TDR failed.", `RESET);

        // --- TEST: COUNT_DEFAULT_MODE ---
        $display(`CYAN, "TEST: COUNT_DEFAULT_MODE...", `RESET);
        do_write(TCR_ADDR, 32'h0, 4'h1); wait_cycles(10); do_read(TDR0_ADDR, count);
        if (count === 10) $display(`GREEN, "PASS: COUNT_DEFAULT_MODE successful.", `RESET);
        else $display(`RED, "FAIL: COUNT_DEFAULT_MODE failed. Expected 10, got %d", count, `RESET);
        
        // // --- TEST: COUNT_DIV_MODE ---
        // $display(`CYAN, "TEST: COUNT_DIV_MODE...", `RESET);
        // do_write(TCR_ADDR, 32'h3, 4'h1); wait_cycles(10); do_read(TDR0_ADDR, count);
        // if (count === 5) $display(`GREEN, "PASS: COUNT_DIV_MODE successful.", `RESET);
        // else $display(`RED, "FAIL: COUNT_DIV_MODE failed. Expected 5, got %d", count, `RESET);

        // // --- TEST: COUNT_CLEAR_ON_DISABLE ---
        // $display(`CYAN, "TEST: COUNT_CLEAR_ON_DISABLE...", `RESET);
        // do_write(TCR_ADDR, 32'h1, 4'h1); wait_cycles(5); do_write(TCR_ADDR, 32'h0, 4'h1); do_read(TDR0_ADDR, count);
        // if (count === 0) $display(`GREEN, "PASS: COUNT_CLEAR_ON_DISABLE successful.", `RESET);
        // else $display(`RED, "FAIL: COUNT_CLEAR_ON_DISABLE failed.", `RESET);

        // // --- TEST: COUNT_DIRECT_WRITE ---
        // $display(`CYAN, "TEST: COUNT_DIRECT_WRITE...", `RESET);
        // do_write(TCR_ADDR, 0, 4'h1); do_write(TDR0_ADDR, 32'hC0DECAFE, 4'hF); do_read(TDR0_ADDR, count);
        // if (count === 32'hC0DECAFE) $display(`GREEN, "PASS: COUNT_DIRECT_WRITE successful.", `RESET);
        // else $display(`RED, "FAIL: COUNT_DIRECT_WRITE failed.", `RESET);

        // // --- TEST: INTERRUPT_TRIGGER_STICKY & INTERRUPT_CLEAR & INTERRUPT_MASK ---
        // $display(`CYAN, "TEST: INTERRUPT_TRIGGER_STICKY...", `RESET);
        // do_write(TCR_ADDR, 0, 4'h1); do_write(TDR0_ADDR, 9, 4'hF); do_write(TCMP0_ADDR, 10, 4'hF); 
        // do_write(TIER_ADDR, 1, 4'h1); do_write(TCR_ADDR, 1, 4'h1); wait_cycles(2);
        // if (tim_int === 1) $display(`GREEN, "PASS: INTERRUPT triggered.", `RESET);
        // else $display(`RED, "FAIL: INTERRUPT did not trigger.", `RESET);
        // wait_cycles(1); do_read(TISR_ADDR, data);
        // if (data[0] === 1) $display(`GREEN, "PASS: INTERRUPT status is sticky.", `RESET);
        // else $display(`RED, "FAIL: INTERRUPT status is not sticky.", `RESET);

        // $display(`CYAN, "TEST: INTERRUPT_MASK...", `RESET);
        // do_write(TIER_ADDR, 0, 4'h1); #1;
        // do_read(TISR_ADDR, data);
        // if (tim_int === 0 && data[0] === 1) $display(`GREEN, "PASS: INTERRUPT_MASK successful.", `RESET);
        // else $display(`RED, "FAIL: INTERRUPT_MASK failed.", `RESET);
        
        // $display(`CYAN, "TEST: INTERRUPT_CLEAR...", `RESET);
        // do_write(TISR_ADDR, 1, 4'h1); do_read(TISR_ADDR, data);
        // if (data[0] === 0 && tim_int === 0) $display(`GREEN, "PASS: INTERRUPT_CLEAR successful.", `RESET);
        // else $display(`RED, "FAIL: INTERRUPT_CLEAR failed.", `RESET);

        // // --- TEST: HALT_BASIC & HALT_RESUME & HALT_NEGATIVE ---
        // $display(`CYAN, "TEST: HALT_BASIC...", `RESET);
        // do_write(TCR_ADDR, 1, 4'h1); wait_cycles(5); set_dbg_mode(1); do_write(THCSR_ADDR, 1, 4'h1);
        // do_read(TDR0_ADDR, c1); wait_cycles(10); do_read(TDR0_ADDR, c2); do_read(THCSR_ADDR, data);
        // if (data[1] === 1 && c1 === c2) $display(`GREEN, "PASS: HALT_BASIC successful.", `RESET);
        // else $display(`RED, "FAIL: HALT_BASIC failed.", `RESET);

        // $display(`CYAN, "TEST: HALT_RESUME...", `RESET);
        // do_write(THCSR_ADDR, 0, 4'h1); wait_cycles(10); do_read(TDR0_ADDR, c3); do_read(THCSR_ADDR, data);
        // if (data[1] === 0 && c3 > c2) $display(`GREEN, "PASS: HALT_RESUME successful.", `RESET);
        // else $display(`RED, "FAIL: HALT_RESUME failed.", `RESET);

        // $display(`CYAN, "TEST: HALT_NEGATIVE...", `RESET);
        // set_dbg_mode(0); do_write(THCSR_ADDR, 1, 4'h1); do_read(TDR0_ADDR, c1); wait_cycles(10); do_read(TDR0_ADDR, c2);
        // if (c2 > c1) $display(`GREEN, "PASS: HALT_NEGATIVE successful (dbg_mode=0).", `RESET);
        // else $display(`RED, "FAIL: HALT_NEGATIVE failed (dbg_mode=0).", `RESET);
        // do_write(THCSR_ADDR, 0, 4'h1); // clean up

        // // --- TEST: ERROR_FLAG_TIMER_RUNNING & ERROR_FLAG_PROHIBITED_VAL ---
        // $display(`CYAN, "TEST: ERROR_FLAG_TIMER_RUNNING...", `RESET);
        // do_write(TCR_ADDR, 1, 4'h1); do_read(TCR_ADDR, before);
        // // Manual transaction to check pslverr
        // @(posedge sys_clk);
        // tim_psel <= 1; tim_pwrite <= 1; tim_penable <= 0; tim_paddr <= TCR_ADDR; tim_pwdata <= 32'h501; tim_pstrb <= 4'hF;
        // @(posedge sys_clk);
        // tim_penable <= 1;
        // while (tim_pready === 1'b0) @(posedge sys_clk);
        // if (tim_pslverr === 1) $display(`GREEN, "PASS: pslverr asserted.", `RESET);
        // else $display(`RED, "FAIL: pslverr not asserted.", `RESET);
        // @(posedge sys_clk);
        // tim_psel <= 0; tim_penable <= 0;
        // do_read(TCR_ADDR, after);
        // if (after === before) $display(`GREEN, "PASS: Register unchanged after error.", `RESET);
        // else $display(`RED, "FAIL: Register changed after error.", `RESET);

        // $display(`CYAN, "TEST: ERROR_FLAG_PROHIBITED_VAL...", `RESET);
        // do_write(TCR_ADDR, 0, 4'h1); do_read(TCR_ADDR, before);
        // do_write(TCR_ADDR, 32'h0F00, 4'hF); // illegal div_val = 0xF
        // // Assuming the do_write completes and we can check the slave's previous error state
        // #1; // Wait for combinational logic
        // if (tim_pslverr) $display(`GREEN, "PASS: pslverr asserted on prohibited value write.", `RESET);
        // else $display(`RED, "FAIL: pslverr not asserted on prohibited value write.", `RESET);
        // do_read(TCR_ADDR, after);
        // if (after === before) $display(`GREEN, "PASS: Register unchanged after error.", `RESET);
        // else $display(`RED, "FAIL: Register changed after error.", `RESET);
        
        // // --- TEST: INVALID_ADDR_READ & INVALID_ADDR_WRITE ---
        // $display(`CYAN, "TEST: INVALID_ADDR_READ...", `RESET);
        // do_read(INVALID_ADDR, data);
        // if (data === 32'h0) $display(`GREEN, "PASS: INVALID_ADDR_READ successful.", `RESET);
        // else $display(`RED, "FAIL: INVALID_ADDR_READ failed.", `RESET);
        
        // $display(`CYAN, "TEST: INVALID_ADDR_WRITE...", `RESET);
        // do_read(TCR_ADDR, before); do_write(INVALID_ADDR, 32'hFFFFFFFF, 4'hF); do_read(TCR_ADDR, after);
        // if (after === before) $display(`GREEN, "PASS: INVALID_ADDR_WRITE successful.", `RESET);
        // else $display(`RED, "FAIL: INVALID_ADDR_WRITE failed.", `RESET);

        $display(`CYAN, "\n--- All tests complete. Finishing simulation. ---", `RESET);
        $finish;
    end

endmodule
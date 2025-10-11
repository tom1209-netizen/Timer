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
    reg         sys_clk;
    reg         sys_rst_n;
    reg         tim_psel;
    reg         tim_pwrite;
    reg         tim_penable;
    reg  [11:0] tim_paddr;
    reg  [31:0] tim_pwdata;
    reg  [3:0]  tim_pstrb;
    reg         dbg_mode;

    // Outputs from DUT
    wire [31:0] tim_prdata;
    wire        tim_pready;
    wire        tim_pslverr;
    wire        tim_int;

    // --- Register Address Map ---
    localparam TCR_ADDR      = 12'h000;
    localparam TDR0_ADDR     = 12'h004;
    localparam TDR1_ADDR     = 12'h008;
    localparam TCMP0_ADDR    = 12'h00C;
    localparam TCMP1_ADDR    = 12'h010;
    localparam TIER_ADDR     = 12'h014;
    localparam TISR_ADDR     = 12'h018;
    localparam THCSR_ADDR    = 12'h01C;
    localparam INVALID_ADDR  = 12'hFFE;

    reg [31:0] tcr;
    reg [31:0] tcmp0;
    reg [31:0] tcmp1;
    reg [31:0] tier;
    reg [31:0] thcsr;
    reg [31:0] data;
    reg [31:0] before;
    reg [31:0] after;
    reg [31:0] count;
    reg [31:0] tdr0;
    reg [31:0] tdr1;

    reg [31:0] c1;
    reg [31:0] c2;
    reg [31:0] c3;
    reg [31:0] c4;

    reg toggle_test_passed;

    // --- Instantiate the Design Under Test (DUT) ---
    timer_top dut (
        .sys_clk     (sys_clk),
        .sys_rst_n   (sys_rst_n),
        .tim_psel    (tim_psel),
        .tim_pwrite  (tim_pwrite),
        .tim_penable (tim_penable),
        .tim_paddr   (tim_paddr),
        .tim_pwdata  (tim_pwdata),
        .tim_pstrb   (tim_pstrb),
        .dbg_mode    (dbg_mode),
        .tim_prdata  (tim_prdata),
        .tim_pready  (tim_pready),
        .tim_pslverr (tim_pslverr),
        .tim_int     (tim_int)
    );

    // --- Clock Generator ---
    initial begin
        sys_clk = 1'b0;
        forever #50 sys_clk = ~sys_clk; // 100ns period
    end

    // --- Testbench Helper Tasks ---
    task do_write;
        input [11:0] addr;
        input [31:0] data;
        input [3:0]  strb;
        begin
            @(posedge sys_clk);

            tim_psel    <= 1'b1;
            tim_pwrite  <= 1'b1;
            tim_penable <= 1'b0;

            tim_paddr   <= addr;
            tim_pwdata  <= data;
            tim_pstrb   <= strb;

            @(posedge sys_clk);
            tim_penable <= 1'b1;

            @(posedge sys_clk);

            @(posedge sys_clk);
            tim_psel    <= 1'b0;
            tim_penable <= 1'b0;
        end
    endtask

    task do_read;
        input  [11:0] addr;
        output [31:0] captured_data;
        begin
            @(posedge sys_clk);

            tim_psel    <= 1'b1;
            tim_pwrite  <= 1'b0;
            tim_penable <= 1'b0;

            tim_paddr   <= addr;

            @(posedge sys_clk);
            tim_penable <= 1'b1;

            @(posedge sys_clk);

            captured_data = tim_prdata;

            @(posedge sys_clk);
            tim_psel    <= 1'b0;
            tim_penable <= 1'b0;
        end
    endtask

    task do_write_aborted;
        input [11:0] addr;
        input [31:0] data;
        input [3:0]  strb;
        begin
            @(posedge sys_clk);
            // SETUP phase
            tim_psel    <= 1'b1;
            tim_pwrite  <= 1'b1;
            tim_penable <= 1'b0;
            tim_paddr   <= addr;
            tim_pwdata  <= data;
            tim_pstrb   <= strb;
            @(posedge sys_clk);
            // De-assert psel to abort transaction
            tim_psel    <= 1'b0;
            @(posedge sys_clk);
        end
    endtask

    task wait_cycles;
        input integer num_cycles;
        integer i;
        begin
            for (i = 0; i < num_cycles; i = i + 1) begin
                @(posedge sys_clk);
            end
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

        // --- Reset Sequence ---
        tim_psel    <= 1'b0;
        tim_pwrite  <= 1'b0;
        tim_penable <= 1'b0;
        tim_paddr   <= 12'd0;
        tim_pwdata  <= 32'd0;
        tim_pstrb   <= 4'd0;
        dbg_mode    <= 1'b0;

        sys_rst_n   <= 1'b0;
        #25;
        sys_rst_n   <= 1'b1;

        $display(`GREEN, "System Reset Applied and Released.", `RESET);
        #10;

        // --- TEST: RESET_DEFAULTS ---
        $display(`CYAN, "%0t TEST: RESET_DEFAULTS...", $realtime, `RESET);

        do_read(TCR_ADDR,   tcr);
        do_read(TCMP0_ADDR, tcmp0);
        do_read(TCMP1_ADDR, tcmp1);
        do_read(TIER_ADDR,  tier);
        do_read(THCSR_ADDR, thcsr);

        if ( tcr   === 32'h00000100 &&
             tcmp0 === 32'hFFFFFFFF &&
             tcmp1 === 32'hFFFFFFFF &&
             tier  === 32'h00000000 &&
             thcsr === 32'h00000000 ) begin
            $display(`GREEN, "PASS: All registers reset to correct default values.", `RESET);
        end else begin
            $display(`RED, "FAIL: Register default values incorrect.", `RESET);
        end

        // --- TEST: RW_ACCESS_TCMP ---
        $display(`CYAN, "%0t TEST: RW_ACCESS_TCMP...", $realtime, `RESET);

        do_write(TCMP0_ADDR, 32'hDEADBEEF, 4'hF);
        do_read (TCMP0_ADDR, data);

        if (data === 32'hDEADBEEF) begin
            $display(`GREEN, "PASS: RW_ACCESS_TCMP successful.", `RESET);
        end else begin
            $display(`RED, "FAIL: RW_ACCESS_TCMP failed.", `RESET);
        end

        // --- TEST: BYTE_ACCESS_TCR ---
        $display(`CYAN, "%0t TEST: BYTE_ACCESS_TCR...", $realtime, `RESET);

        do_read (TCR_ADDR, before);
        do_write(TCR_ADDR, 32'hxxxx01xx, 4'b0010);
        do_read (TCR_ADDR, after);

        if ( after[11:8]   === 4'h1 &&
             after[7:0]    === before[7:0] &&
             after[31:12]  === before[31:12] ) begin
            $display(`GREEN, "PASS: BYTE_ACCESS_TCR successful.", `RESET);
        end else begin
            $display(`RED, "FAIL: BYTE_ACCESS_TCR failed.", `RESET);
        end

        // --- TEST: BYTE_ACCESS_TCMP_COMBINED ---
        $display(`CYAN, "%0t TEST: BYTE_ACCESS_TCMP_COMBINED...", $realtime, `RESET);
        do_read (TCMP0_ADDR, before);
        do_write(TCMP0_ADDR, 32'hAABBCCDD, 4'b1001); // Write MSB and LSB
        do_read (TCMP0_ADDR, after);
        if ( after[31:24] === 8'hAA && after[7:0] === 8'hDD && after[23:8] === before[23:8] ) begin
            $display(`GREEN, "PASS: BYTE_ACCESS_TCMP_COMBINED successful.", `RESET);
        end else begin
            $display(`RED, "FAIL: BYTE_ACCESS_TCMP_COMBINED failed.", `RESET);
        end


        // --- TEST: RO_READ_TDR ---
        $display(`CYAN, "%0t TEST: RO_READ_TDR...", $realtime, `RESET);

        do_write(TDR1_ADDR, 32'hAAAABBBB, 4'hF);
        do_write(TDR0_ADDR, 32'h12345678, 4'hF);

        do_read(TDR0_ADDR, tdr0);
        do_read(TDR1_ADDR, tdr1);

        if ( tdr0 === 32'h12345678 &&
             tdr1 === 32'hAAAABBBB ) begin
            $display(`GREEN, "PASS: RO_READ_TDR successful.", `RESET);
        end else begin
            $display(`RED, "FAIL: RO_READ_TDR failed.", `RESET);
        end

        // --- TEST: COUNT_DEFAULT_MODE ---
        $display(`CYAN, "%0t TEST: COUNT_DEFAULT_MODE...", $realtime, `RESET);
        // enable the timer_en and div_en
        do_write(TCR_ADDR, 32'h1, 4'h1);
        do_write(TCR_ADDR, 32'h0, 4'h1);
        do_write(TCR_ADDR, 32'h1, 4'h1);
        wait_cycles(10);
        do_read(TDR0_ADDR, count);

        if (count === (32'd10 + 32'd02)) begin
            $display(`GREEN, "PASS: COUNT_DEFAULT_MODE successful.", `RESET);
        end else begin
            $display(`RED, "FAIL: COUNT_DEFAULT_MODE failed. Expected 12, got %0d", count, `RESET);
        end

        // --- TEST: COUNT_DIV_MODE_ZERO ---
        $display(`CYAN, "%0t TEST: COUNT_DIV_MODE_ZERO...", $realtime, `RESET);
        do_write(TCR_ADDR, 32'h0, 4'h1);      // Disable timer
        do_write(TCR_ADDR, 32'h0000, 4'h2);   // Set div_val = 0
        do_write(TCR_ADDR, 32'h3, 4'h1);      // Enable timer_en and div_en
        wait_cycles(15);
        do_read(TDR0_ADDR, count);

        if (count === (32'd15 + 32'd02)) begin
            $display(`GREEN, "PASS: COUNT_DIV_MODE_ZERO successful. Counter increments every cycle.", `RESET);
        end else begin
            $display(`RED, "FAIL: COUNT_DIV_MODE_ZERO failed. Expected 17, got %0d", count, `RESET);
        end

        // --- TEST: COUNT_DIV_MODE ---
        $display(`CYAN, "%0t TEST: COUNT_DIV_MODE...", $realtime, `RESET);
        // div_val = 2
        do_write(TCR_ADDR, 32'h0, 4'h1);
        do_write(TCR_ADDR, 32'h0100, 4'h2);
        do_write(TCR_ADDR, 32'h3, 4'h1);
        wait_cycles(10);
        do_read(TDR0_ADDR, count);

        if (count === (32'd5 + 32'd1)) begin
            $display(`GREEN, "PASS: COUNT_DIV_MODE div_val=2 successful.", `RESET);
        end else begin
            $display(`RED, "FAIL: COUNT_DIV_MODE div_val=2 failed. Expected 6, got %0d", count, `RESET);
        end

        // div_val = 4
        do_write(TCR_ADDR, 32'h0, 4'h1);
        do_write(TCR_ADDR, 32'h0200, 4'h2);
        do_write(TCR_ADDR, 32'h3, 4'h1);
        wait_cycles(20);
        do_read(TDR0_ADDR, count);

        if (count === (32'd5)) begin
            $display(`GREEN, "PASS: COUNT_DIV_MODE div_val=4 successful.", `RESET);
        end else begin
            $display(`RED, "FAIL: COUNT_DIV_MODE div_val=4 failed. Expected 5, got %0d", count, `RESET);
        end

        // div_val = 8
        do_write(TCR_ADDR, 32'h0, 4'h1);
        do_write(TCR_ADDR, 32'h0300, 4'h2);
        do_write(TCR_ADDR, 32'h3, 4'h1);
        wait_cycles(40);
        do_read(TDR0_ADDR, count);

        if (count === (32'd5)) begin
            $display(`GREEN, "PASS: COUNT_DIV_MODE div_val=8 successful.", `RESET);
        end else begin
            $display(`RED, "FAIL: COUNT_DIV_MODE div_val=8 failed. Expected 5, got %0d", count, `RESET);
        end

        // div_val = 16
        do_write(TCR_ADDR, 32'h0, 4'h1);
        do_write(TCR_ADDR, 32'h0400, 4'h2);
        do_write(TCR_ADDR, 32'h3, 4'h1);
        wait_cycles(80);
        do_read(TDR0_ADDR, count);

        if (count === (32'd5)) begin
            $display(`GREEN, "PASS: COUNT_DIV_MODE div_val=16 successful.", `RESET);
        end else begin
            $display(`RED, "FAIL: COUNT_DIV_MODE div_val=16 failed. Expected 5, got %0d", count, `RESET);
        end

        // div_val = 32
        do_write(TCR_ADDR, 32'h0, 4'h1);
        do_write(TCR_ADDR, 32'h0500, 4'h2);
        do_write(TCR_ADDR, 32'h3, 4'h1);
        wait_cycles(160);
        do_read(TDR0_ADDR, count);

        if (count === (32'd5)) begin
            $display(`GREEN, "PASS: COUNT_DIV_MODE div_val=32 successful.", `RESET);
        end else begin
            $display(`RED, "FAIL: COUNT_DIV_MODE div_val=32 failed. Expected 5, got %0d", count, `RESET);
        end

        // div_val = 64
        do_write(TCR_ADDR, 32'h0, 4'h1);
        do_write(TCR_ADDR, 32'h0600, 4'h2);
        do_write(TCR_ADDR, 32'h3, 4'h1);
        wait_cycles(320);
        do_read(TDR0_ADDR, count);

        if (count === (32'd5)) begin
            $display(`GREEN, "PASS: COUNT_DIV_MODE div_val=64 successful.", `RESET);
        end else begin
            $display(`RED, "FAIL: COUNT_DIV_MODE div_val=64 failed. Expected 5, got %0d", count, `RESET);
        end

        // div_val = 128
        do_write(TCR_ADDR, 32'h0, 4'h1);
        do_write(TCR_ADDR, 32'h0700, 4'h2);
        do_write(TCR_ADDR, 32'h3, 4'h1);
        wait_cycles(640);
        do_read(TDR0_ADDR, count);

        if (count === (32'd5)) begin
            $display(`GREEN, "PASS: COUNT_DIV_MODE div_val=128 successful.", `RESET);
        end else begin
            $display(`RED, "FAIL: COUNT_DIV_MODE div_val=128 failed. Expected 5, got %0d", count, `RESET);
        end

        // div_val = 256
        do_write(TCR_ADDR, 32'h0, 4'h1);
        do_write(TCR_ADDR, 32'h0800, 4'h2);
        do_write(TCR_ADDR, 32'h3, 4'h1);
        wait_cycles(1280);
        do_read(TDR0_ADDR, count);

        if (count === (32'd5)) begin
            $display(`GREEN, "PASS: COUNT_DIV_MODE div_val=256 successful.", `RESET);
        end else begin
            $display(`RED, "FAIL: COUNT_DIV_MODE div_val=256 failed. Expected 5, got %0d", count, `RESET);
        end

        // --- TEST: COUNT_CLEAR_ON_DISABLE ---
        $display(`CYAN, "%0t TEST: COUNT_CLEAR_ON_DISABLE...", $realtime, `RESET);

        do_write(TCR_ADDR, 32'h1, 4'h1);
        wait_cycles(5);
        do_write(TCR_ADDR, 32'h0, 4'h1);
        do_read (TDR0_ADDR, count);

        if (count === 32'd0) begin
            $display(`GREEN, "PASS: COUNT_CLEAR_ON_DISABLE successful.", `RESET);
        end else begin
            $display(`RED, "FAIL: COUNT_CLEAR_ON_DISABLE failed.", `RESET);
        end

        // --- TEST: COUNT_DIRECT_WRITE ---
        $display(`CYAN, "%0t TEST: COUNT_DIRECT_WRITE...", $realtime, `RESET);

        do_write(TCR_ADDR, 32'd0,       4'h1);
        do_write(TDR0_ADDR, 32'hC0DECAFE, 4'hF);
        do_read (TDR0_ADDR, count);

        if (count === 32'hC0DECAFE) begin
            $display(`GREEN, "PASS: COUNT_DIRECT_WRITE successful.", `RESET);
        end else begin
            $display(`RED, "FAIL: COUNT_DIRECT_WRITE failed.", `RESET);
        end

        // --- TEST: INTERRUPT_TRIGGER_STICKY & CLEAR & MASK ---
        $display(`CYAN, "%0t TEST: INTERRUPT_TRIGGER_STICKY...", $realtime, `RESET);

        do_write(TCR_ADDR,   32'd0, 4'h1);
        do_write(TDR0_ADDR,  32'd9, 4'hF);
        do_write(TCMP0_ADDR, 32'd10, 4'hF);
        do_write(TCMP1_ADDR, 32'd0, 4'hF);
        do_write(TIER_ADDR,  32'd1, 4'h1);
        do_write(TCR_ADDR,   32'd1, 4'h1);

        wait_cycles(3);

        if (tim_int === 1'b1) begin
            $display(`GREEN, "PASS: INTERRUPT triggered.", `RESET);
        end else begin
            $display(`RED, "FAIL: INTERRUPT did not trigger.", `RESET);
        end

        wait_cycles(1);
        do_read(TISR_ADDR, data);

        if (data[0] === 1'b1) begin
            $display(`GREEN, "PASS: INTERRUPT status is sticky.", `RESET);
        end else begin
            $display(`RED, "FAIL: INTERRUPT status is not sticky.", `RESET);
        end

        $display(`CYAN, "%0t TEST: INTERRUPT_MASK...", $realtime, `RESET);

        do_write(TIER_ADDR, 32'd0, 4'h1);
        #1;
        do_read(TISR_ADDR, data);

        if ( (tim_int === 1'b0) && (data[0] === 1'b1) ) begin
            $display(`GREEN, "PASS: INTERRUPT_MASK successful.", `RESET);
        end else begin
            $display(`RED, "FAIL: INTERRUPT_MASK failed.", `RESET);
        end

        $display(`CYAN, "%0t TEST: INTERRUPT_CLEAR...", $realtime, `RESET);

        do_write(TISR_ADDR, 32'd1, 4'h1);
        do_read (TISR_ADDR, data);

        if ( (data[0] === 1'b0) && (tim_int === 1'b0) ) begin
            $display(`GREEN, "PASS: INTERRUPT_CLEAR successful.", `RESET);
        end else begin
            $display(`RED, "FAIL: INTERRUPT_CLEAR failed.", `RESET);
        end

        // --- TEST: HALT_BASIC & HALT_RESUME & HALT_NEGATIVE ---
        $display(`CYAN, "%0t TEST: HALT_BASIC...", $realtime, `RESET);

        do_write(TCR_ADDR, 32'd1, 4'h1);
        wait_cycles(5);

        set_dbg_mode(1'b1);
        do_write(THCSR_ADDR, 32'd1, 4'h1);

        do_read(TDR0_ADDR, c1);
        wait_cycles(10);
        do_read(TDR0_ADDR, c2);
        do_read(THCSR_ADDR, data);

        if ( (data[1] === 1'b1) && (c1 === c2) ) begin
            $display(`GREEN, "PASS: HALT_BASIC successful.", `RESET);
        end else begin
            $display(`RED, "FAIL: HALT_BASIC failed.", `RESET);
        end

        $display(`CYAN, "%0t TEST: HALT_RESUME...", $realtime, `RESET);

        do_write(THCSR_ADDR, 32'd0, 4'h1);
        wait_cycles(10);
        do_read(TDR0_ADDR, c3);
        do_read(THCSR_ADDR, data);

        if ( (data[1] === 1'b0) && (c3 > c2) ) begin
            $display(`GREEN, "PASS: HALT_RESUME successful.", `RESET);
        end else begin
            $display(`RED, "FAIL: HALT_RESUME failed.", `RESET);
        end

        $display(`CYAN, "%0t TEST: HALT_NEGATIVE...", $realtime, `RESET);

        set_dbg_mode(1'b0);
        do_write(THCSR_ADDR, 32'd1, 4'h1);

        do_read(TDR0_ADDR, c1);
        wait_cycles(10);
        do_read(TDR0_ADDR, c2);

        if (c2 > c1) begin
            $display(`GREEN, "PASS: HALT_NEGATIVE successful (dbg_mode=0).", `RESET);
        end else begin
            $display(`RED, "FAIL: HALT_NEGATIVE failed (dbg_mode=0).", `RESET);
        end

        do_write(THCSR_ADDR, 32'd0, 4'h1); // clean up

        // --- TEST: ERROR_FLAG_TIMER_RUNNING & PROHIBITED_VAL ---
        $display(`CYAN, "%0t TEST: ERROR_FLAG_TIMER_RUNNING...", $realtime, `RESET);

        do_write(TCR_ADDR, 32'd1, 4'h1);
        do_read (TCR_ADDR, before);

        // Manual transaction to check pslverr
        @(posedge sys_clk);

        tim_psel    <= 1'b1;
        tim_pwrite  <= 1'b1;
        tim_penable <= 1'b0;

        tim_paddr   <= TCR_ADDR;
        tim_pwdata  <= 32'h00000501;
        tim_pstrb   <= 4'hF;

        @(posedge sys_clk);
        tim_penable <= 1'b1;

        @(posedge sys_clk);
        @(posedge sys_clk);

        if (tim_pslverr === 1'b1) begin
            $display(`GREEN, "PASS: pslverr asserted.", `RESET);
        end else begin
            $display(`RED, "FAIL: pslverr not asserted.", `RESET);
        end

        tim_psel    <= 1'b0;
        tim_penable <= 1'b0;

        do_read(TCR_ADDR, after);

        if (after === before) begin
            $display(`GREEN, "PASS: Register unchanged after error.", `RESET);
        end else begin
            $display(`RED, "FAIL: Register changed after error.", `RESET);
        end

        $display(`CYAN, "%0t TEST: ERROR_FLAG_PROHIBITED_VAL...", $realtime, `RESET);

        do_write(TCR_ADDR, 32'd0, 4'h1);
        do_read (TCR_ADDR, before);

        // illegal div_val = 0xF
        do_write(TCR_ADDR, 32'h00000F00, 4'hF);

        if (tim_pslverr) begin
            $display(`GREEN, "PASS: pslverr asserted on prohibited value write.", `RESET);
        end else begin
            $display(`RED, "FAIL: pslverr not asserted on prohibited value write.", `RESET);
        end

        do_read(TCR_ADDR, after);

        if (after === before) begin
            $display(`GREEN, "PASS: Register unchanged after error.", `RESET);
        end else begin
            $display(`RED, "FAIL: Register changed after error.", `RESET);
        end

        // --- TEST: INVALID_ADDR_READ & WRITE ---
        $display(`CYAN, "%0t TEST: INVALID_ADDR_READ...", $realtime, `RESET);

        do_read(INVALID_ADDR, data);

        if (data === 32'h00000000) begin
            $display(`GREEN, "PASS: INVALID_ADDR_READ successful.", `RESET);
        end else begin
            $display(`RED, "FAIL: INVALID_ADDR_READ failed.", `RESET);
        end

        $display(`CYAN, "TEST: INVALID_ADDR_WRITE...", `RESET);

        do_read (TCR_ADDR, before);
        do_write(INVALID_ADDR, 32'hFFFFFFFF, 4'hF);
        do_read (TCR_ADDR, after);

        if (after === before) begin
            $display(`GREEN, "PASS: INVALID_ADDR_WRITE successful.", `RESET);
        end else begin
            $display(`RED, "FAIL: INVALID_ADDR_WRITE failed.", `RESET);
        end

        // --- TEST: ERROR_CONCURRENT ---
        $display(`CYAN, "%0t TEST: ERROR_CONCURRENT...", $realtime, `RESET);
        do_write(TCR_ADDR, 32'd1, 4'h1); 

        // Manual transaction to trigger concurrent errors (change div_val while running AND use prohibited value)
        @(posedge sys_clk);
        tim_psel    <= 1'b1;
        tim_pwrite  <= 1'b1;
        tim_penable <= 1'b0;
        tim_paddr   <= TCR_ADDR;
        tim_pwdata  <= 32'h00000F01; 
        tim_pstrb   <= 4'hF;
        @(posedge sys_clk);
        tim_penable <= 1'b1;
        @(posedge sys_clk);
        @(posedge sys_clk);
        if (tim_pslverr === 1'b1) begin
            $display(`GREEN, "PASS: pslverr asserted for concurrent errors.", `RESET);
        end else begin
            $display(`RED, "FAIL: pslverr not asserted for concurrent errors.", `RESET);
        end
        tim_psel    <= 1'b0;
        tim_penable <= 1'b0;
        do_write(TCR_ADDR, 32'd0, 4'h1); 

        // --- TEST: COUNT_ROLLOVER_32B ---
        $display(`CYAN, "%0t TEST: COUNT_ROLLOVER_32B...", $realtime, `RESET);
        do_write(TCR_ADDR, 32'd0, 4'h1); 
        do_write(TDR0_ADDR, 32'hFFFFFFFF, 4'hF);
        do_write(TDR1_ADDR, 32'h00000000, 4'hF);
        do_write(TCR_ADDR, 32'd1, 4'h1); 
        wait_cycles(5);
        do_read(TDR0_ADDR, tdr0);
        do_read(TDR1_ADDR, tdr1);
        if ( tdr0 === (32'd4 + 32'd2) && tdr1 === 32'd1 ) begin
             $display(`GREEN, "PASS: COUNT_ROLLOVER_32B successful.", `RESET);
        end else begin
             $display(`RED, "FAIL: COUNT_ROLLOVER_32B failed. Expected {1, 6}, got {%0h, %0h}", tdr1, tdr0, `RESET);
        end
        do_write(TCR_ADDR, 32'd0, 4'h1); 

        // --- TEST: INTERRUPT_CLEAR_PRIORITY ---
        $display(`CYAN, "%0t TEST: INTERRUPT_CLEAR_PRIORITY...", $realtime, `RESET);
        do_write(TCR_ADDR, 32'd0, 4'h1); 
        do_write(TISR_ADDR, 32'd1, 4'h1); 
        do_write(TCMP0_ADDR, 32'd10, 4'hF);
        do_write(TIER_ADDR, 32'd1, 4'h1);
        do_write(TDR0_ADDR, 32'd10, 4'hF); 
        do_write(TCR_ADDR, 32'd1, 4'h1); 
        wait_cycles(2);
        do_write(TISR_ADDR, 32'd1, 4'h1);
        do_read(TISR_ADDR, data);
        if (data[0] === 1'b0 && tim_int === 1'b0) begin
            $display(`GREEN, "PASS: INTERRUPT_CLEAR_PRIORITY successful.", `RESET);
        end else begin
            $display(`RED, "FAIL: INTERRUPT_CLEAR_PRIORITY failed.", `RESET);
        end
        do_write(TCR_ADDR, 32'd0, 4'h1); 

        // --- TEST: APB_ABORT ---
        $display(`CYAN, "%0t TEST: APB_ABORT...", $realtime, `RESET);
        do_read(TCMP0_ADDR, before);
        do_write_aborted(TCMP0_ADDR, 32'hABADCAFE, 4'hF);
        do_read(TCMP0_ADDR, after);
        if (before === after) begin
            $display(`GREEN, "PASS: APB_ABORT successful, register unchanged.", `RESET);
        end else begin
            $display(`RED, "FAIL: APB_ABORT failed, register was modified.", `RESET);
        end

        // --- TEST: APB_BACK_TO_BACK ---
        $display(`CYAN, "%0t TEST: APB_BACK_TO_BACK...", $realtime, `RESET);
        // Manual back-to-back Write -> Read transaction
        // Txn 1: Write to TCMP1
        @(posedge sys_clk);
        tim_pwrite  <= 1'b1;
        tim_psel    <= 1'b1;
        tim_penable <= 1'b0;
        tim_paddr   <= TCMP1_ADDR;
        tim_pwdata  <= 32'hCAFED00D;
        tim_pstrb   <= 4'hF;
        @(posedge sys_clk);
        tim_penable <= 1'b1; 
        @(posedge sys_clk); 
        @(posedge sys_clk); 

        // Txn 2: Read from TCMP1
        tim_pwrite  <= 1'b0;
        tim_penable <= 1'b0; 
        tim_paddr   <= TCMP1_ADDR;
        @(posedge sys_clk);
        tim_penable <= 1'b1; 
        @(posedge sys_clk);
        data = tim_prdata; 
        @(posedge sys_clk);
        tim_psel    <= 1'b0; 
        tim_penable <= 1'b0;
        if (data === 32'hCAFED00D) begin
            $display(`GREEN, "PASS: APB_BACK_TO_BACK successful.", `RESET);
        end else begin
            $display(`RED, "FAIL: APB_BACK_TO_BACK failed. Expected CAFED00D, got %0h", data, `RESET);
        end

        // --- TEST: MAX_VALUE_TOGGLE ---
        $display(`CYAN, "%0t TEST: MAX_VALUE_TOGGLE...", $realtime, `RESET);
        toggle_test_passed = 1'b1;
        do_write(TCR_ADDR, 32'd0, 4'h1);
        
        do_write(TCMP0_ADDR, 32'h00000000, 4'hF);
        do_write(TCMP0_ADDR, 32'hFFFFFFFF, 4'hF);
        do_read(TCMP0_ADDR, data);
        if (data !== 32'hFFFFFFFF) toggle_test_passed = 1'b0;

        do_write(TCMP1_ADDR, 32'h00000000, 4'hF);
        do_write(TCMP1_ADDR, 32'hFFFFFFFF, 4'hF);
        do_read(TCMP1_ADDR, data);
        if (data !== 32'hFFFFFFFF) toggle_test_passed = 1'b0;

        do_write(TDR0_ADDR, 32'h00000000, 4'hF);
        do_write(TDR0_ADDR, 32'hFFFFFFFF, 4'hF);
        do_read(TDR0_ADDR, data);
        if (data !== 32'hFFFFFFFF) toggle_test_passed = 1'b0;

        do_write(TDR1_ADDR, 32'h00000000, 4'hF);
        do_write(TDR1_ADDR, 32'hFFFFFFFF, 4'hF);
        do_read(TDR1_ADDR, data);
        if (data !== 32'hFFFFFFFF) toggle_test_passed = 1'b0;

        if (toggle_test_passed) begin
            $display(`GREEN, "PASS: MAX_VALUE_TOGGLE successful.", `RESET);
        end else begin
            $display(`RED, "FAIL: MAX_VALUE_TOGGLE failed. Readback value incorrect.", `RESET);
        end


        // --- TEST: DIV_VAL_TOGGLE ---
        $display(`CYAN, "%0t TEST: DIV_VAL_TOGGLE...", $realtime, `RESET);
        do_write(TCR_ADDR, 32'h0800, 4'h2); // Set div_val = 8 (binary 1000)
        do_write(TCR_ADDR, 32'h0100, 4'h2); // Set div_val = 1 (binary 0001)
        do_read(TCR_ADDR, data); // *** ADDED CHECKER LOGIC ***
        if (data[11:8] === 4'h1) begin
            $display(`GREEN, "PASS: DIV_VAL_TOGGLE successful.", `RESET);
        end else begin
            $display(`RED, "FAIL: DIV_VAL_TOGGLE failed. div_val was not set correctly.", `RESET);
        end


        // --- TEST: BYTE_ACCESS_STROBE_MISS ---
        $display(`CYAN, "%0t TEST: BYTE_ACCESS_STROBE_MISS...", $realtime, `RESET);
        do_write(TCMP0_ADDR, 32'hAAAAAAAA, 4'hF);
        do_read(TCMP0_ADDR, before);
        do_write(TCMP0_ADDR, 32'hDEADBEEF, 4'b1110);
        do_read(TCMP0_ADDR, after);
        if (after[7:0] === before[7:0] && after[31:8] === 32'hDEADBE) begin
            $display(`GREEN, "PASS: BYTE_ACCESS_STROBE_MISS successful. Byte 0 was not written.", `RESET);
        end else begin
            $display(`RED, "FAIL: BYTE_ACCESS_STROBE_MISS failed. Expected %h, got %h", {before[31:8], 8'hEF}, after, `RESET);
        end


        // --- TEST: BYTE_ACCESS_STROBE_MISS_MSB ---
        // Goal: Hit remaining branch coverage for tim_pstrb checks in u_register.
        $display(`CYAN, "%0t TEST: BYTE_ACCESS_STROBE_MISS_MSB...", $realtime, `RESET);
        do_write(TCMP1_ADDR, 32'hAAAAAAAA, 4'hF); // Pre-load
        do_read(TCMP1_ADDR, before);
        do_write(TCMP1_ADDR, 32'hDEADBEEF, 4'b0111); // Write bytes 2, 1, 0 only
        do_read(TCMP1_ADDR, after);
        if (after[31:24] === before[31:24] && after[23:0] === 32'hADBEEF) begin
            $display(`GREEN, "PASS: BYTE_ACCESS_STROBE_MISS_MSB successful.", `RESET);
        end else begin
            $display(`RED, "FAIL: BYTE_ACCESS_STROBE_MISS_MSB failed.", `RESET);
        end

        // --- TEST: COMPREHENSIVE_STROBE_TEST ---
        // Goal: Hit all remaining branch coverage misses for tim_pstrb checks.
        $display(`CYAN, "%0t TEST: COMPREHENSIVE_STROBE_TEST...", $realtime, `RESET);

        // Test missing strobe on TCMP0[3]
        do_write(TCMP0_ADDR, 32'hAAAAAAAA, 4'hF); // Pre-load
        do_read(TCMP0_ADDR, before);
        do_write(TCMP0_ADDR, 32'hDEADBEEF, 4'b0111); // Write bytes 2,1,0 only
        do_read(TCMP0_ADDR, after);
        if (after[31:24] === before[31:24] && after[23:0] === 32'hADBEEF) begin
            $display(`GREEN, "PASS: TCMP0 MSB strobe miss successful.", `RESET);
        end else begin
            $display(`RED, "FAIL: TCMP0 MSB strobe miss failed.", `RESET);
        end

        // Test missing strobes on TCMP1[2:0]
        do_write(TCMP1_ADDR, 32'hBBBBBBBB, 4'hF); // Pre-load
        do_read(TCMP1_ADDR, before);
        do_write(TCMP1_ADDR, 32'hCAFED00D, 4'b1000); // Write byte 3 only
        do_read(TCMP1_ADDR, after);
        if (after[31:24] === 32'hCA && after[23:0] === before[23:0]) begin
            $display(`GREEN, "PASS: TCMP1 LSBs strobe miss successful.", `RESET);
        end else begin
            $display(`RED, "FAIL: TCMP1 LSBs strobe miss failed.", `RESET);
        end

        // Test no-op write to TIER
        do_read(TIER_ADDR, before);
        do_write(TIER_ADDR, 32'hFFFFFFFF, 4'b0000); // Write with no strobes
        do_read(TIER_ADDR, after);
        if (after === before) begin
            $display(`GREEN, "PASS: TIER no-op write successful.", `RESET);
        end else begin
            $display(`RED, "FAIL: TIER no-op write failed.", `RESET);
        end

        // Test no-op write to THCSR
        do_read(THCSR_ADDR, before);
        do_write(THCSR_ADDR, 32'hFFFFFFFF, 4'b0000); // Write with no strobes
        do_read(THCSR_ADDR, after);
        if (after === before) begin
            $display(`GREEN, "PASS: THCSR no-op write successful.", `RESET);
        end else begin
            $display(`RED, "FAIL: THCSR no-op write failed.", `RESET);
        end


        // --- TEST: INTERRUPT_CLEAR_NEGATIVE ---
        $display(`CYAN, "%0t TEST: INTERRUPT_CLEAR_NEGATIVE...", $realtime, `RESET);
        do_write(TCR_ADDR, 32'd0, 4'h1);
        do_write(TCMP0_ADDR, 32'd5, 4'hF);
        do_write(TDR0_ADDR, 32'd5, 4'hF);
        do_write(TCR_ADDR, 32'd1, 4'h1);
        wait_cycles(2);
        do_read(TISR_ADDR, before);
        do_write(TISR_ADDR, 32'd0, 4'h1);
        do_read(TISR_ADDR, after);
        if (before[0] === 1'b1 && after[0] === 1'b1) begin
            $display(`GREEN, "PASS: INTERRUPT_CLEAR_NEGATIVE successful. Writing 0 did not clear status.", `RESET);
        end else begin
            $display(`RED, "FAIL: INTERRUPT_CLEAR_NEGATIVE failed.", `RESET);
        end
        do_write(TISR_ADDR, 32'd1, 4'h1);


        // --- TEST: COUNTER_CONTROL_CONDITION ---
        $display(`CYAN, "%0t TEST: COUNTER_CONTROL_CONDITION...", $realtime, `RESET);
        do_write(TCR_ADDR, 32'h0, 4'h1);
        do_write(TCR_ADDR, 32'h0203, 4'h3); // timer_en=1, div_en=1, div_val=2
        wait_cycles(10);
        do_read(TDR0_ADDR, c1);
        wait_cycles(10);
        do_read(TDR0_ADDR, c2); // c2 should be > c1
        
        do_write(TCR_ADDR, 32'h0202, 4'h1); // De-assert timer_en
        do_read(TDR0_ADDR, c3); // Read value immediately after disable
        wait_cycles(10);
        do_read(TDR0_ADDR, c4); // Read value after waiting
        
        if (c2 > c1 && c3 === c4) begin
            $display(`GREEN, "PASS: COUNTER_CONTROL_CONDITION successful. Counter stopped correctly.", `RESET);
        end else begin
            $display(`RED, "FAIL: COUNTER_CONTROL_CONDITION failed. c1=%d, c2=%d, c3=%d, c4=%d", c1, c2, c3, c4, `RESET);
        end


        // --- TEST: APB_SETUP_WAIT ---
        // Goal: Hit branch coverage in u_apb_slave FSM by waiting in the SETUP state.
        $display(`CYAN, "%0t TEST: APB_SETUP_WAIT...", $realtime, `RESET);
        do_read(TCMP0_ADDR, before);
        // Manual transaction to wait in SETUP state
        @(posedge sys_clk);
        tim_psel    <= 1'b1;
        tim_pwrite  <= 1'b1;
        tim_penable <= 1'b0; // Enter SETUP
        tim_paddr   <= TCMP0_ADDR;
        tim_pwdata  <= 32'h1A2B3C4D;
        tim_pstrb   <= 4'hF;

        // Keep psel=1 and penable=0 for 3 cycles to wait in SETUP
        wait_cycles(3);

        @(posedge sys_clk);
        tim_penable <= 1'b1; // Now go to ACCESS state
        @(posedge sys_clk); // Wait for pready
        @(posedge sys_clk); // Finish access
        tim_psel    <= 1'b0;
        tim_penable <= 1'b0;

        do_read(TCMP0_ADDR, after);
        if (after === 32'h1A2B3C4D) begin
            $display(`GREEN, "PASS: APB_SETUP_WAIT successful. Write completed after setup wait.", `RESET);
        end else begin
            $display(`RED, "FAIL: APB_SETUP_WAIT failed. Write did not complete correctly.", `RESET);
        end


        // --- TEST: APB_ACCESS_WAIT ---
        // Goal: Hit expression coverage for tim_pready in u_apb_slave.
        $display(`CYAN, "%0t TEST: APB_ACCESS_WAIT...", $realtime, `RESET);
        do_read(TCMP0_ADDR, before); 

        // Manual transaction to de-assert penable during ACCESS
        @(posedge sys_clk);
        tim_psel    <= 1'b1;
        tim_pwrite  <= 1'b0;
        tim_penable <= 1'b0; 
        tim_paddr   <= TCMP0_ADDR;

        @(posedge sys_clk);
        tim_penable <= 1'b1; 

        @(posedge sys_clk); 
        tim_penable <= 1'b0; 
        wait_cycles(2);    

        tim_penable <= 1'b1; 
        @(posedge sys_clk);
        data = tim_prdata;   
        @(posedge sys_clk);
        tim_psel    <= 1'b0;
        tim_penable <= 1'b0;

        if (data === before) begin
            $display(`GREEN, "PASS: APB_ACCESS_WAIT successful. Read data is correct.", `RESET);
        end else begin
            $display(`RED, "FAIL: APB_ACCESS_WAIT failed. Expected %h, got %h", before, data, `RESET);
        end

        // --- TEST: APB_ACCESS_PSEL_ABORT ---
        // Goal: Hit final expression coverage for tim_pready in u_apb_slave.
        $display(`CYAN, "%0t TEST: APB_ACCESS_PSEL_ABORT...", $realtime, `RESET);
        // Manual transaction to de-assert psel during ACCESS
        @(posedge sys_clk);
        tim_psel    <= 1'b1;
        tim_pwrite  <= 1'b0;
        tim_penable <= 1'b0; // Enter SETUP
        tim_paddr   <= TCR_ADDR;

        @(posedge sys_clk);
        tim_penable <= 1'b1; // Enter ACCESS

        @(posedge sys_clk); // Now in ACCESS state. pready should be high.
        tim_psel    <= 1'b0; // De-assert psel. This should de-assert pready.
        @(posedge sys_clk);
        tim_psel    <= 1'b1; // Re-assert to avoid confusing other logic.
        @(posedge sys_clk);
        tim_psel    <= 1'b0; // End of sequence
        tim_penable <= 1'b0;

        $display(`GREEN, "PASS: APB_ACCESS_PSEL_ABORT sequence executed.", `RESET);

        // --- TEST: Halt ack ---
        $display(`CYAN, "%0t TEST: HALT_ACK...", $realtime, `RESET);
        set_dbg_mode(1'b1);
        do_write(THCSR_ADDR, 32'd1, 4'h1);
        wait_cycles(2);
        do_read(THCSR_ADDR, data);
        if (data[1] === 1'b1) begin
            $display(`GREEN, "PASS: HALT_ACK successful. Halt acknowledged.", `RESET);
        end else begin
            $display(`RED, "FAIL: HALT_ACK failed. Halt not acknowledged.", `RESET);
        end

        // --- TEST: Halt no ack when dbg_mode=0 ---
        $display(`CYAN, "%0t TEST: HALT_NO_ACK...", $realtime, `RESET);
        set_dbg_mode(1'b0);
        do_write(THCSR_ADDR, 32'd1, 4'h1);
        wait_cycles(2);
        do_read(THCSR_ADDR, data);
        if (data[1] === 1'b0) begin
            $display(`GREEN, "PASS: HALT_NO_ACK successful. No halt ack when dbg_mode=0.", `RESET);
        end else begin
            $display(`RED, "FAIL: HALT_NO_ACK failed. Unexpected halt ack when dbg_mode=0.", `RESET);
        end

        $display(`CYAN, "\n--- All tests complete. Finishing simulation. ---", `RESET);
        $finish;
    end

endmodule

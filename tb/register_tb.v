`timescale 1ns / 1ps

// Color Codes for Console Output
`define RED     "\033[1;31m"
`define GREEN   "\033[1;32m"
`define YELLOW  "\033[1;33m"
`define CYAN    "\033[1;36m"
`define RESET   "\033[0m"

module register_tb;
    // --- Testbench Signals ---
    reg  sys_clk;
    reg  sys_rst_n;

    // Inputs to the DUT
    reg  wr_en;
    reg  rd_en;
    reg  [11:0] tim_paddr;
    reg  [31:0] tim_pwdata;
    reg  [3:0]  tim_pstrb;
    reg  [63:0] cnt_val;
    reg  halt_ack_status;
    reg  interrupt_status;

    // Outputs from the DUT
    wire [31:0] tim_prdata;
    wire timer_en;
    wire div_en;
    wire [3:0]  div_val;
    wire halt_req;
    wire [63:0] compare_val;
    wire interrupt_en;
    wire counter_clear;
    wire [1:0]  counter_write_sel;
    wire [31:0] counter_write_data;
    wire interrupt_clear;
    wire reg_error_flag;

    // --- Instantiate the Design Under Test (DUT) ---
    register dut (
        .sys_clk(sys_clk),
        .sys_rst_n(sys_rst_n),
        .wr_en(wr_en),
        .rd_en(rd_en),
        .tim_paddr(tim_paddr),
        .tim_pwdata(tim_pwdata),
        .tim_pstrb(tim_pstrb),
        .tim_prdata(tim_prdata),
        .cnt_val(cnt_val),
        .halt_ack_status(halt_ack_status),
        .interrupt_status(interrupt_status),
        .timer_en(timer_en),
        .div_en(div_en),
        .div_val(div_val),
        .halt_req(halt_req),
        .compare_val(compare_val),
        .interrupt_en(interrupt_en),
        .counter_clear(counter_clear),
        .counter_write_sel(counter_write_sel),
        .counter_write_data(counter_write_data),
        .interrupt_clear(interrupt_clear),
        .reg_error_flag(reg_error_flag)
    );
    
    // --- Clock Generator ---
    initial begin
        sys_clk = 0;
        forever #50 sys_clk = ~sys_clk; // 100ns period clock
    end

    // --- Testbench Helper Tasks ---
    task write_reg;
        input [11:0] addr;
        input [31:0] data;
        input [3:0]  strb;
        begin
            @(posedge sys_clk);
            wr_en     <= 1'b1;
            rd_en     <= 1'b0;
            tim_paddr <= addr;
            tim_pwdata <= data;
            tim_pstrb <= strb;
            @(posedge sys_clk);
            wr_en     <= 1'b0;
            tim_paddr <= 12'h0;
            tim_pwdata <= 32'h0;
            tim_pstrb <= 4'h0;
        end
    endtask

    task read_reg;
        input [11:0] addr;
        begin
            @(posedge sys_clk);
            wr_en     <= 1'b0;
            rd_en     <= 1'b1;
            tim_paddr <= addr;
            @(posedge sys_clk);
            rd_en     <= 1'b0;
            tim_paddr <= 12'h0;
        end
    endtask

    // --- Test Sequence ---
    initial begin
        $display(`CYAN);
        $display("-----------------------------------");
        $display("--- Starting Register Testbench ---");
        $display("-----------------------------------", `RESET);

        // --- Reset Sequence ---
        $display(`YELLOW, "Applying Reset...", `RESET);
        wr_en <= 0; rd_en <= 0; tim_paddr <= 0; tim_pwdata <= 0; tim_pstrb <= 0;
        cnt_val <= 0; halt_ack_status <= 0; interrupt_status <= 0;
        sys_rst_n <= 0;
        #25;
        sys_rst_n <= 1;
        $display(`GREEN, "Reset Released.", `RESET);
        #10;

        // // --- SCENARIO 1: Basic Register Write and Read ---
        // $display(`CYAN, "TEST 1: Verifying basic write/read (TCMP0)...", `RESET);
        // write_reg(12'h00C, 32'h12345678, 4'hF);
        // read_reg(12'h00C);
        
        // if (tim_prdata === 32'h12345678)
        //     $display(`GREEN, "PASS: Correctly read back the value written to TCMP0.", `RESET);
        // else
        //     $display(`RED, "FAIL: Read incorrect value from TCMP0. Expected 32'h12345678, got %h", tim_prdata, `RESET);
        // #20;

        // // --- SCENARIO 2: Reading a Status Register ---
        // $display(`CYAN, "TEST 2: Verifying read from status register (TDR0)...", `RESET);
        // cnt_val <= 64'hAAAABBBB_C0C0DADA;
        // read_reg(12'h004); // Read TDR0
        
        // if (tim_prdata === 32'hC0C0DADA)
        //     $display(`GREEN, "PASS: Correctly read cnt_val[31:0] through TDR0.", `RESET);
        // else
        //     $display(`RED, "FAIL: Incorrect value from TDR0. Expected 32'hC0C0DADA, got %h", tim_prdata, `RESET);
        // #20;

        // --- SCENARIO 3: Checking a Command Output ---
        $display(`CYAN, "TEST 3: Verifying interrupt_clear command generation...", `RESET);
        write_reg(12'h018, 32'h00000001, 4'h1); // Write 1 to TISR

        #1; // Small delay to allow signal propagation
        if (interrupt_clear === 1'b1)
            $display(`GREEN, "PASS: interrupt_clear pulsed high during write to TISR.", `RESET);
        else
            $display(`RED, "FAIL: interrupt_clear did not pulse high.", `RESET);
        #20;

        // // --- SCENARIO 4: Checking Control Outputs ---
        // $display(`CYAN, "TEST 4: Verifying control signal outputs from TCR write...", `RESET);
        // write_reg(12'h000, 32'h00000503, 4'hF); // timer_en=1, div_en=1, div_val=5
        // #1; 
        
        // if (timer_en === 1'b1 && div_en === 1'b1 && div_val === 4'h5)
        //     $display(`GREEN, "PASS: Control outputs correctly reflect TCR value.", `RESET);
        // else
        //     $display(`RED, "FAIL: Control outputs mismatch. timer_en=%b, div_en=%b, div_val=%h", timer_en, div_en, div_val, `RESET);
        // #20;

        // // --- SCENARIO 5: Checking Error Flag Generation ---
        // $display(`CYAN, "TEST 5: Verifying reg_error_flag generation...", `RESET);
        // // Condition: timer_en is already 1 from the previous test. Now try to write div_val again.
        // write_reg(12'h000, 32'h00000603, 4'hF);
        // #1;

        // if (reg_error_flag === 1'b1)
        //     $display(`GREEN, "PASS: reg_error_flag correctly asserted on illegal write.", `RESET);
        // else
        //     $display(`RED, "FAIL: reg_error_flag was not asserted on illegal write.", `RESET);
        // @(posedge sys_clk);
        // #20;

        $display(`CYAN, "--- All tests complete. Finishing simulation. ---", `RESET);
        $finish;
    end

endmodule
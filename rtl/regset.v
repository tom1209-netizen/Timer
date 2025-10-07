module register (
    // System Signals
    input wire sys_clk,
    input wire sys_rst_n,

    // APB Interface
    input wire wr_en,
    input wire rd_en,
    input wire [11:0] tim_paddr,
    input wire [31:0] tim_pwdata,
    input wire [3:0] tim_pstrb,
    output wire [31:0] tim_prdata,

    // Status Inputs from other blocks
    input wire [63:0] cnt_val,
    input wire halt_ack_status,
    input wire interrupt_status,

    // Control Outputs to other blocks
    output wire timer_en,
    output wire div_en,
    output wire [3:0] div_val,
    output wire halt_req,
    output wire [63:0] compare_val,
    output wire interrupt_en,

    // Command Outputs to other blocks
    output wire counter_clear,
    output wire [1:0] counter_write_sel,
    output wire [31:0] counter_write_data,
    output wire interrupt_clear,

    // Error Output to apb_slave
    output wire reg_error_flag
);
    localparam TCR_ADDR = 12'h000;
    localparam TDR0_ADDR = 12'h004;
    localparam TDR1_ADDR = 12'h008;
    localparam TCMP0_ADDR = 12'h00C;
    localparam TCMP1_ADDR = 12'h010;
    localparam TIER_ADDR = 12'h014;
    localparam TISR_ADDR = 12'h018;
    localparam THCSR_ADDR = 12'h01C;

    wire tcr_sel = (tim_paddr == TCR_ADDR);
    wire tdr0_sel = (tim_paddr == TDR0_ADDR);
    wire tdr1_sel = (tim_paddr == TDR1_ADDR);
    wire tcmp0_sel = (tim_paddr == TCMP0_ADDR);
    wire tcmp1_sel = (tim_paddr == TCMP1_ADDR);
    wire tier_sel = (tim_paddr == TIER_ADDR);
    wire tisr_sel = (tim_paddr == TISR_ADDR);
    wire thcsr_sel = (tim_paddr == THCSR_ADDR);

    reg [31:0] tcr_reg;
    reg [31:0] tcmp0_reg;
    reg [31:0] tcmp1_reg;
    reg [31:0] tier_reg;
    reg [31:0] thcsr_reg;
    reg timer_en_dly;

    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            tcr_reg <= {20'h0, 4'b0001, 6'b0, 1'b0, 1'b0};
            tcmp0_reg <= 32'hFFFF_FFFF;
            tcmp1_reg <= 32'hFFFF_FFFF;
            tier_reg <= 32'h0;
            thcsr_reg <= 32'h0;
        end else if (wr_en && !reg_error_flag) begin
            if (tcr_sel) begin
                if (tim_pstrb[0]) tcr_reg[7:0] <= tim_pwdata[7:0];
                if (tim_pstrb[1]) tcr_reg[15:8] <= tim_pwdata[15:8];
            end

            if (tcmp0_sel) begin
                if (tim_pstrb[0]) tcmp0_reg[7:0] <= tim_pwdata[7:0];
                if (tim_pstrb[1]) tcmp0_reg[15:8] <= tim_pwdata[15:8];
                if (tim_pstrb[2]) tcmp0_reg[23:16] <= tim_pwdata[23:16];
                if (tim_pstrb[3]) tcmp0_reg[31:24] <= tim_pwdata[31:24];
            end

            if (tcmp1_sel) begin
                if (tim_pstrb[0]) tcmp1_reg[7:0] <= tim_pwdata[7:0];
                if (tim_pstrb[1]) tcmp1_reg[15:8] <= tim_pwdata[15:8];
                if (tim_pstrb[2]) tcmp1_reg[23:16] <= tim_pwdata[23:16];
                if (tim_pstrb[3]) tcmp1_reg[31:24] <= tim_pwdata[31:24];
            end

            if (tier_sel) begin
                if (tim_pstrb[0]) tier_reg[0] <= tim_pwdata[0];
            end

            if (thcsr_sel) begin
                if (tim_pstrb[0]) thcsr_reg[0] <= tim_pwdata[0];
            end
        end
    end

    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            timer_en_dly <= 1'b0;
        end else begin
            timer_en_dly <= tcr_reg[0];
        end
    end

    reg [31:0] read_mux_out;

    always @(*) begin
        read_mux_out = 32'h0;
        case (tim_paddr)
            TCR_ADDR:   read_mux_out = tcr_reg;
            TDR0_ADDR:  read_mux_out = cnt_val[31:0];
            TDR1_ADDR:  read_mux_out = cnt_val[63:32];
            TCMP0_ADDR: read_mux_out = tcmp0_reg;
            TCMP1_ADDR: read_mux_out = tcmp1_reg;
            TIER_ADDR:  read_mux_out = tier_reg;
            TISR_ADDR:  read_mux_out = {31'b0, interrupt_status};
            THCSR_ADDR: read_mux_out = {30'b0, halt_ack_status, thcsr_reg[0]};
        endcase
    end

    assign tim_prdata = read_mux_out;

    assign timer_en = tcr_reg[0];
    assign div_en = tcr_reg[1];
    assign div_val = tcr_reg[11:8];
    assign halt_req = thcsr_reg[0];
    assign compare_val = {tcmp1_reg, tcmp0_reg};
    assign interrupt_en = tier_reg[0];
    assign counter_clear = timer_en_dly && !tcr_reg[0];
    assign counter_write_sel[0] = wr_en && tdr0_sel;
    assign counter_write_sel[1] = wr_en && tdr1_sel;
    assign counter_write_data = tim_pwdata;
    assign interrupt_clear = wr_en && tisr_sel && tim_pwdata[0];

    wire is_timer_running;
    wire write_to_tcr_div;
    wire prohibited_div_val;

    assign is_timer_running = tcr_reg[0];
    assign write_to_tcr_div = wr_en && tcr_sel && (tim_pstrb[0] || tim_pstrb[1]);
    assign prohibited_div_val = wr_en && tcr_sel && tim_pstrb[1] && (tim_pwdata[11:8] > 4'b1000);

    assign reg_error_flag = (is_timer_running && write_to_tcr_div) || prohibited_div_val;

endmodule

module interrupt (
    // System Signals
    input wire sys_clk,
    input wire sys_rst_n,

    // Inputs
    input wire [63:0] cnt_val,
    input wire [63:0] compare_val,
    input wire interrupt_en,
    input wire interrupt_clear,

    // Outputs
    output reg interrupt_status,
    output wire tim_int
);
    wire match = (cnt_val == compare_val);

    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            interrupt_status <= 1'b0;
        end else if (interrupt_clear) begin
            interrupt_status <= 1'b0;
        end else if (match) begin
            interrupt_status <= 1'b1;
        end
    end

    assign tim_int = interrupt_status && interrupt_en;
endmodule

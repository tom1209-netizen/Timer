module counter (
    // System Signals
    input wire sys_clk,
    input wire sys_rst_n,

    // Control Inputs
    input wire cnt_en,
    input wire counter_clear,

    // Data Write Interface
    input wire [31:0] counter_write_data,
    input wire [1:0] counter_write_sel,

    // Data Outputs
    output wire [63:0] cnt_val
);

    reg [63:0] counter_reg;
    assign cnt_val = counter_reg;

    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            counter_reg <= 64'd0;
        end else if (counter_clear) begin
            counter_reg <= 64'd0;
        end else if (counter_write_sel == 2'b01) begin
            counter_reg[31:0] <= counter_write_data;
        end else if (counter_write_sel == 2'b10) begin
            counter_reg[63:32] <= counter_write_data;
        end else if (cnt_en) begin
            counter_reg <= counter_reg + 1;
        end
    end

endmodule

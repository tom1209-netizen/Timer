module interrupt (
    // System Signals
    input wire sys_clk,
    input wire sys_rst_n,

    // Inputs
    input wire [63:0] cnt_val,
    input wire [63:0] compare_val,
    input wire interrupt_en,
    input wire interrupt_pending_clear,

    // Outputs
    output reg interrupt_status,
    output wire tim_int
);
    wire match = (cnt_val == compare_val);

    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            interrupt_status <= 1'b0;
        end else if (interrupt_pending_clear) begin
            interrupt_status <= 1'b0;
        end else if (match) begin
            interrupt_status <= 1'b1;
        end
    end

    assign tim_int = interrupt_status && interrupt_en;
endmodule

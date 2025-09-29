module counter_control (
    // System Signals
    input wire sys_clk,
    input wire sys_rst_n,

    // Control Inputs from Register Block
    input wire timer_en,
    input wire div_en,
    input wire [3:0] div_val,
    input wire halt_req,
    input wire dbg_mode,

    // Outputs
    output wire cnt_en,
    output wire halt_ack_status
);

    // --- Halt Logic ---
    assign halt_ack_status = halt_req && dbg_mode;

    // --- Divisor Counter Logic ---
    reg  [7:0] divisor_counter;
    wire [7:0] limit;
    wire       is_limit;

    // Combinational logic to calculate the limit
    assign limit = (1 << div_val) - 1;

    // The counter for the divisor
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            divisor_counter <= 8'd0;
        end else if (!timer_en || !div_en || is_limit) begin
            divisor_counter <= 8'd0;
        end else begin
            divisor_counter <= divisor_counter + 1;
        end
    end

    // The comparator
    assign is_limit = (divisor_counter == limit);

    // --- Final cnt_en Generation Logic ---
    wire cnt_en_pre_halt;

    // MUX to select between default mode and control mode
    assign cnt_en_pre_halt = div_en ? (timer_en && is_limit) : timer_en;
    
    // Final gate to ensure halt stops the counter
    assign cnt_en = cnt_en_pre_halt && !halt_ack_status;

endmodule

module apb_slave (
    // System Signals
    input wire sys_clk,
    input wire sys_rst_n,

    // APB Interface
    input wire tim_psel,
    input wire tim_pwrite,
    input wire tim_penable,
    output wire tim_pready,
    output wire tim_pslverr,

    // Internal Interface
    input wire reg_error_flag,
    output wire wr_en,
    output wire rd_en
);
    // FSM State Definitions
    localparam [1:0] IDLE   = 2'b00;
    localparam [1:0] SETUP  = 2'b01;
    localparam [1:0] ACCESS = 2'b10;

    // State Registers
    reg [1:0] current_state_reg;
    reg [1:0] next_state;

    // State Register Update
    always @(posedge sys_clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            current_state_reg <= IDLE;
        end else begin
            current_state_reg <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = current_state_reg;
        case (current_state_reg)
            IDLE:   if (tim_psel) next_state = SETUP;
            SETUP:  if (tim_penable) next_state = ACCESS;
                    else if (!tim_psel) next_state = IDLE; // Abort
            ACCESS: if (tim_pready) next_state = IDLE; // Transaction complete
        endcase
    end

    // Output Logic
    assign tim_pready  = (current_state_reg == ACCESS) && tim_penable && tim_psel;
    
    assign wr_en = tim_pready && tim_pwrite;
    assign rd_en = tim_pready && !tim_pwrite;

    assign tim_pslverr = tim_pready && reg_error_flag;

endmodule

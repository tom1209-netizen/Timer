module timer_top (
    // System Signals
    input wire          sys_clk,
    input wire          sys_rst_n,

    // APB Slave Interface
    input wire          tim_psel,
    input wire          tim_pwrite,
    input wire          tim_penable,
    input wire [11:0]   tim_paddr,
    input wire [31:0]   tim_pwdata,
    input wire [3:0]    tim_pstrb,
    output wire         tim_pready,
    output wire [31:0]  tim_prdata,
    output wire         tim_pslverr,

    // Interrupt Output
    output wire         tim_int,   

    // Debug Input
    input wire          dbg_mode
);
    // APB Slave to Register Block
    wire wr_en;
    wire rd_en;
    wire reg_error_flag;

    // Register Block to Counter Control Block
    wire        timer_en;
    wire        div_en;
    wire [3:0]  div_val;
    wire        halt_req;

    // Register Block to Counter Block
    wire [1:0]  counter_write_sel;
    wire [31:0] counter_write_data;
    wire        counter_clear;

    // Register Block to Interrupt Logic Block
    wire [63:0] compare_val;
    wire        interrupt_en;
    wire        interrupt_clear;

    // Counter Control Block to Counter Block
    wire cnt_en;
    
    // Counter Control Block to Register Block
    wire halt_ack_status;

    // Counter Block to Register Block & Interrupt Logic Block
    wire [63:0] cnt_val;
    
    // Interrupt Logic Block to Register Block
    wire interrupt_status;

    apb_slave u_apb_slave (
        .sys_clk(sys_clk),
        .sys_rst_n(sys_rst_n),
        .tim_psel(tim_psel),
        .tim_pwrite(tim_pwrite),
        .tim_penable(tim_penable),
        .reg_error_flag(reg_error_flag),
        .wr_en(wr_en),
        .rd_en(rd_en),
        .tim_pslverr(tim_pslverr),
        .tim_pready(tim_pready)
    );

    register u_register (
        .sys_clk(sys_clk),
        .sys_rst_n(sys_rst_n),
        .wr_en(wr_en),
        .rd_en(rd_en),
        .tim_paddr(tim_paddr),
        .tim_pwdata(tim_pwdata),
        .tim_pstrb(tim_pstrb),
        .halt_ack_status(halt_ack_status),
        .cnt_val(cnt_val),
        .interrupt_status(interrupt_status),
        .reg_error_flag(reg_error_flag),
        .timer_en(timer_en),
        .div_en(div_en),
        .div_val(div_val),
        .halt_req(halt_req),
        .counter_write_sel(counter_write_sel),
        .counter_write_data(counter_write_data),
        .counter_clear(counter_clear),
        .compare_val(compare_val),
        .interrupt_en(interrupt_en),
        .interrupt_clear(interrupt_clear),
        .tim_prdata(tim_prdata)
    );

    counter_control u_counter_control (
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

    counter u_counter (
        .sys_clk(sys_clk),
        .sys_rst_n(sys_rst_n),
        .counter_write_sel(counter_write_sel),
        .counter_write_data(counter_write_data),
        .counter_clear(counter_clear),
        .cnt_en(cnt_en),
        .cnt_val(cnt_val)
    );

    interrupt u_interrupt_logic (
        .sys_clk(sys_clk),
        .sys_rst_n(sys_rst_n),
        .compare_val(compare_val),
        .interrupt_en(interrupt_en),
        .interrupt_clear(interrupt_clear),
        .cnt_val(cnt_val),
        .interrupt_status(interrupt_status),
        .tim_int(tim_int)
    );

endmodule

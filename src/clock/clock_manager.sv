module ClockManager #(
    parameter clock_config_t CLK_DISPLAY,
    parameter clock_config_t CLK_SYSTEM
)(
    input logic clk_ext,
    input logic reset,

    output logic clk_system,
    output logic rstn_system,

    output logic clk_display,
    output logic rstn_display
);
    // TODO: proper async -> rstn
    logic rstn;
    assign rstn = ~reset;

    logic clk;
    BUFG bufg_ext_clk_inst (
        .I(clk_ext),

        .O(clk)
    );

    // VGA clock
    Clock #(
        .CLOCK_CONFIG(CLK_DISPLAY)
    ) clock_display_inst (
        .clk_in(clk),
        .rstn_in(rstn),

        .clk_out(clk_display),
        .rstn_out(rstn_display)
    );

    // System clock
    Clock #(
        .CLOCK_CONFIG(CLK_SYSTEM)
    ) clk_system_inst (
        .clk_in(clk),
        .rstn_in(rstn),

        .clk_out(clk_system),
        .rstn_out(rstn_system)
    );

endmodule
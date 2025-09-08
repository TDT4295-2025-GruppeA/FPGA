

module ClockManager #(
    parameter clock_config_t CLK_DISPLAY
)(
    input logic clk_ext,
    input logic reset,

    output logic clk_display,
    output logic rstn_display
);
    // TODO: proper async -> rstn
    logic rstn;
    assign rstn = ~reset;

    // VGA clock
    Clock #(
        .CLOCK_CONFIG(CLK_DISPLAY)
    ) clock_vga_inst (
        .clk_in(clk_ext),
        .rstn_in(rstn),

        .clk_out(clk_display),
        .rstn_out(rstn_display)
    );
endmodule
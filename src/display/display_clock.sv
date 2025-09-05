// Inspired by projectf
// https://github.com/projf/projf-explore/blob/main/lib/clock/xc7/clock_480p.sv


module DisplayClock #(
    parameter real MASTER_MULTIPLY, // Master multiplier (float 2.000 - 64.000) (step: 0.125)
    parameter unsigned MASTER_DIVIDE, // Master divisor (uint 1 - 106)
    parameter real CLK_DIVIDE_F // Divisor for clock 0 (float 1.000 - 128.000)
) (
    input logic clk_100m,
    input logic rstn,

    output logic pixel_clk,
    output logic pixel_clk_rstn
);
    localparam real CLK_PERIOD = 10.0; // input clock period in nanoseconds (0.000 - 100.000)

    logic feedback;
    logic pixel_clk_unbuf;
    logic locked;

    MMCME2_BASE #(
        .CLKFBOUT_MULT_F(MASTER_MULTIPLY),
        .DIVCLK_DIVIDE(MASTER_DIVIDE),
        .CLKIN1_PERIOD(CLK_PERIOD),
        .CLKOUT0_DIVIDE_F(CLK_DIVIDE_F)
    ) clock_inst (
        .CLKIN1(clk_100m),
        .RST(~rstn),
        .CLKFBIN(feedback),

        .CLKOUT0(pixel_clk_unbuf),
        .LOCKED(locked),
        .CLKFBOUT(feedback)
    );

    BUFG buf_clk(
        .I(pixel_clk_unbuf),

        .O(pixel_clk)
    );

    // Generate clock reset signal
    logic[1:0] sync;
    always_ff @(posedge pixel_clk or negedge rstn) begin
        if (!rstn) begin
            sync <= 2'b00;
        end else if (!locked) begin
            sync <= 2'b00;
        end else begin
            sync <= {sync[0], 1'b1};
        end
    end

    assign pixel_clk_rstn = sync[1];

endmodule
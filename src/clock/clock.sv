import fixed_pkg::*;
import clock_modes_pkg::*;

module Clock #(
    parameter clock_config_t CLOCK_CONFIG
) (
    input logic clk_in,
    input logic rstn_in,

    output logic clk_out,
    output logic rstn_out
);
    // clock period in nanoseconds
    localparam real CLK_PERIOD = ftor(CLOCK_CONFIG.clk_input_period);
    localparam real MASTER_MULTIPLY = ftor(CLOCK_CONFIG.master_mul);
    localparam int MASTER_DIVIDE = CLOCK_CONFIG.master_div;
    localparam real CLK_DIVIDE_F = ftor(CLOCK_CONFIG.clk_div_f);

    logic feedback;
    logic clk_out_unbuf;
    logic locked;

    MMCME2_BASE #(
        .CLKFBOUT_MULT_F(MASTER_MULTIPLY),
        .DIVCLK_DIVIDE(MASTER_DIVIDE),
        .CLKIN1_PERIOD(CLK_PERIOD),
        .CLKOUT0_DIVIDE_F(CLK_DIVIDE_F)
    ) clock_inst (
        .CLKIN1(clk_in),
        .RST(~rstn_in),
        .CLKFBIN(feedback),

        .CLKOUT0(clk_out_unbuf),
        .LOCKED(locked),
        .CLKFBOUT(feedback)
    );

    BUFG buf_clk(
        .I(clk_out_unbuf),

        .O(clk_out)
    );

    // Generate clock reset signal
    logic[1:0] sync;
    always_ff @(posedge clk_out or negedge rstn_in) begin
        if (!rstn_in) begin
            sync <= 2'b00;
        end else if (!locked) begin
            sync <= 2'b00;
        end else begin
            sync <= {sync[0], 1'b1};
        end
    end

    assign rstn_out = sync[1];

endmodule
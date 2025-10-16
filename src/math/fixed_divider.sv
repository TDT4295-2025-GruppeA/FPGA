// Uses Vivado's built-in divider IP to perform fixed-point division.
module FixedDivider (
    input logic clk,
    input logic operands_valid,
    input fixed dividend,
    input fixed divisor,
    output logic ready,
    output logic result_valid,
    output fixed result
);
    logic dividend_ready, divisor_ready;

    // Sizes are hardcoded as the IP core is generated
    // with fixed sized inputs and outputs.
    logic [47:0] dividend_data;
    logic [31:0] divisor_data;
    logic [47:0] result_data;

    Divider divider (
        .aclk(clk),
        .s_axis_divisor_tvalid(operands_valid),
        .s_axis_divisor_tready(divisor_ready),
        .s_axis_divisor_tdata(divisor_data),
        .s_axis_dividend_tvalid(operands_valid),
        .s_axis_dividend_tready(dividend_ready),
        .s_axis_dividend_tdata(dividend_data),
        .m_axis_dout_tvalid(result_valid),
        .m_axis_dout_tdata(result_data)
    );

    // I would presume divident_ready and divisor_ready
    // are always the same, but just to be safe we are
    // only ready once both are ready.
    assign ready = dividend_ready & divisor_ready;
    // Left shift dividend to 64 bits to perserve
    // decimal point posiiton after division.
    assign dividend_data = {dividend, 16'b0};
    // Divisor and output have the same width as
    // out fixed point type so no shift needed.
    assign divisor_data = divisor;
    // Truncate result to fit in fixed type.
    assign result = fixed'(result_data);
endmodule

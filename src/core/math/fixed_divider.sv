import fixed_pkg::*;

// Uses Vivado's built-in divider IP to perform fixed-point division.
module FixedDivider (
    input logic clk,
    
    output logic dividend_s_ready,
    input logic dividend_s_valid,
    input fixed dividend_s_data,

    output logic divisor_s_ready,
    input logic divisor_s_valid,
    input fixed divisor_s_data,

    input logic result_m_ready,
    output logic result_m_valid,
    output fixed result_m_data
);
    // Sizes are hardcoded as the IP core is generated
    // with fixed sized inputs and outputs.
    logic [47:0] internal_dividend_data;
    logic [31:0] internal_divisor_data;
    logic [47:0] internal_result_data;

    Divider divider (
        .aclk(clk),
        
        .s_axis_dividend_tready(dividend_s_ready),
        .s_axis_dividend_tvalid(dividend_s_valid),
        .s_axis_dividend_tdata(internal_dividend_data),
        
        .s_axis_divisor_tready(divisor_s_ready),
        .s_axis_divisor_tvalid(divisor_s_valid),
        .s_axis_divisor_tdata(internal_divisor_data),
        
        .m_axis_dout_tready(result_m_ready),
        .m_axis_dout_tvalid(result_m_valid),
        .m_axis_dout_tdata(internal_result_data)
    );

    // Left shift dividend to 64 bits to preserve
    // decimal point position after division.
    assign internal_dividend_data = 48'(dividend_s_data <<< STANDARD_FRACTIONAL_BITS);
    // Divisor and output have the same width as
    // out fixed point type so no shift needed.
    assign internal_divisor_data = 32'(divisor_s_data);
    // Truncate result to fit in fixed type.
    assign result_m_data = fixed'(internal_result_data);
endmodule

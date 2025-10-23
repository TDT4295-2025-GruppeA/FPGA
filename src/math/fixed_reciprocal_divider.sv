import fixed_pkg::*;

// Uses Vivado's built-in divider IP to perform fixed-point division.
module FixedReciprocalDivider (
    input logic clk,

    output logic divisor_s_ready,
    input logic divisor_s_valid,
    input fixed divisor_s_data,

    input logic result_m_ready,
    output logic result_m_valid,
    output fixed result_m_data
);
    // Sizes are hardcoded as the IP core is generated
    // with fixed sized inputs and outputs.
    logic [16:0] internal_dividend_data;
    logic [31:0] internal_divisor_data;
    logic [23:0] internal_result_data;
    
    ReciprocalDivider divider (
        .aclk(clk),
        
        .s_axis_dividend_tready(),
        .s_axis_dividend_tvalid(1'b1),
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
    assign internal_dividend_data = {1'b1, 16'b0};
    // Divisor and output have the same width as
    // out fixed point type so no shift needed.
    assign internal_divisor_data = 32'(divisor_s_data);
    // Truncate result to fit in fixed type.
    assign result_m_data = fixed'(internal_result_data);
endmodule

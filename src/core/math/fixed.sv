// This file defines a type for fixed point numbers,
// functions to convert between fixed point and real/int,
// and functions for basic arithmetic operations.

// For all cases where precision is lost, rounding 
// shall be done in stead of truncation.

package fixed_pkg;
    localparam int STANDARD_FRACTIONAL_BITS = 14;
    localparam int PIXEL_FRACTIONAL_BITS = 3;
    localparam int PRECISION_FRACTIONAL_BITS = 20;
    localparam int TOTAL_WIDTH = 25;

    typedef logic signed [TOTAL_WIDTH-1:0] fixed;
    typedef logic signed [31:0] fixed_q16x16;
    typedef fixed fixed_q11x14;

    typedef logic signed [(TOTAL_WIDTH*2)-1:0] double;

    //////////////////////////
    // Conversion Functions //
    //////////////////////////

    // These functions are named to follow the convention
    // of the existin functions in SystemVerilog. 

    function automatic fixed rtof(real r, int decimal_width = STANDARD_FRACTIONAL_BITS);
        return fixed'(r * (1 << decimal_width));
    endfunction

    function automatic real ftor(fixed f, int decimal_width = STANDARD_FRACTIONAL_BITS);
        return real'(f) / real'(1 << decimal_width);
    endfunction

    function automatic int ftoi(fixed f, int decimal_width = STANDARD_FRACTIONAL_BITS);
        // Add a bias to round to nearest integer in stead of just truncating.
        fixed bias = 1 <<< (decimal_width - 1);
        // If number is negative, the bias will need to be subtracted.
        fixed signed_bias = f[TOTAL_WIDTH-1] ? -bias : bias;
        fixed rounded = f + signed_bias;
        
        return int'(rounded) >>> decimal_width;
    endfunction

    function automatic fixed itof(int i, int decimal_width = STANDARD_FRACTIONAL_BITS);
        return fixed'(i <<< decimal_width);
    endfunction

    ///////////////////////////
    // Arithmetic Operations //
    ///////////////////////////

    // The add and sub functions are not really necessary,
    // but we define them for consistency. It is also
    // easier to change the implementation later if needed.

    function automatic fixed add(fixed lhs, fixed rhs);
        return lhs + rhs;
    endfunction

    function automatic fixed sub(fixed lhs, fixed rhs);
        return lhs - rhs;
    endfunction

    function automatic fixed mul(fixed lhs, fixed rhs, int decimal_width = STANDARD_FRACTIONAL_BITS);
        // Store intermediate result in wider type to avoid overflow.
        double wide_result = double'(lhs) * double'(rhs);
        return fixed'(wide_result >>> decimal_width);
    endfunction

    // NOTE: This function is currently not used and we should
    // figure out if we need a more advanced/efficient division
    // algortihm than what SystemVerilog synthesizes.
    function automatic fixed div(fixed lhs, fixed rhs, int decimal_width = STANDARD_FRACTIONAL_BITS);
        // Store numerator in wider type to avoid overflow.
        // Denominator must match the width of numerator.
        double numerator = double'(lhs) <<< decimal_width;
        double denominator = double'(rhs);

        return fixed'(numerator / denominator);
    endfunction

    ///////////////////////
    // Utility Functions //
    ///////////////////////

    function automatic fixed cast_precision(fixed value, int from_decimal_width, int to_decimal_width);
        if (to_decimal_width > from_decimal_width) begin
            return value <<< (to_decimal_width - from_decimal_width);
        end else begin
            return value >>> (from_decimal_width - to_decimal_width);
        end
    endfunction

    function automatic fixed_q11x14 cast_q16x16_q11x14(fixed_q16x16 in);
        localparam DELTA_DECIMAL_WIDTH = 2;
        return fixed_q11x14'(in >>> DELTA_DECIMAL_WIDTH);
    endfunction

    function automatic fixed clamp(fixed value, fixed min, fixed max);
        if (value < min) begin
            return min;
        end else if (value > max) begin
            return max;
        end else begin
            return value;
        end
    endfunction
endpackage

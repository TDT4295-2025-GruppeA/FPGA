// This file defines a type for fixed point numbers,
// functions to convert between fixed point and real/int,
// and functions for basic arithmetic operations.

// For all cases where precision is lost, rounding 
// shall be done in stead of truncation.

package fixed_pkg;
    localparam int DECIMAL_WIDTH = 14;
    localparam int TOTAL_WIDTH = 25;

    typedef logic signed [TOTAL_WIDTH-1:0] fixed;
    typedef logic signed [31:0] fixed_q16x16;
    typedef fixed fixed_q11x14;

    //////////////////////////
    // Conversion Functions //
    //////////////////////////

    // These functions are named to follow the convention
    // of the existin functions in SystemVerilog. 

    function automatic fixed rtof(real r);
        return fixed'(r * (1 << DECIMAL_WIDTH));
    endfunction

    function automatic real ftor(fixed f);
        return real'(f) / real'(1 << DECIMAL_WIDTH);
    endfunction

    function automatic int ftoi(fixed f);
        // Add a bias to round to nearest integer in stead of just truncating.
        fixed bias = 1 <<< (DECIMAL_WIDTH - 1);
        // If number is negative, the bias will need to be subtracted.
        fixed signed_bias = f[TOTAL_WIDTH-1] ? -bias : bias;
        fixed rounded = f + signed_bias;
        
        return int'(rounded) >>> DECIMAL_WIDTH;
    endfunction

    function automatic fixed itof(int i);
        return fixed'(i <<< DECIMAL_WIDTH);
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

    function automatic fixed mul(fixed lhs, fixed rhs);
        // Store intermediate result in wider type to avoid overflow.
        typedef logic signed [(TOTAL_WIDTH*2)-1:0] double;
        double wide_result = double'(lhs) * double'(rhs);
        return fixed'(wide_result >>> DECIMAL_WIDTH);
    endfunction

    // NOTE: This function is currently not used and we should
    // figure out if we need a more advanced/efficient division
    // algortihm than what SystemVerilog synthesizes.
    function automatic fixed div(fixed lhs, fixed rhs);
        // Store numerator in wider type to avoid overflow.
        // Denominator must match the width of numerator.
        typedef logic signed [TOTAL_WIDTH+DECIMAL_WIDTH-1:0] extended;
        
        extended numerator = {lhs, {DECIMAL_WIDTH{1'b0}}};
        extended denominator = extended'(rhs);

        return fixed'(numerator / denominator);
    endfunction

    function automatic fixed_q11x14 cast_q16x16_q11x14(fixed_q16x16 in);
        localparam DELTA_DECIMAL_WIDTH = 2;
        return fixed_q11x14'(in >>> DELTA_DECIMAL_WIDTH);
    endfunction
endpackage

// This file defines a type for fixed point numbers,
// functions to convert between fixed point and real/int,
// and functions for basic arithmetic operations.

package fixed_pkg;
    localparam int DECIMAL_WIDTH = 16;
    localparam int TOTAL_WIDTH = 32;

    typedef logic signed [TOTAL_WIDTH-1:0] fixed;

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
        return int'(f >>> DECIMAL_WIDTH);
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
        localparam DOUBLE_WIDTH = TOTAL_WIDTH * 2;
        logic signed [DOUBLE_WIDTH-1:0] wide_result;
        wide_result = (DOUBLE_WIDTH)'(lhs) * (DOUBLE_WIDTH)'(rhs);
        return fixed'(wide_result >>> DECIMAL_WIDTH);
    endfunction

    function automatic fixed div(fixed lhs, fixed rhs);
        // Store numerator in wider type to avoid overflow.
        logic signed [TOTAL_WIDTH+DECIMAL_WIDTH-1:0] numerator;
        // Denominator must match the width of numerator.
        logic signed [TOTAL_WIDTH+DECIMAL_WIDTH-1:0] denominator;
        numerator = {lhs, {DECIMAL_WIDTH{1'b0}}};
        denominator = (DECIMAL_WIDTH+TOTAL_WIDTH)'(rhs);
        return fixed'(numerator / denominator);
    endfunction
endpackage

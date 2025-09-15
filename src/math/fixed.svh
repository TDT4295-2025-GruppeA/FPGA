`ifndef FIXED_H
`define FIXED_H

localparam DECIMAL_WIDTH = 16;
localparam TOTAL_WIDTH = 32;

// Used to avoid overflow in multiplication
localparam DOUBLE_WIDTH = TOTAL_WIDTH * 2;


typedef logic signed [TOTAL_WIDTH-1:0] fixed;

// FADD and FSUB are not realy necessary,
// but we define them for consistency.
// It is also easier to change the implementation later if needed.
`define ADD(l, r) ((l) + (r))
`define SUB(l, r) ((l) - (r))
// Cast to wider type to avoid overflow before shifting
`define MUL(l, r) (fixed'(((DOUBLE_WIDTH)'(l) * (DOUBLE_WIDTH)'(r)) >>> DECIMAL_WIDTH))
// Left shift the numerator to preserve the decimal point
// Expand the denominator to make operands have the same width
`define DIV(l, r) (fixed'(signed'({l, {DECIMAL_WIDTH{1'b0}}}) / signed'((DECIMAL_WIDTH+TOTAL_WIDTH)'(r))))

// Convert real/integer to fixed
`define F(r) (fixed'((r) * (1 << DECIMAL_WIDTH)))
// Convert fixed to real
`define R(f) ((f) / real'(1 << DECIMAL_WIDTH))
// Convert fixed to integer (floor)
`define I(f) ((f) >>> DECIMAL_WIDTH)

`endif // FIXED_H

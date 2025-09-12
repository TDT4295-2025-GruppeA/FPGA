localparam DECIMAL_WIDTH = 24;
localparam TOTAL_WIDTH = 64;

typedef logic signed [TOTAL_WIDTH-1:0] fixed;

// FADD and FSUB are not realy necessary,
// but we define them for consistency.
// It is also easier to change the implementation later if needed.
`define ADD(l, r) ((l) + (r))
`define SUB(l, r) ((l) - (r))
`define MUL(l, r) (((TOTAL_WIDTH*2)'(l) * (TOTAL_WIDTH*2)'(r)) >>> DECIMAL_WIDTH)
`define DIV(l, r) (signed'({l, {DECIMAL_WIDTH{1'b0}}}) / signed'(r))

// Convert fixed to integer (floor)
`define FIXED_TO_INTEGER(f) (int'(f) >>> DECIMAL_WIDTH)
// Convert integer to fixed
`define ITOF(i) (fixed'(i) <<< DECIMAL_WIDTH)

// Convert real to fixed
`define F(f) (fixed'(f * real'(1 << DECIMAL_WIDTH)))
// Convert fixed to real
`define R(f) ((f) / real'(1 << DECIMAL_WIDTH))

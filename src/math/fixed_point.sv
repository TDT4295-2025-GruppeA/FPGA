localparam DECIMAL_WIDTH = 16;
localparam TOTAL_WIDTH = 32;

typedef logic signed [TOTAL_WIDTH-1:0] fixed;

// FADD and FSUB are not realy necessary,
// but we define them for consistency.
// It is also easier to change the implementation later if needed.
`define FADD(l, r) (l + r)
`define FSUB(l, r) (l - r)
`define FMUL(l, r) ((`TOTAL_WIDTH*2)'(l) * (`TOTAL_WIDTH*2)'(r)) >>> DECIMAL_WIDTH
`define FDIV(l, r) ({l, {DECIMAL_WIDTH{1'b0}}} / r)

`define FTOI(f) (f >>> DECIMAL_WIDTH)
`define ITOF(i) (i <<< DECIMAL_WIDTH)

`define F(f) (f * (1 << DECIMAL_WIDTH))

`include "src/math/fixed.svh"
`include "src/math/linalg.svh"

module Cross (
    input `VECTOR(3, l),
    input `VECTOR(3, r),
    output `VECTOR(3, o)
);
    always_comb begin
        o[0] = `SUB(`MUL(l[1], r[2]), `MUL(l[2], r[1]));
        o[1] = `SUB(`MUL(l[2], r[0]), `MUL(l[0], r[2]));
        o[2] = `SUB(`MUL(l[0], r[1]), `MUL(l[1], r[0]));
    end
endmodule

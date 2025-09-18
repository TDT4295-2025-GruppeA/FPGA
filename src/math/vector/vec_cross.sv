import fixed_pkg::*;

module VecCross (
    input fixed lhs [3],
    input fixed rhs [3],
    output fixed out [3]
);
    always_comb begin
        out[0] = sub(mul(lhs[1], rhs[2]), mul(lhs[2], rhs[1]));
        out[1] = sub(mul(lhs[2], rhs[0]), mul(lhs[0], rhs[2]));
        out[2] = sub(mul(lhs[0], rhs[1]), mul(lhs[1], rhs[0]));
    end
endmodule

`include "src/math/fixed.svh"

module FixedTB (
    input real a,
    input real b,
    output real sum,
    output real sub,
    output real mul,
    output real div
);
    fixed a_fixed;
    fixed b_fixed;

    fixed sum_fixed;
    fixed sub_fixed;
    fixed mul_fixed;
    fixed div_fixed;

    assign a_fixed = `F(a);
    assign b_fixed = `F(b);

    assign sum_fixed = `ADD(a_fixed, b_fixed);
    assign sub_fixed = `SUB(a_fixed, b_fixed);
    assign mul_fixed = `MUL(a_fixed, b_fixed);
    assign div_fixed = `DIV(a_fixed, b_fixed);

    assign sum = `R(sum_fixed);
    assign sub = `R(sub_fixed);
    assign mul = `R(mul_fixed);
    assign div = `R(div_fixed);
endmodule
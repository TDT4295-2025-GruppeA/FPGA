import fixed_pkg::*;

module FixedTB (
    input real a,
    input real b,
    output real sum,
    output real diff,
    output real prod,
    output real quot
);
    fixed a_fixed;
    fixed b_fixed;

    fixed sum_fixed;
    fixed diff_fixed;
    fixed prod_fixed;
    fixed quot_fixed;

    assign a_fixed = rtof(a);
    assign b_fixed = rtof(b);

    assign sum_fixed = add(a_fixed, b_fixed);
    assign diff_fixed = sub(a_fixed, b_fixed);
    assign prod_fixed = mul(a_fixed, b_fixed);
    assign quot_fixed = div(a_fixed, b_fixed);

    assign sum = ftor(sum_fixed);
    assign diff = ftor(diff_fixed);
    assign prod = ftor(prod_fixed);
    assign quot = ftor(quot_fixed);
endmodule

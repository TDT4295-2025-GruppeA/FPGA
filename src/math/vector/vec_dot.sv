import fixed_pkg::*;

module VecDot #(
    parameter int N = 3
) (
    input fixed lhs [N],
    input fixed rhs [N],
    output fixed out
);
    integer i;

    always_comb begin
        out = 0;
        for (i = 0; i < N; i++) begin
            out += mul(lhs[i], rhs[i]);
        end
    end
endmodule

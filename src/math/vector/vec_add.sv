import fixed_pkg::*;

module VecAdd #(
    parameter int N = 3
) (
    input fixed lhs [N],
    input fixed rhs [N],
    output fixed out [N]
);
    always_comb begin
        for (int i = 0; i < N; i++) begin
            out[i] = add(lhs[i], rhs[i]);
        end
    end
endmodule

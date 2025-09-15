`include "src/math/fixed.svh"
`include "src/math/linalg.svh"

module Sub #(
    parameter int N = 3
) (
    input `VECTOR(N, l),
    input `VECTOR(N, r),
    output `VECTOR(N, o)
);
    always_comb begin
        for (int i = 0; i < N; i++) begin
            o[i] = `SUB(l[i], r[i]);
        end
    end
endmodule

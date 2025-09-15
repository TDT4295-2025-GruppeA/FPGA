`include "src/math/fixed.svh"
`include "src/math/linalg.svh"

module Dot #(
    parameter int N = 3
) (
    input `VECTOR(N, l),
    input `VECTOR(N, r),
    output fixed o
);
    integer i;

    always_comb begin
        o = 0;
        for (i = 0; i < N; i++) begin
            o += `MUL(l[i], r[i]);
        end
    end
endmodule

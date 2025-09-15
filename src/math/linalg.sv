
`include "src/math/fixed.svh"
`include "src/math/linalg.svh"

module MatMul #(
    parameter int M = 3,
    parameter int K = 3,
    parameter int N = 3
)(
    input `MATRIX(M, K, l),
    input `MATRIX(K, N, r),
    output `MATRIX(M, N, o)
);
    integer i, j, k;

    always_comb begin
        for (i = 0; i < M; i++) begin
            for (j = 0; j < N; j++) begin
                o[i][j] = 0;
                for (k = 0; k < K; k++) begin
                    o[i][j] += `MUL(l[i][k], r[k][j]);
                end
            end
        end
    end
endmodule

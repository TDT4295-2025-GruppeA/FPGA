import fixed_pkg::*;

module MatMul #(
    parameter int M = 3,
    parameter int K = 3,
    parameter int N = 3
) (
    input fixed lhs [M][K],
    input fixed rhs [K][N],
    output fixed out [M][N]
);
    integer i, j, k;

    always_comb begin
        for (i = 0; i < M; i++) begin
            for (j = 0; j < N; j++) begin
                out[i][j] = 0;
                for (k = 0; k < K; k++) begin
                    out[i][j] += mul(lhs[i][k], rhs[k][j]);
                end
            end
        end
    end
endmodule

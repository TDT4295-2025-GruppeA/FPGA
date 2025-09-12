
`define MATRIX(rows, cols, name) fixed name [0:rows-1][0:cols-1]

`define VECTOR(dim, name) `MATRIX(dim, 1, name)
`ifdef WIP
module Add #(
    parameter int M = 3,
    parameter int N = 1
)(
    input `MATRIX(M, N, l),
    input `MATRIX(M, N, r),
    output `MATRIX(M, N, o)
);
    genvar i, j;
    generate
        for (i = 0; i < M; i++) begin : row_loop
            for (j = 0; j < N; j++) begin : col_loop
                assign o[i][j] = l[i][j] + r[i][j];
            end
        end
    endgenerate
endmodule

// Cross products are only defined for 3D
// (and 7D, but who needs that)
module Cross (
    input `VECTOR(3, l),
    input `VECTOR(3, r),
    output `VECTOR(3, o)
);
    assign o[0] = l[1]*r[2] - l[2]*r[1];
    assign o[1] = l[2]*r[0] - l[0]*r[2];
    assign o[2] = l[0]*r[1] - l[1]*r[0];
endmodule

module Dot #(
    parameter int N = 3,
) (
    input `VECTOR(N, l),
    input `VECTOR(N, r),
    output fixed o
);
    assign o = '0;
    genvar i;
    generate
        for (i = 0; i < N; i++) begin : dot_loop
            assign o += l[i] * r[i];
        end
    endgenerate
endmodule

module ScaMul #(
    parameter int M = 3,
    parameter int N = 1
)(
    input fixed l,
    input `MATRIX(M, N, r),
    output `MATRIX(M, N, o)
);
    genvar i, j;
    generate
        for (i = 0; i < M; i++) begin : row_loop
            for (j = 0; j < N; j++) begin : col_loop
                assign o[i][j] = l * r[i][j];
            end
        end
    endgenerate
endmodule

module MatMul #(
    parameter int M = 3,
    parameter int K = 3,
    parameter int N = 3
)(
    input `MATRIX(M, K, l),
    input `MATRIX(K, N, r),
    output `MATRIX(M, N, o)
);
    genvar i, j, k;
    generate
        for (i = 0; i < M; i++) begin : row_loop
            for (j = 0; j < N; j++) begin : col_loop
                assign o[i][j] = '0;
                for (k = 0; k < K; k++) begin : sum_loop
                    assign o[i][j] += l[i][k] * r[k][j];
                end
            end
        end
    endgenerate
endmodule

module T #(
    parameter int M = 3,
    parameter int N = 1
)(
    input `MATRIX(M, N, i),
    output `MATRIX(N, M, o)
)
    genvar i, j;
    generate
        for (i = 0; i < M; i++) begin : row_loop
            for (j = 0; j < N; j++) begin : col_loop
                assign o[j][i] = i[i][j];
            end
        end
    endgenerate
endmodule

module Inv #(
    parameter int N = 3
)(
    input `MATRIX(N, N, i),
    output `MATRIX(N, N, o)
);
    
endmodule
`endif
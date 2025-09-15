`ifndef LINALG_H
`define LINALG_H

`define MATRIX(rows, cols, name) fixed name [0:rows-1][0:cols-1]

`define VECTOR(dim, name) `MATRIX(dim, 1, name)

`endif // LINALG_H

// Formula retrieved from https://en.wikipedia.org/wiki/Gray_code#Converting_to_and_from_Gray_code
module BinaryToGray #(
    parameter int WIDTH = 8
) (
    input logic [WIDTH-1:0] binary,
    output logic [WIDTH-1:0] gray
);
    assign gray = binary ^ (binary >> 1);
endmodule

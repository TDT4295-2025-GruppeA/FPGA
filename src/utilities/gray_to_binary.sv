// Copied from https://vlsiverify.com/verilog/verilog-codes/gray-to-binary/
module GrayToBinary #(
    parameter int WIDTH = 8
) (
    input logic [WIDTH-1:0] gray,
    output logic [WIDTH-1:0] binary
);
    genvar i;
    generate
        for(i = 0; i < WIDTH; i++) begin
            assign binary[i] = ^(gray >> i);
        end
    endgenerate
endmodule

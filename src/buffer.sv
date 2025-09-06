module Buffer #(
    parameter string FILE_SOURCE
)(
    input logic clk,
    input logic rstn,
    input logic[31:0] addr, // TODO: variable size
    output logic[11:0] data
);

    logic[11:0] memory[640 * 480];

    initial begin
        $readmemh(FILE_SOURCE, memory);
    end

    always_ff @(posedge clk) begin
        data <= memory[addr];
    end

endmodule
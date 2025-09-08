module Buffer #(
    parameter string FILE_SOURCE,
    parameter int FILE_SIZE = 640*480
)(
    input logic clk,
    input logic rstn,
    input logic[31:0] addr, // TODO: variable size
    output logic[11:0] data
);

    logic[11:0] memory[FILE_SIZE];

    initial begin
        $readmemh(FILE_SOURCE, memory);
    end

    always_ff @(posedge clk) begin
        data <= memory[addr];
    end

endmodule
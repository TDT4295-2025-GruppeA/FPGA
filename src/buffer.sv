module Buffer #(
    parameter string FILE_SOURCE,
    parameter int FILE_SIZE = 640*480,
    parameter int DATA_WIDTH = 12,
    parameter int ADDR_WIDTH = $clog2(FILE_SIZE)
)(
    input logic clk,
    input logic rstn,
    input logic[ADDR_WIDTH-1:0] addr,
    output logic[DATA_WIDTH-1:0] data
);

    (* ram_style = "block" *) logic[DATA_WIDTH-1:0] memory[FILE_SIZE];

    initial begin
        $readmemh(FILE_SOURCE, memory);
    end

    always_ff @(posedge clk) begin
        data <= memory[addr];
    end

endmodule
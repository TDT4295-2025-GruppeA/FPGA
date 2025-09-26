module Buffer #(
    parameter string FILE_SOURCE = "static/foreleser_320x240p12.mem",
    parameter int FILE_SIZE = 640*480
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
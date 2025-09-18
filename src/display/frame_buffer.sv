module FrameBuffer #(
    parameter int BUFFER_SIZE = 640*480,
    parameter int DATA_WIDTH = 12,
    parameter int ADDR_WIDTH = $clog2(BUFFER_SIZE)
)(
    input logic clk,
    input logic rstn,
    
    input logic[ADDR_WIDTH-1:0] read_addr,
    output logic[DATA_WIDTH-1:0] read_data,

    input logic write_en,
    input logic[ADDR_WIDTH-1:0] write_addr,
    input logic[DATA_WIDTH-1:0] write_data
);

    (* ram_style = "block" *) logic[DATA_WIDTH-1:0] memory[BUFFER_SIZE];

    always_ff @(posedge clk) begin
        read_data <= memory[read_addr];

        if (write_en) begin
            memory[write_addr] <= write_data;
        end
    end

    initial begin
        for (int i = 0; i < BUFFER_SIZE; i++) begin
            memory[i] = 12'h000; // Initialize memory to black
        end
    end

endmodule
import buffer_config_pkg::*;

module FrameBuffer #(
    parameter buffer_config_t BUFFER_CONFIG = BUFFER_160x120x12
)(
    input logic clk,
    input logic rstn,
    
    input logic[BUFFER_CONFIG.addr_width-1:0] read_addr,
    output logic[BUFFER_CONFIG.data_width-1:0] read_data,

    input logic write_en,
    input logic[BUFFER_CONFIG.addr_width-1:0] write_addr,
    input logic[BUFFER_CONFIG.data_width-1:0] write_data
);
    localparam int BUFFER_SIZE = BUFFER_CONFIG.width * BUFFER_CONFIG.height;

    (* ram_style = "block" *) logic[BUFFER_CONFIG.data_width-1:0] memory[BUFFER_SIZE];

    always_ff @(posedge clk) begin
        read_data <= memory[read_addr];

        if (write_en) begin
            memory[write_addr] <= write_data;
        end
    end

    initial begin
        for (int i = 0; i < BUFFER_SIZE; i++) begin
            memory[i] = BUFFER_CONFIG.data_width'(0);
        end
    end

endmodule
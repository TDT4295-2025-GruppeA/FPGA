import buffer_config_pkg::*;

module FrameBuffer #(
    parameter buffer_config_t BUFFER_CONFIG = BUFFER_160x120x12
)(
    input logic clk_write,
    input logic rstn_write,

    input logic clk_read,
    
    input logic[BUFFER_CONFIG.addr_width-1:0] read_addr,
    output logic[BUFFER_CONFIG.data_width-1:0] read_data,

    input logic write_en,
    input logic[BUFFER_CONFIG.addr_width-1:0] write_addr,
    input logic[BUFFER_CONFIG.data_width-1:0] write_data
);
    localparam int BUFFER_SIZE = BUFFER_CONFIG.width * BUFFER_CONFIG.height;

    (* ram_style = "block" *) logic[BUFFER_CONFIG.data_width-1:0] memory[BUFFER_SIZE];

    always_ff @(posedge clk_write) begin
        if (write_en) begin
            memory[write_addr] <= write_data;
        end
    end

    always_ff @(posedge clk_read) begin
        read_data <= memory[read_addr];
    end

     initial begin
        // Hardcoded 12-bit R4G4B4 format: RRRR GGGG BBBB
        // Full Red (1111), Zero Green (0000), Zero Blue (0000)
        localparam logic[11:0] INITIAL_RED_VALUE = 12'hF00;
        
        for (int i = 0; i < BUFFER_SIZE; i++) begin
            memory[i] = INITIAL_RED_VALUE;
        end
    end

endmodule
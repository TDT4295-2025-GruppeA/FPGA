import buffer_config_pkg::*;
import types_pkg::*;

module FrameBuffer #(
    parameter buffer_config_t BUFFER_CONFIG = BUFFER_160x120x12
)(
    input logic clk_write,
    input logic rstn_write,

    input logic clk_read,
    
    input logic[BUFFER_CONFIG.addr_width-1:0] read_addr,
    output color_t read_data,

    input logic write_en,
    input logic[BUFFER_CONFIG.addr_width-1:0] write_addr,
    input color_t write_data
);

    (* ram_style = "block" *) logic[$bits(color_t)-1:0] memory[BUFFER_CONFIG.size];

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
        localparam logic[11:0] INITIAL_RED_VALUE = color_t'('hF00);
        
        for (int i = 0; i < BUFFER_CONFIG.size; i++) begin
            memory[i] = INITIAL_RED_VALUE;
        end
    end

endmodule
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
        localparam color_red_t INITIAL_RED_VALUE = color_red_t'('h1F);
        localparam color_green_t INITIAL_GREEN_VALUE = color_green_t'('h3F);
        localparam color_blue_t INITIAL_BLUE_VALUE = color_blue_t'('h1F);
        localparam color_t INITIAL_COLOR_VALUE = {INITIAL_RED_VALUE, INITIAL_GREEN_VALUE, INITIAL_BLUE_VALUE};
        
        for (int i = 0; i < BUFFER_CONFIG.size; i++) begin
            memory[i] = INITIAL_COLOR_VALUE;
        end
    end

endmodule
import fixed_pkg::*;
import types_pkg::*;

module DepthBuffer #(
    parameter int BUFFER_WIDTH = 160,
    parameter int BUFFER_HEIGHT = 120,
    parameter int BUFFER_ADDR_WIDTH = $clog2(BUFFER_WIDTH * BUFFER_HEIGHT),
    parameter real NEAR_PLANE = 1.0,
    parameter real FAR_PLANE  = 10.0
)(
    input  logic clk,
    input  logic rstn,

    // Write request from pipeline
    input  logic        write_en_in,
    input  pixel_data_t write_pixel_in,  // Full pixel data (includes depth, color, coords, etc.)
    input  logic [BUFFER_ADDR_WIDTH-1:0] write_addr_in,

    // Outputs to next pipeline stage (e.g. frame buffer)
    output logic                         write_en_out,
    output logic [BUFFER_ADDR_WIDTH-1:0] write_addr_out,
    output pixel_data_t                  write_pixel_out,

    // Depth buffer clear
    input  logic clear_req,
    input  logic [BUFFER_ADDR_WIDTH-1:0] clear_addr
);
    // Precompute reciprocal near/far planes
    localparam fixed REC_NEAR = rtof(1.0 / NEAR_PLANE, PRECISION_FRACTIONAL_BITS);
    localparam fixed REC_FAR  = rtof(1.0 / FAR_PLANE, PRECISION_FRACTIONAL_BITS);

    localparam int DECIMATION_OFFSET = 4;
    localparam int DECIMATION_WIDTH = 18; // Hardocded to 18 as that is one of the word sizes for BRAM.
    (* ram_style = "block" *) logic signed [DECIMATION_WIDTH-1:0] z_buffer [0:(BUFFER_WIDTH*BUFFER_HEIGHT)-1];

    //////////////////////////////
    // Stage 1: Input Latching  //
    //////////////////////////////

    logic                         s1_write_req;
    logic [BUFFER_ADDR_WIDTH-1:0] s1_addr;
    pixel_data_t                  s1_pixel;

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            s1_write_req <= 1'b0;
            s1_addr      <= '0;
            s1_pixel     <= '0;
        end else begin
            s1_write_req <= write_en_in;
            s1_addr      <= write_addr_in;
            s1_pixel     <= write_pixel_in;
        end
    end

    ///////////////////////////////////////
    // Stage 2: Read current depth value //
    ///////////////////////////////////////

    logic [DECIMATION_WIDTH-1:0] read_data;

    logic                         s2_write_req;
    logic [BUFFER_ADDR_WIDTH-1:0] s2_addr;
    pixel_data_t                  s2_pixel;
    fixed                         s2_current_depth;
    
    assign s2_current_depth = fixed'(read_data) << DECIMATION_OFFSET;

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            s2_write_req <= 1'b0;
            s2_addr      <= '0;
            s2_pixel     <= '0;
        end else begin
            s2_write_req <= s1_write_req;
            s2_addr      <= s1_addr;
            s2_pixel     <= s1_pixel;
        end
    end

    //////////////////////
    // Depth Comparison //
    //////////////////////

    always_comb begin
        write_en_out    = 1'b0;
        write_addr_out  = s2_addr;
        write_pixel_out = s2_pixel;

        if (s2_write_req) begin
            if (s2_pixel.depth < REC_FAR || s2_pixel.depth > REC_NEAR) begin
                write_en_out = 1'b0;
            end else if (s2_pixel.depth > s2_current_depth) begin
                write_en_out = 1'b1;
            end
        end
    end

    ///////////////////////////////
    // Depth Buffer Read & Write //
    ///////////////////////////////

    logic write_en;
    logic [BUFFER_ADDR_WIDTH-1:0] write_addr;
    logic [DECIMATION_WIDTH-1:0] write_data;

    assign write_en = clear_req || write_en_out;
    assign write_addr = clear_req ? clear_addr : s2_addr;
    assign write_data = clear_req ? '0 : DECIMATION_WIDTH'(s2_pixel.depth >>> DECIMATION_OFFSET);

    always_ff @(posedge clk) begin
        read_data <= z_buffer[s1_addr];

        if (write_en)
           z_buffer[write_addr] <= write_data;
    end

endmodule

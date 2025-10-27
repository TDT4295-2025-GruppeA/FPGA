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
    input  logic        write_req,
    input  pixel_data_t write_pixel,  // Full pixel data (includes depth, color, coords, etc.)
    input  logic [BUFFER_ADDR_WIDTH-1:0] write_addr_in,

    // Outputs to next pipeline stage (e.g. frame buffer)
    output logic                         write_en,
    output logic [BUFFER_ADDR_WIDTH-1:0] write_addr_out,
    output pixel_data_t                  write_pixel_out,

    // Depth buffer clear
    input  logic clear_req,
    input  logic [BUFFER_ADDR_WIDTH-1:0] clear_addr
);
    // Precompute reciprocal near/far planes
    localparam fixed REC_NEAR = rtof(1.0 / NEAR_PLANE);
    localparam fixed REC_FAR  = rtof(1.0 / FAR_PLANE);

    localparam int DECIMATION_FACTOR = 4;
    localparam int HALF_FIXED_WIDTH = TOTAL_WIDTH/2;
    (* ram_style = "block" *) logic signed [HALF_FIXED_WIDTH-1:0] z_buffer [0:(BUFFER_WIDTH*BUFFER_HEIGHT)-1];

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
            s1_write_req <= write_req;
            s1_addr      <= write_addr_in;
            s1_pixel     <= write_pixel;
        end
    end


    /////////////////////////////////////
    // Stage 2: Read current depth value
    /////////////////////////////////////

    logic                         s2_write_req;
    logic [BUFFER_ADDR_WIDTH-1:0] s2_addr;
    pixel_data_t                  s2_pixel;
    fixed                         s2_current_depth;

    always_ff @(posedge clk) begin
        s2_write_req     <= s1_write_req;
        s2_addr          <= s1_addr;
        s2_pixel         <= s1_pixel;
        s2_current_depth <= fixed'(z_buffer[s1_addr] <<< DECIMATION_FACTOR);
    end

    //////////////////////////////
    // Stage 3: Depth comparison
    //////////////////////////////

    always_comb begin
        write_en        = 1'b0;
        write_addr_out  = s2_addr;
        write_pixel_out = s2_pixel;

        if (s2_write_req) begin
            if (s2_pixel.depth < REC_FAR || s2_pixel.depth > REC_NEAR) begin
                // Outside frustum → reject
                write_en   = 1'b0;
            end else if (s2_pixel.depth > s2_current_depth) begin
                // Closer → pass
                write_en   = 1'b1;
            end
        end
    end


    ////////////////////////////////
    // Stage 4: Depth buffer update
    ////////////////////////////////
     always_ff @(posedge clk) begin
        if (clear_req)
            z_buffer[clear_addr] <= '0;
        else if (write_en)
            z_buffer[s2_addr] <= HALF_FIXED_WIDTH'(s2_pixel.depth >>> DECIMATION_FACTOR);
    end

endmodule

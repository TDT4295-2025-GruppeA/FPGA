import fixed_pkg::*;

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
    input  logic [BUFFER_ADDR_WIDTH-1:0] write_addr,
    input  fixed        write_depth,     // reciprocal depth (1/z)
    output logic        write_pass,      // depth test passed?

    // Depth buffer clear
    input  logic clear_req,
    input  logic [BUFFER_ADDR_WIDTH-1:0] clear_addr
);
    // Precompute reciprocal near/far planes
    localparam fixed REC_NEAR = div(rtof(1.0), rtof(NEAR_PLANE));
    localparam fixed REC_FAR  = div(rtof(1.0), rtof(FAR_PLANE));

    // The actual depth buffer
    fixed z_buffer [0:(BUFFER_WIDTH*BUFFER_HEIGHT)-1];

    fixed current_depth;
    fixed new_depth;

    logic write_en;

    // Depth test logic
    always_comb begin
        current_depth = z_buffer[write_addr];
        write_en = 1'b0;
        write_pass = 1'b0;

        if (write_req) begin
            if (write_depth < REC_FAR || write_depth > REC_NEAR) begin
                // Outside view frustum → reject
                write_en = 1'b0;
                write_pass = 1'b0;
                new_depth = current_depth;
            end else if (write_depth > current_depth) begin
                // Closer → draw
                write_en = 1'b1;
                write_pass = 1'b1;
                new_depth = write_depth;
            end
        end

    end

    // Sequential write
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            int i;
            for (i = 0; i < BUFFER_WIDTH*BUFFER_HEIGHT; i++)
                z_buffer[i] <= '0;
        end else begin
            if (clear_req)
                z_buffer[clear_addr] <= '0; // farthest
            else if (write_en)
                z_buffer[write_addr] <= new_depth;
        end
    end

endmodule

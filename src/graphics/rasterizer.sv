import fixed_pkg::*;

typedef enum logic {
    IDLE,
    RUNNING
} rasterizer_state;

module Rasterizer #(
    parameter logic [12:0] WIDTH = 13'd64,
    parameter logic [12:0] HEIGHT = 13'd64
)(
    input logic clk,
    input logic rstn,
    input logic start,
    input fixed vertex0 [3],
    input fixed vertex1 [3],
    input fixed vertex2 [3],
    input logic [12:0] offset_x,
    input logic [12:0] offset_y,
    output logic ready,
    output logic [12:0] pixel_x,
    output logic [12:0] pixel_y,
    output logic pixel_covered
);
    rasterizer_state state = IDLE;
    logic [12:0] x = 0;
    logic [12:0] y = 0;

    fixed p [3]; // Current pixel position
    fixed p1 [3], p2 [3], p3 [3]; // Vectors from vertices to pixel
    fixed v1 [3], v2 [3], v3 [3]; // Edge vectors
    fixed c1 [3], c2 [3], c3 [3]; // Cross products

    assign p[0] = itof(32'(x + offset_x));
    assign p[1] = itof(32'(y + offset_y));
    assign p[2] = itof(0);

    VecSub sub1 (
        .lhs(p),
        .rhs(vertex0),
        .out(p1)
    );
    VecSub sub2 (
        .lhs(p),
        .rhs(vertex1),
        .out(p2)
    );
    VecSub sub3 (
        .lhs(p),
        .rhs(vertex2),
        .out(p3)
    );

    VecSub sub4 (
        .lhs(vertex1),
        .rhs(vertex0),
        .out(v1)
    );
    VecSub sub5 (
        .lhs(vertex2),
        .rhs(vertex1),
        .out(v2)
    );
    VecSub sub6 (
        .lhs(vertex0),
        .rhs(vertex2),
        .out(v3)
    );

    VecCross cross1 (
        .lhs(p1),
        .rhs(v1),
        .out(c1)
    );
    VecCross cross2 (
        .lhs(p2),
        .rhs(v2),
        .out(c2)
    );
    VecCross cros3 (
        .lhs(p3),
        .rhs(v3),
        .out(c3)
    );

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            ready <= 1;
            state <= IDLE;
            x <= 0;
            y <= 0;
            pixel_covered <= 0;
            pixel_x <= 0;
            pixel_y <= 0;
        end else begin
            case (state)
                IDLE: begin
                    // When idle output zeros           
                    pixel_covered <= 0;
                    pixel_x <= 0;
                    pixel_y <= 0;
                    // Also, make sure internal counters are reset
                    x <= 0;
                    y <= 0;

                    // If start is received, go to running state
                    if (start) begin
                        ready <= 0;
                        state <= RUNNING;
                    end else begin
                        ready <= 1;
                    end
                end
                RUNNING: begin
                    // Check if pixel is inside triangle
                    if (c1[2] >= 0 && c2[2] >= 0 && c3[2] >= 0) begin
                        pixel_covered <= 1;
                    end else begin
                        pixel_covered <= 0;
                    end

                    // Output current pixel position
                    pixel_x <= x;
                    pixel_y <= y;

                    // Move to next pixel
                    if (x == WIDTH - 1) begin
                        x <= 0;
                        if (y == HEIGHT - 1) begin
                            state <= IDLE;
                            y <= 0;
                            x <= 0;
                        end else begin
                            y <= y + 1;
                        end
                    end else begin
                        x <= x + 1;
                    end
                end
            endcase
        end
    end
endmodule

import types_pkg::*;
import fixed_pkg::*;

typedef enum logic[1:0] { 
    TRIANGLE_SAMPLER_IDLE,        // Waiting for new data.
    TRIANGLE_SAMPLER_INSIDE_TEST, // Check that the sample point is within the triangle.
    TRIANGLE_SAMPLER_INTERPOLATE, // Calculate barycentric coordinates, interpolated color and depth.
    TRIANGLE_SAMPLER_DONE         // Result ready to be read.
} triangle_sampler_state;

// Positive when to the right of line, negative when to the left.
function automatic fixed edge_equation(position_t p0, position_t p1, fixed qx, fixed qy);
    // The formula from the book:
    //
    // F_01(q) = (y_1 - y_0) * x_q + (x_1 - x_0) * y_q + (x_0 * y_1 + y_0 * x_1)
    //         = (((y_1 - y_0) * x_q) + ((x_1 - x_0) * y_q)) + ((x_0 * y_1) + (y_0 * x_1))
    //
    // Note that our y axis is flipped upside down, so the sign for y coordinates is inverted.
    // Written using our fixed point arithmetic functions:
    return add(
        add(
            mul(
                sub(p1.y, p0.y),
                qx
            ),
            mul(
                sub(p0.x, p1.x),
                qy
            )
        ),
        add(
            mul(p0.x, p1.y),
            mul(p0.y, p1.x)
        )
    );
endfunction

// Weights input values by barycentric coordinates.
function automatic fixed barycentric_weight(fixed b0, fixed value0, fixed b1, fixed value1, fixed b2, fixed value2);
    return add(
        add(
            mul(b0, value0),
            mul(b1, value1)
        ),
        mul(b2, value2)
    );
endfunction


// Samples a single point on a triangle.
// If the result is inside the triangle, it also
// calculates the interpolated color and depth.
module TriangleSampler #(
    parameter int VIEWPORT_WIDTH = 1,
    parameter int VIEWPORT_HEIGHT = 1
) (
    input logic clk,
    input logic rstn,

    output logic triangle_s_ready,
    input logic triangle_s_valid,
    input triangle_t triangle_s_data,

    output logic pixel_coordinate_s_ready,
    input logic pixel_coordinate_s_valid,
    input pixel_coordinate_t pixel_coordinate_s_data,

    input logic pixel_data_m_ready,
    output logic pixel_data_m_valid,
    output pixel_data_t pixel_data_m_data

);
    // Precompute how many fixed point units a pixel represents.
    // NOTE: We subtract 1 from the width and height because we
    // measure lengths between pixels from their centers.
    // E.g. in a 2 pixel wide viewport the distance from the left
    // column to the right column is 1 pixel, not 2 pixels.
    localparam fixed PIXEL_SCALE_X_FIXED = rtof(1 / real'(VIEWPORT_WIDTH - 1));
    localparam fixed PIXEL_SCALE_Y_FIXED = rtof(1 / real'(VIEWPORT_HEIGHT - 1));

    triangle_sampler_state state;

    // We are ready to accept new data when we are TRIANGLE_SAMPLER_IDLE.
    assign triangle_s_ready = (state == TRIANGLE_SAMPLER_IDLE);
    assign pixel_coordinate_s_ready = (state == TRIANGLE_SAMPLER_IDLE);

    // Result is ready to be read when we are TRIANGLE_SAMPLER_DONE.
    assign pixel_data_m_valid = (state == TRIANGLE_SAMPLER_DONE);

    // Registers to store input data.
    triangle_t triangle;
    pixel_coordinate_t pixel_coordinate;
    fixed pixel_x, pixel_y;

    // Convert pixel coordinates to fixed point.
    assign pixel_x = mul(itof(int'(pixel_coordinate.x)), PIXEL_SCALE_X_FIXED);
    assign pixel_y = mul(itof(int'(pixel_coordinate.y)), PIXEL_SCALE_Y_FIXED);

    // Wire to hold the computed results.
    pixel_data_t pixel_data;

    // Connect pixel coordinates to result.
    assign pixel_data.coordinate = pixel_coordinate;

    // Edge functions for the three edges of the triangle.
    fixed f01, f12, f20;
    assign f01 = edge_equation(triangle.a.position, triangle.b.position, pixel_x, pixel_y);
    assign f12 = edge_equation(triangle.b.position, triangle.c.position, pixel_x, pixel_y);
    assign f20 = edge_equation(triangle.c.position, triangle.a.position, pixel_x, pixel_y);

    // The sample point is within the triangle if it
    // is on the right side of all three edges.
    assign pixel_data.valid = (f01 > 0) && (f12 > 0) && (f20 > 0);

    // Twice the area of the triangle.
    // Used for calculating barycentric coordinates.
    fixed a;
    assign a = add(f01, add(f12, f20));

    // Control signals for the divider.
    logic divisor_valid, divisor_ready, a_reciprocal_valid;
    fixed a_reciprocal;

    FixedDivider divider (
        .clk(clk),
        
        .dividend_s_ready(), // Ignored.
        .dividend_s_valid(1'b1), // Always valid.
        .dividend_s_data(itof(1)), // We want to calculate 1/a.

        .divisor_s_ready(divisor_ready),
        .divisor_s_valid(divisor_valid),
        .divisor_s_data(a),

        .result_m_ready(1'b1), // Always ready for result.
        .result_m_valid(a_reciprocal_valid),
        .result_m_data(a_reciprocal)
    );

    // Calculate barycentric coordinates.
    fixed b0, b1, b2;
    assign b0 = mul(f01, a_reciprocal);
    assign b1 = mul(f12, a_reciprocal);
    assign b2 = mul(f20, a_reciprocal);

    // Calculate interpolated color and depth.
    // Only valid if the point is inside the triangle.
    assign pixel_data.depth = barycentric_weight(
        b0, triangle.a.position.z,
        b1, triangle.b.position.z,
        b2, triangle.c.position.z
    );

    // Color TBD. For now just white.
    assign pixel_data.color.red   = 4'hF;
    assign pixel_data.color.green = 4'hF;
    assign pixel_data.color.blue  = 4'hF;

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            state <= TRIANGLE_SAMPLER_IDLE;
            pixel_data_m_data <= '0;
        end else begin
            case (state)
                TRIANGLE_SAMPLER_IDLE: begin
                    // Load new triangle if available.
                    if (triangle_s_valid) begin
                        triangle <= triangle_s_data;
                    end

                    // Load new sample point if available.
                    // Start inside test.
                    if (pixel_coordinate_s_valid) begin
                        state <= TRIANGLE_SAMPLER_INSIDE_TEST;
                        pixel_coordinate <= pixel_coordinate_s_data;
                    end
                end

                TRIANGLE_SAMPLER_INSIDE_TEST: begin
                    // Check if the sample point is inside the triangle.
                    if (pixel_data.valid) begin
                        // And that the divider is ready to accept new data.
                        if (divisor_ready) begin
                            // If it is, proceed to interpolation.
                            divisor_valid <= 1'b1;
                            state <= TRIANGLE_SAMPLER_INTERPOLATE;
                        end
                        // If not, we just wait.
                    end else begin
                        // Otherwise, we are done.
                        state <= TRIANGLE_SAMPLER_DONE;
                        pixel_data_m_data <= pixel_data;
                    end
                end
                
                TRIANGLE_SAMPLER_INTERPOLATE: begin
                    // Disable the divisor input.
                    divisor_valid <= 1'b0;

                    // Wait for the divider to produce the result.
                    if (a_reciprocal_valid) begin
                        // Latch the interpolated color and depth.
                        pixel_data_m_data <= pixel_data;
                        // And proceed to TRIANGLE_SAMPLER_DONE state.
                        state <= TRIANGLE_SAMPLER_DONE;
                    end
                end
                
                TRIANGLE_SAMPLER_DONE: begin
                    // Return to TRIANGLE_SAMPLER_IDLE when result has been read.
                    if (pixel_data_m_ready) begin
                        state <= TRIANGLE_SAMPLER_IDLE;
                    end
                end
            endcase
        end
    end

endmodule
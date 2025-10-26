import types_pkg::*;
import fixed_pkg::*;

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
                sub(p0.y, p1.y),
                qx
            ),
            mul(
                sub(p1.x, p0.x),
                qy
            )
        ),
        sub(
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

function automatic logic [3:0] barycentric_weight_color(fixed b0, logic [3:0] color0, fixed b1, logic [3:0] color1, fixed b2, logic [3:0] color2);
    return 4'(ftoi(barycentric_weight(
        b0, itof(32'(color0)),
        b1, itof(32'(color1)),
        b2, itof(32'(color2))
    )));
endfunction

function automatic logic is_top_left(position_t p0, position_t p1);
    return ((p0.y == p1.y) && (p1.x > p0.x)) || (p0.y > p1.y);
endfunction

// Steps:
// 1. Evaluate edge functions.
// 2. Calculate first two barycentric coordinates.
// 3. Calculate last barycentric coordinate.
// 3. Interpolate color and depth.
// 4. Output pixel data.
module TriangleInterpolator #(
    parameter int VIEWPORT_WIDTH = 1,
    parameter int VIEWPORT_HEIGHT = 1
) (
    input logic clk,
    input logic rstn,

    output logic attributed_triangle_s_ready,
    input logic attributed_triangle_s_valid,
    input attributed_triangle_t attributed_triangle_s_data,
    input triangle_metadata_t attributed_triangle_s_metadata,

    output logic pixel_coordinate_s_ready,
    input logic pixel_coordinate_s_valid,
    input pixel_coordinate_t pixel_coordinate_s_data,
    input pixel_metadata_t pixel_coordinate_s_metadata,

    input logic pixel_data_m_ready,
    output logic pixel_data_m_valid,
    output pixel_data_t pixel_data_m_data,
    output pixel_metadata_t pixel_data_m_metadata

);
    // Precompute how many fixed point units a pixel represents.
    // NOTE: We subtract 1 from the width and height because we
    // measure lengths between pixels from their centers.
    // E.g. in a 2 pixel wide viewport the distance from the left
    // column to the right column is 1 pixel, not 2 pixels.
    localparam real PIXEL_SCALE_X = 2.0 / real'(VIEWPORT_WIDTH - 1);
    localparam real PIXEL_SCALE_Y = 2.0 / real'(VIEWPORT_HEIGHT - 1);

    localparam int PIXEL_OFFSET_X = (VIEWPORT_WIDTH - 1) / 2;
    localparam int PIXEL_OFFSET_Y = (VIEWPORT_HEIGHT - 1) / 2;

    // Stall pipline when downstream is not ready.
    logic stall;
    assign stall = !pixel_data_m_ready;

    // We are ready to accept new data when we are not stalling.
    assign attributed_triangle_s_ready = !stall;
    assign pixel_coordinate_s_ready = !stall;

    /////////////
    // Stage 1 //
    /////////////

    // Registers to store input data.
    triangle_t triangle_1_r;
    triangle_metadata_t triangle_metadata_1_r;
    fixed a_reciprocal_1_r;
    logic small_1_r;
    pixel_coordinate_t pixel_coordinate_1_r;
    pixel_metadata_t pixel_coordinate_metadata_1_r;

    // If data in stage 1 is valid.
    logic valid_1_r;

    // Latch input data.
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            triangle_1_r <= '0;
            triangle_metadata_1_r <= '0;
            a_reciprocal_1_r <= '0;
            pixel_coordinate_1_r <= '0;
            pixel_coordinate_metadata_1_r <= '0;
            valid_1_r <= '0;
        end else if (!stall) begin
            if (attributed_triangle_s_valid && attributed_triangle_s_ready) begin
                triangle_1_r <= attributed_triangle_s_data.triangle;
                triangle_metadata_1_r <= attributed_triangle_s_metadata;
                a_reciprocal_1_r <= attributed_triangle_s_data.area_inv;
                small_1_r <= attributed_triangle_s_data.small_area;
            end
            if (pixel_coordinate_s_valid && pixel_coordinate_s_ready) begin
                pixel_coordinate_1_r <= pixel_coordinate_s_data;
                pixel_coordinate_metadata_1_r <= pixel_coordinate_s_metadata;
            end

            // Stage is valid if we recieve a pixel.
            // User error if no triangle is received.
            // This is done so that the triangle can
            // be reused for subsequent pixels.
            valid_1_r <= pixel_coordinate_s_valid;
        end
    end

    pixel_metadata_t pixel_metadata_1_c;
    assign pixel_metadata_1_c.last = triangle_metadata_1_r.last && pixel_coordinate_metadata_1_r.last;

    // Convert pixel coordinates to fixed point.
    fixed pixel_x_1_c, pixel_y_1_c;
    assign pixel_x_1_c = pixel_coordinate_1_r.x * rtof(PIXEL_SCALE_X) - 18'(PIXEL_OFFSET_X) * rtof(PIXEL_SCALE_X);
    assign pixel_y_1_c = pixel_coordinate_1_r.y * rtof(PIXEL_SCALE_Y) - 18'(PIXEL_OFFSET_Y) * rtof(PIXEL_SCALE_Y);

    // Edge functions for the three edges of the triangle.
    fixed f01_1_c, f12_1_c, f20_1_c;
    assign f01_1_c = edge_equation(triangle_1_r.v0.position, triangle_1_r.v1.position, pixel_x_1_c, pixel_y_1_c);
    assign f12_1_c = edge_equation(triangle_1_r.v1.position, triangle_1_r.v2.position, pixel_x_1_c, pixel_y_1_c);
    assign f20_1_c = edge_equation(triangle_1_r.v2.position, triangle_1_r.v0.position, pixel_x_1_c, pixel_y_1_c);

    /////////////
    // Stage 2 //
    /////////////

    // Latch onto data from stage 1.
    triangle_t triangle_2_r;
    fixed a_reciprocal_2_r;
    logic small_2_r;
    pixel_coordinate_t pixel_coordinate_2_r;
    pixel_metadata_t pixel_metadata_2_r;
    fixed f01_2_r, f12_2_r, f20_2_r;
    fixed pixel_x_2_r, pixel_y_2_r;

    // If data in stage 2 is valid.
    logic valid_2_r;

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            triangle_2_r <= '0;
            a_reciprocal_2_r <= '0;
            pixel_coordinate_2_r <= '0;
            pixel_metadata_2_r <= '0;
            f01_2_r <= '0;
            f12_2_r <= '0;
            f20_2_r <= '0;
            pixel_x_2_r <= '0;
            pixel_y_2_r <= '0;
            valid_2_r <= '0;
        end else if (!stall) begin
            triangle_2_r <= triangle_1_r;
            a_reciprocal_2_r <= a_reciprocal_1_r;
            small_2_r <= small_1_r;
            pixel_coordinate_2_r <= pixel_coordinate_1_r;
            pixel_metadata_2_r <= pixel_metadata_1_c;
            f01_2_r <= f01_1_c;
            f12_2_r <= f12_1_c;
            f20_2_r <= f20_1_c;
            pixel_x_2_r <= pixel_x_1_c;
            pixel_y_2_r <= pixel_y_1_c;
            valid_2_r <= valid_1_r;
        end
    end

    // Top left rule. Whether to include pixels on the edge.
    logic topleft01_2_c, topleft12_2_c, topleft20_2_c;
    assign topleft01_2_c = is_top_left(triangle_2_r.v0.position, triangle_2_r.v1.position);
    assign topleft12_2_c = is_top_left(triangle_2_r.v1.position, triangle_2_r.v2.position);
    assign topleft20_2_c = is_top_left(triangle_2_r.v2.position, triangle_2_r.v0.position);

    // When we check if a pixel is exactly on the edge we need to
    // check if the edge function equals zero. However, due to
    // numerical imprecision we need to allow for a small tolerance.
    // NOTE: The value 4 here corresponds to 4 LSBs.
    localparam fixed EDGE_TOLERANCE = 8;

    // The sample point is within the triangle if it is on the right
    // side of all three edges or if the sample point is exactly on an edge
    // and that edge is a top left edge. We also require the area to be
    // larger than a small threshold to avoid numerical issues.
    logic covered_2_c;
    assign covered_2_c = (
        (f01_2_r > 0 || f01_2_r >= -EDGE_TOLERANCE && topleft01_2_c) &&
        (f12_2_r > 0 || f12_2_r >= -EDGE_TOLERANCE && topleft12_2_c) &&
        (f20_2_r > 0 || f20_2_r >= -EDGE_TOLERANCE && topleft20_2_c) &&
        !small_2_r
    );

    // Calculate barycentric coordinates.
    fixed b0_2_c, b1_2_c;
    assign b0_2_c = mul(f12_2_r, a_reciprocal_2_r);
    assign b1_2_c = mul(f20_2_r, a_reciprocal_2_r);

    /////////////
    // Stage 3 //
    /////////////

    // Latch onto data from stage 2.
    triangle_t triangle_3_r;
    pixel_coordinate_t pixel_coordinate_3_r;
    pixel_metadata_t pixel_metadata_3_r;
    logic covered_3_r;
    fixed b0_3_r, b1_3_r;
    fixed pixel_x_3_r, pixel_y_3_r;

    logic valid_3_r;

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            triangle_3_r <= '0;
            pixel_coordinate_3_r <= '0;
            pixel_metadata_3_r <= '0;
            covered_3_r <= '0;
            b0_3_r <= '0;
            b1_3_r <= '0;
            pixel_x_3_r <= '0;
            pixel_y_3_r <= '0;
            valid_3_r <= '0;
        end else if (!stall) begin
            triangle_3_r <= triangle_2_r;
            pixel_coordinate_3_r <= pixel_coordinate_2_r;
            pixel_metadata_3_r <= pixel_metadata_2_r;
            covered_3_r <= covered_2_c;
            b0_3_r <= b0_2_c;
            b1_3_r <= b1_2_c;
            pixel_x_3_r <= pixel_x_2_r;
            pixel_y_3_r <= pixel_y_2_r;
            valid_3_r <= valid_2_r;
        end
    end

    fixed  b2_3_c;
    assign b2_3_c = sub(itof(1), add(b0_3_r, b1_3_r));

    /////////////
    // Stage 4 //
    /////////////

    // Latch onto data from stage 3.
    triangle_t triangle_4_r;
    pixel_coordinate_t pixel_coordinate_4_r;
    pixel_metadata_t pixel_metadata_4_r;
    logic covered_4_r;
    fixed b0_4_r, b1_4_r, b2_4_r;
    fixed pixel_x_4_r, pixel_y_4_r;

    logic valid_4_r;

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            triangle_4_r <= '0;
            pixel_coordinate_4_r <= '0;
            pixel_metadata_4_r <= '0;
            covered_4_r <= '0;
            b0_4_r <= '0;
            b1_4_r <= '0;
            b2_4_r <= '0;
            pixel_x_4_r <= '0;
            pixel_y_4_r <= '0;
            valid_4_r <= '0;
        end else if (!stall) begin
            triangle_4_r <= triangle_3_r;
            pixel_coordinate_4_r <= pixel_coordinate_3_r;
            pixel_metadata_4_r <= pixel_metadata_3_r;
            covered_4_r <= covered_3_r;
            b0_4_r <= b0_3_r;
            b1_4_r <= b1_3_r;
            b2_4_r <= b2_3_c;
            pixel_x_4_r <= pixel_x_3_r;
            pixel_y_4_r <= pixel_y_3_r;
            valid_4_r <= valid_3_r;
        end
    end

    pixel_data_t pixel_data_4_c;
    assign pixel_data_4_c.coordinate = pixel_coordinate_4_r;
    assign pixel_data_4_c.covered = covered_4_r;

    // Calculate interpolated color and depth.
    // Only valid if the point is inside the triangle.
    assign pixel_data_4_c.depth = barycentric_weight(
        b0_4_r, triangle_4_r.v0.position.z,
        b1_4_r, triangle_4_r.v1.position.z,
        b2_4_r, triangle_4_r.v2.position.z
    );

     assign pixel_data_4_c.color.red = barycentric_weight_color(
        b0_4_r, triangle_4_r.v0.color.red,
        b1_4_r, triangle_4_r.v1.color.red,
        b2_4_r, triangle_4_r.v2.color.red
    );
    assign pixel_data_4_c.color.green = barycentric_weight_color(
        b0_4_r, triangle_4_r.v0.color.green,
        b1_4_r, triangle_4_r.v1.color.green,
        b2_4_r, triangle_4_r.v2.color.green
    );
    assign pixel_data_4_c.color.blue = barycentric_weight_color(
        b0_4_r, triangle_4_r.v0.color.blue,
        b1_4_r, triangle_4_r.v1.color.blue,
        b2_4_r, triangle_4_r.v2.color.blue
    );

    /////////////
    // Stage 5 //
    /////////////

    // Latch onto data from stage 4.
    pixel_data_t pixel_data_5_r;
    pixel_metadata_t pixel_metadata_5_r;

    logic valid_5_r;

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            pixel_data_5_r <= '0;
            pixel_metadata_5_r <= '0;
            valid_5_r <= '0;
        end else if (!stall) begin
            pixel_data_5_r <= pixel_data_4_c;
            pixel_metadata_5_r <= pixel_metadata_4_r;
            valid_5_r <= valid_4_r;
        end
    end

    assign pixel_data_m_metadata = pixel_metadata_5_r;
    assign pixel_data_m_data = pixel_data_5_r;

    assign pixel_data_m_valid = valid_5_r;
endmodule
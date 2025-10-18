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

// Steps:
// 1. Evaluate edge functions.
// 2. Calculate barycentric coordinates.
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

    output logic pixel_coordinate_s_ready,
    input logic pixel_coordinate_s_valid,
    input pixel_coordinate_t pixel_coordinate_s_data,
    input pixel_coordinate_metadata_t pixel_coordinate_s_metadata,

    input logic pixel_data_m_ready,
    output logic pixel_data_m_valid,
    output pixel_data_t pixel_data_m_data,
    output pixel_data_metadata_t pixel_data_m_metadata

);
    // Precompute how many fixed point units a pixel represents.
    // NOTE: We subtract 1 from the width and height because we
    // measure lengths between pixels from their centers.
    // E.g. in a 2 pixel wide viewport the distance from the left
    // column to the right column is 1 pixel, not 2 pixels.
    localparam fixed PIXEL_SCALE_X_FIXED = rtof(1 / real'(VIEWPORT_WIDTH - 1));
    localparam fixed PIXEL_SCALE_Y_FIXED = rtof(1 / real'(VIEWPORT_HEIGHT - 1));

    // Stall pipline when downstream is not ready.
    logic stall;
    assign stall = ~pixel_data_m_ready;

    // We are ready to accept new data when we are not stalling.
    assign attributed_triangle_s_ready = ~stall;
    assign pixel_coordinate_s_ready = ~stall;

    /////////////
    // Stage 1 //
    /////////////

    // Registers to store input data.
    triangle_t triangle_1_r;
    fixed a_reciprocal_1_r;
    pixel_coordinate_t pixel_coordinate_1_r;
    pixel_coordinate_metadata_t pixel_coordinate_metadata_1_r;

    // If data in stage 1 is valid.
    logic valid_1_r;

    // Latch input data.
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            triangle_1_r <= '0;
            a_reciprocal_1_r <= '0;
            pixel_coordinate_1_r <= '0;
            pixel_coordinate_metadata_1_r <= '0;
            valid_1_r <= '0;
        end else if (!stall) begin
            if (attributed_triangle_s_valid) begin
                triangle_1_r <= attributed_triangle_s_data.triangle;
                a_reciprocal_1_r <= attributed_triangle_s_data.area_inv;
            end
            if (pixel_coordinate_s_valid) begin
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

    // Convert pixel coordinates to fixed point.
    fixed pixel_x_1_c, pixel_y_1_c;
    assign pixel_x_1_c = mul(itof(int'(pixel_coordinate_1_r.x)), PIXEL_SCALE_X_FIXED);
    assign pixel_y_1_c = mul(itof(int'(pixel_coordinate_1_r.y)), PIXEL_SCALE_Y_FIXED);

    // Edge functions for the three edges of the triangle.
    fixed f01_1_c, f12_1_c, f20_1_c;
    assign f01_1_c = edge_equation(triangle_1_r.a.position, triangle_1_r.b.position, pixel_x_1_c, pixel_y_1_c);
    assign f12_1_c = edge_equation(triangle_1_r.b.position, triangle_1_r.c.position, pixel_x_1_c, pixel_y_1_c);
    assign f20_1_c = edge_equation(triangle_1_r.c.position, triangle_1_r.a.position, pixel_x_1_c, pixel_y_1_c);

    /////////////
    // Stage 2 //
    /////////////

    // Latch onto data from stage 1.
    triangle_t triangle_2_r;
    fixed a_reciprocal_2_r;
    pixel_coordinate_t pixel_coordinate_2_r;
    pixel_coordinate_metadata_t pixel_coordinate_metadata_2_r;
    fixed f01_2_r, f12_2_r, f20_2_r;
    fixed pixel_x_2_r, pixel_y_2_r;

    // If data in stage 2 is valid.
    logic valid_2_r;

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            triangle_2_r <= '0;
            a_reciprocal_2_r <= '0;
            pixel_coordinate_2_r <= '0;
            pixel_coordinate_metadata_2_r <= '0;
            f01_2_r <= '0;
            f12_2_r <= '0;
            f20_2_r <= '0;
            pixel_x_2_r <= '0;
            pixel_y_2_r <= '0;
            valid_2_r <= '0;
        end else if (!stall) begin
            triangle_2_r <= triangle_1_r;
            a_reciprocal_2_r <= a_reciprocal_1_r;
            pixel_coordinate_2_r <= pixel_coordinate_1_r;
            pixel_coordinate_metadata_2_r <= pixel_coordinate_metadata_1_r;
            f01_2_r <= f01_1_c;
            f12_2_r <= f12_1_c;
            f20_2_r <= f20_1_c;
            pixel_x_2_r <= pixel_x_1_c;
            pixel_y_2_r <= pixel_y_1_c;
            valid_2_r <= valid_1_r;
        end
    end

    // The sample point is within the triangle if it
    // is on the right side of all three edges.
    // TODO: Add top left rule.
    logic covered_2_c;
    assign covered_2_c = (f01_2_r > 0) && (f12_2_r > 0) && (f20_2_r > 0);

    // Calculate barycentric coordinates.
    fixed b0_2_c, b1_2_c, b2_2_c;
    assign b0_2_c = mul(f01_2_r, a_reciprocal_2_r);
    assign b1_2_c = mul(f12_2_r, a_reciprocal_2_r);
    assign b2_2_c = mul(f20_2_r, a_reciprocal_2_r);

    /////////////
    // Stage 3 //
    /////////////

    // Latch onto data from stage 2.
    triangle_t triangle_3_r;
    pixel_coordinate_t pixel_coordinate_3_r;
    pixel_coordinate_metadata_t pixel_coordinate_metadata_3_r;
    logic covered_3_r;
    fixed b0_3_r, b1_3_r, b2_3_r;
    fixed pixel_x_3_r, pixel_y_3_r;

    logic valid_3_r;

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            triangle_3_r <= '0;
            pixel_coordinate_3_r <= '0;
            pixel_coordinate_metadata_3_r <= '0;
            covered_3_r <= '0;
            b0_3_r <= '0;
            b1_3_r <= '0;
            b2_3_r <= '0;
            pixel_x_3_r <= '0;
            pixel_y_3_r <= '0;
            valid_3_r <= '0;
        end else if (!stall) begin
            triangle_3_r <= triangle_2_r;
            pixel_coordinate_3_r <= pixel_coordinate_2_r;
            pixel_coordinate_metadata_3_r <= pixel_coordinate_metadata_2_r;
            covered_3_r <= covered_2_c;
            b0_3_r <= b0_2_c;
            b1_3_r <= b1_2_c;
            b2_3_r <= b2_2_c;
            pixel_x_3_r <= pixel_x_2_r;
            pixel_y_3_r <= pixel_y_2_r;
            valid_3_r <= valid_2_r;
        end
    end

    // Calculate interpolated color and depth.
    // Only valid if the point is inside the triangle.
    fixed depth_3_c;
    assign depth_3_c = barycentric_weight(
        b0_3_r, triangle_3_r.a.position.z,
        b1_3_r, triangle_3_r.b.position.z,
        b2_3_r, triangle_3_r.c.position.z
    );

    /////////////
    // Stage 4 //
    ////////////

    // Latch onto data from stage 3.
    pixel_coordinate_t pixel_coordinate_4_r;
    pixel_coordinate_metadata_t pixel_coordinate_metadata_4_r;
    logic covered_4_r;
    fixed depth_4_r;

    logic valid_4_r;

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            pixel_coordinate_4_r <= '0;
            pixel_coordinate_metadata_4_r <= '0;
            covered_4_r <= '0;
            depth_4_r <= '0;
            valid_4_r <= '0;
        end else if (!stall) begin
            pixel_coordinate_4_r <= pixel_coordinate_3_r;
            pixel_coordinate_metadata_4_r <= pixel_coordinate_metadata_3_r;
            covered_4_r <= covered_3_r;
            depth_4_r <= depth_3_c;
            valid_4_r <= valid_3_r;
        end
    end

    assign pixel_data_m_metadata.last = pixel_coordinate_metadata_4_r.last;

    assign pixel_data_m_valid = valid_4_r;

    assign pixel_data_m_data.coordinate = pixel_coordinate_4_r;
    assign pixel_data_m_data.covered = covered_4_r;

    assign pixel_data_m_data.depth = depth_4_r;

    // TODO: Interpolate Color. 
    // For now just white.
    assign pixel_data_m_data.color.red   = 4'hF;
    assign pixel_data_m_data.color.green = 4'hF;
    assign pixel_data_m_data.color.blue  = 4'hF;

endmodule
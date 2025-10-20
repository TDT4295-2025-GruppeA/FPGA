import types_pkg::*;
import fixed_pkg::*;

module Rasterizer #(
    // The viewport size to rasterize
    parameter int VIEWPORT_WIDTH = 64,
    parameter int VIEWPORT_HEIGHT = 64
)(
    // System interface
    input logic clk,
    input logic rstn,

    output logic triangle_s_ready,
    input logic triangle_s_valid,
    input triangle_t triangle_s_data,
    input triangle_metadata_t triangle_s_metadata,

    input logic pixel_data_m_ready,
    output logic pixel_data_m_valid,
    output pixel_data_t pixel_data_m_data,
    output pixel_metadata_t pixel_data_m_metadata
);
    typedef enum logic {
        IDLE,
        RUNNING
    } rasterizer_state;

    rasterizer_state state = IDLE;

    attributed_triangle_t attributed_triangle;
    triangle_metadata_t attributed_triangle_metadata;
    logic attributed_triangle_valid;

    // We consider the rasterizer ready when it is IDLE and
    // the interpolator is ready for a new triangle.
    logic rasterizer_ready, interpolator_ready;
    assign rasterizer_ready = (state == IDLE) && interpolator_ready;

    TrianglePreprocessor preprocessor (
        .clk(clk),
        .rstn(rstn),

        .triangle_s_ready(triangle_s_ready),
        .triangle_s_valid(triangle_s_valid),
        .triangle_s_data(triangle_s_data),
        .triangle_s_metadata(triangle_s_metadata),

        .attributed_triangle_m_ready(rasterizer_ready),
        .attributed_triangle_m_valid(attributed_triangle_valid),
        .attributed_triangle_m_data(attributed_triangle),
        .attributed_triangle_m_metadata(attributed_triangle_metadata)
    );

    // Which pixel we are currently sampling.
    pixel_coordinate_t pixel_coordinate;

    // Flags to indicate if we are on the last pixel
    // of the row or the last row of the viewport.
    logic last_x, last_y;
    assign last_x = (pixel_coordinate.x == 10'(VIEWPORT_WIDTH - 1));
    assign last_y = (pixel_coordinate.y == 10'(VIEWPORT_HEIGHT - 1));

    pixel_metadata_t pixel_coordinate_metadata;
    assign pixel_coordinate_metadata.last = last_x && last_y;

    // Sample point is valid as long as we are in RUNNING state.
    logic pixel_coordinate_valid;
    assign pixel_coordinate_valid = state == RUNNING;

    // If the interpolator is ready to receive a new sample point.
    logic pixel_coordinate_ready;

    TriangleInterpolator #(
        .VIEWPORT_WIDTH(VIEWPORT_WIDTH),
        .VIEWPORT_HEIGHT(VIEWPORT_HEIGHT)
    ) interpolator (
        .clk(clk),
        .rstn(rstn),

        // We consider the interpolator is ready when it can receive new triangle.
        .attributed_triangle_s_ready(interpolator_ready),
        .attributed_triangle_s_valid(attributed_triangle_valid && rasterizer_ready),
        .attributed_triangle_s_data(attributed_triangle),
        .attributed_triangle_s_metadata(attributed_triangle_metadata),

        .pixel_coordinate_s_ready(pixel_coordinate_ready),
        .pixel_coordinate_s_valid(pixel_coordinate_valid),
        .pixel_coordinate_s_data(pixel_coordinate),
        .pixel_coordinate_s_metadata(pixel_coordinate_metadata),

        .pixel_data_m_ready(pixel_data_m_ready),
        .pixel_data_m_valid(pixel_data_m_valid),
        .pixel_data_m_data(pixel_data_m_data),
        .pixel_data_m_metadata(pixel_data_m_metadata)
    );

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            state <= IDLE;
            pixel_coordinate.x <= 0;
            pixel_coordinate.y <= 0;
        end else begin
            case (state)
                IDLE: begin
                    // Check if a new triangle has been accepted.
                    if (attributed_triangle_valid && rasterizer_ready) begin
                        // Start rasterizing if so.
                        state <= RUNNING;
                    end
                end
                RUNNING: begin
                    // Wait until sampler is ready to receive new sample point.
                    if (pixel_coordinate_ready) begin
                        // Go to the next pixel.
                        // If it is the last reset to IDLE.
                        if (last_y && last_x) begin
                            pixel_coordinate.x <= 0;
                            pixel_coordinate.y <= 0;    
                            state <= IDLE;
                        end else if (last_x) begin
                            pixel_coordinate.x <= 0;
                            pixel_coordinate.y <= pixel_coordinate.y + 1;
                        end else begin
                            pixel_coordinate.x <= pixel_coordinate.x + 1;
                        end
                    end
                end
            endcase
        end
    end
endmodule

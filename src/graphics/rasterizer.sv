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

    input logic pixel_data_m_ready,
    output logic pixel_data_m_valid,
    output pixel_data_t pixel_data_m_data
);
    typedef enum logic {
        IDLE,
        RUNNING
    } rasterizer_state;

    rasterizer_state state = IDLE;

    // Which pixel we are currently sampling.
    pixel_coordinate_t pixel_coordinate;

    // Sample point is valid as long as we are in RUNNING state.
    logic pixel_coordinate_valid;
    assign pixel_coordinate_valid = state == RUNNING;

    // If the sampler is ready to receive a new sample point.
    logic pixel_coordinate_ready;

    // We are ready to accept a new triangle when we are IDLE
    // and the sampler is ready to accept a new triangle.
    logic sampler_triangle_ready, sampler_triangle_valid;
    assign triangle_s_ready = (state == IDLE) && sampler_triangle_ready;
    assign sampler_triangle_valid = triangle_s_valid && (state == IDLE);

    TriangleSampler #(
        .VIEWPORT_WIDTH(VIEWPORT_WIDTH),
        .VIEWPORT_HEIGHT(VIEWPORT_HEIGHT)
    ) sampler (
        .clk(clk),
        .rstn(rstn),

        .triangle_s_ready(sampler_triangle_ready),
        .triangle_s_valid(sampler_triangle_valid),
        .triangle_s_data(triangle_s_data),

        .pixel_coordinate_s_ready(pixel_coordinate_ready),
        .pixel_coordinate_s_valid(pixel_coordinate_valid),
        .pixel_coordinate_s_data(pixel_coordinate),

        .pixel_data_m_ready(pixel_data_m_ready),
        .pixel_data_m_valid(pixel_data_m_valid),
        .pixel_data_m_data(pixel_data_m_data)
    );

    // Flags to indicate if we are on the last pixel
    // of the row or the last row of the viewport.
    logic last_x, last_y;
    assign last_x = (pixel_coordinate.x == 10'(VIEWPORT_WIDTH - 1));
    assign last_y = (pixel_coordinate.y == 10'(VIEWPORT_HEIGHT - 1));

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            state <= IDLE;
            pixel_coordinate.x <= 0;
            pixel_coordinate.y <= 0;
        end else begin
            case (state)
                IDLE: begin
                    // Check if a new triangle has been accepted.
                    if (sampler_triangle_ready && sampler_triangle_valid) begin
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

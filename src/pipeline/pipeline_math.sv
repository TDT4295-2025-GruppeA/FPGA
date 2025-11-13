import types_pkg::*;

// Module containing the main mathematical elements of the graphics
// pipeline. Currently contains:
// 1. Transform
// 2. Projection
// 3. Rasterization
module PipelineMath #(
    parameter int BUFFER_WIDTH = 160,
    parameter int BUFFER_HEIGHT = 120
)(
    input logic clk,
    input logic rstn,

    input logic triangle_tf_s_valid,
    output logic triangle_tf_s_ready,
    input triangle_tf_t triangle_tf_s_data,
    input triangle_tf_meta_t triangle_tf_s_metadata, 

    input  logic pixel_data_m_ready,
    output logic pixel_data_m_valid,
    output pixel_data_t pixel_data_m_data,
    output pixel_metadata_t pixel_data_m_metadata
);

    ///////////////
    // Transform //
    ///////////////

    wire logic transform_backface_culler_valid;
    wire logic transform_backface_culler_ready;
    wire triangle_t transform_backface_culler_data;
    wire triangle_meta_t transform_backface_culler_metadata;

    Transform transformer (
        .clk(clk),
        .rstn(rstn),

        .triangle_tf_s_ready(triangle_tf_s_ready),
        .triangle_tf_s_valid(triangle_tf_s_valid),
        .triangle_tf_s_data(triangle_tf_s_data),
        .triangle_tf_s_metadata(triangle_tf_s_metadata),

        .triangle_m_ready(transform_backface_culler_ready),
        .triangle_m_valid(transform_backface_culler_valid),
        .triangle_m_data(transform_backface_culler_data),
        .triangle_m_metadata(transform_backface_culler_metadata)
    );

    //////////////////////
    // Backface Culling //
    //////////////////////

    triangle_t backface_culler_projection_data;
    triangle_meta_t backface_culler_projection_metadata;
    logic backface_culler_projection_valid;
    logic backface_culler_projection_ready;

    BackfaceCuller backface_culler (
        .clk(clk),
        .rstn(rstn),

        .triangle_s_ready(transform_backface_culler_ready),
        .triangle_s_valid(transform_backface_culler_valid),
        .triangle_s_data('{ triangle: transform_backface_culler_data, keep: transform_backface_culler_metadata.last }),
        .triangle_s_metadata(transform_backface_culler_metadata),

        .triangle_m_data(backface_culler_projection_data),
        .triangle_m_metadata(backface_culler_projection_metadata),
        .triangle_m_valid(backface_culler_projection_valid),
        .triangle_m_ready(backface_culler_projection_ready)
    );

    /////////////////
    // Projection  //
    /////////////////

    triangle_t projection_rasterizer_data;
    triangle_meta_t projection_rasterizer_metadata;
    logic projection_rasterizer_valid;
    logic projection_rasterizer_ready;

    Projection #(
        .FOCAL_LENGTH(0.5),
        .VIEWPORT_WIDTH(BUFFER_WIDTH),
        .VIEWPORT_HEIGHT(BUFFER_HEIGHT)
    ) projection (
        .clk(clk),
        .rstn(rstn),

        .triangle_s_data(backface_culler_projection_data),
        .triangle_s_metadata(backface_culler_projection_metadata),
        .triangle_s_valid(backface_culler_projection_valid),
        .triangle_s_ready(backface_culler_projection_ready),

        .projected_triangle_m_data(projection_rasterizer_data),
        .projected_triangle_m_valid(projection_rasterizer_valid),
        .projected_triangle_m_metadata(projection_rasterizer_metadata),
        .projected_triangle_m_ready(projection_rasterizer_ready)
    );

    ///////////////////
    // Rasterization //
    ///////////////////

    Rasterizer #(
        .VIEWPORT_WIDTH(BUFFER_WIDTH),
        .VIEWPORT_HEIGHT(BUFFER_HEIGHT)
    ) rasterizer (
        .clk(clk),
        .rstn(rstn),

        .triangle_s_ready(projection_rasterizer_ready),
        .triangle_s_valid(projection_rasterizer_valid),
        .triangle_s_data(projection_rasterizer_data),
        .triangle_s_metadata(projection_rasterizer_metadata),

        .pixel_data_m_ready(pixel_data_m_ready),
        .pixel_data_m_valid(pixel_data_m_valid),
        .pixel_data_m_data(pixel_data_m_data),
        .pixel_data_m_metadata(pixel_data_m_metadata)
    );

endmodule
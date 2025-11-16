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
    input pipeline_entry_t triangle_tf_s_data,
    input last_t triangle_tf_s_metadata, 

    input  logic pixel_data_m_ready,
    output logic pixel_data_m_valid,
    output pixel_data_t pixel_data_m_data,
    output pixel_metadata_t pixel_data_m_metadata
);

    /////////////////////
    // Model Transform //
    /////////////////////

    wire camera_tf_last_t head_transform_metadata;
    assign head_transform_metadata.camera_transform = triangle_tf_s_data.camera_transform;
    assign head_transform_metadata.last = triangle_tf_s_metadata.last;
    triangle_tf head_transform_data;
    assign head_transform_data.triangle = triangle_tf_s_data.triangle;
    assign head_transform_data.transform = triangle_tf_s_data.model_transform;

    wire logic transform_camera_valid;
    wire logic transform_camera_ready;
    wire triangle_t transform_camera_data;
    wire camera_tf_last_t transform_camera_metadata;

    Transform #(
        .TRIANGLE_META_WIDTH($bits(camera_tf_last_t))
    ) transformer_model (
        .clk(clk),
        .rstn(rstn),

        .triangle_tf_s_ready(triangle_tf_s_ready),
        .triangle_tf_s_valid(triangle_tf_s_valid),
        .triangle_tf_s_data(head_transform_data),
        .triangle_tf_s_metadata(head_transform_metadata),

        .triangle_m_ready(transform_camera_ready),
        .triangle_m_valid(transform_camera_valid),
        .triangle_m_data(transform_camera_data),
        .triangle_m_metadata(transform_camera_metadata)
    );

    //////////////////////
    // Camera transform //
    //////////////////////
    triangle_tf transform_camera_data_tf;
    assign transform_camera_data_tf.triangle = transform_camera_data;
    assign transform_camera_data_tf.transform = transform_camera_metadata.camera_transform;

    logic camera_backface_culler_ready;
    logic camera_backface_culler_valid;
    triangle_t camera_backface_culler_data;
    last_t camera_backface_culler_metadata;
    Transform #(
        .TRIANGLE_META_WIDTH($bits(last_t))
    ) transformer_camera (
        .clk(clk),
        .rstn(rstn),

        .triangle_tf_s_ready(transform_camera_ready),
        .triangle_tf_s_valid(transform_camera_valid),
        .triangle_tf_s_data(transform_camera_data_tf),
        .triangle_tf_s_metadata(transform_camera_metadata.last),

        .triangle_m_ready(camera_backface_culler_ready),
        .triangle_m_valid(camera_backface_culler_valid),
        .triangle_m_data(camera_backface_culler_data),
        .triangle_m_metadata(camera_backface_culler_metadata)
    );

    //////////////////////
    // Backface Culling //
    //////////////////////

    triangle_t backface_culler_projection_data;
    last_t backface_culler_projection_metadata;
    logic backface_culler_projection_valid;
    logic backface_culler_projection_ready;

    BackfaceCuller backface_culler (
        .clk(clk),
        .rstn(rstn),

        .triangle_s_ready(camera_backface_culler_ready),
        .triangle_s_valid(camera_backface_culler_valid),
        .triangle_s_data('{ triangle: camera_backface_culler_data, keep: camera_backface_culler_metadata.last }),
        .triangle_s_metadata(camera_backface_culler_metadata),

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
        .FOCAL_LENGTH(0.3),
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
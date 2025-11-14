import types_pkg::*;

// Module to manage the head of the pipeline
// Just connects modules together making up the pipeline head:
// CommandInput
//     Reads bytes from input - bytes are expected to be in the command
//     data format. Commands are read, parallelized and written to
//     modelbuffer/scenebuffer
// ModelBuffer
//     Stores all the triangles for a model
// SceneBuffer
//     Stores the transforms that make up a scene
// SceneReader
//     Reads the transforms in a scene, and pairs it up with every
//     triangle in the specified model. This result is outputted to
//     use in the rest of the pipeline.
module PipelineHead(
    input clk,
    input rstn,

    // Command input
    input  logic  cmd_s_valid,
    output logic  cmd_s_ready,
    input  byte_t cmd_s_data,

    // Command response
    input  logic  cmd_m_ready,
    output logic  cmd_m_valid,
    output byte_t cmd_m_data,

    // Command system reset signal
    output logic cmd_reset,

    // To graphics pipeline
    output logic                triangle_tf_m_valid,
    input  logic                triangle_tf_m_ready,
    output triangle_tf_t        triangle_tf_m_data,
    output triangle_tf_meta_t   triangle_tf_m_metadata
);
    localparam MAX_MODEL_COUNT = 10;
    localparam MAX_TRIANGLE_COUNT = 1024;

    wire modelbuf_write_t cmd_model_data;
    wire logic cmd_model_valid;
    wire logic cmd_model_ready;

    wire modelinstance_t cmd_scene_data;
    wire modelinstance_meta_t cmd_scene_metadata;
    wire logic cmd_scene_valid;
    wire logic cmd_scene_ready;
    CommandInput cmd_inst (
        .clk(clk),
        .rstn(rstn),

        .cmd_s_valid(cmd_s_valid),
        .cmd_s_ready(cmd_s_ready),
        .cmd_s_data(cmd_s_data),

        .cmd_m_ready(cmd_m_ready),
        .cmd_m_valid(cmd_m_valid),
        .cmd_m_data(cmd_m_data),

        .cmd_reset(cmd_reset),

        .model_m_valid(cmd_model_valid),
        .model_m_ready(cmd_model_ready),
        .model_m_data(cmd_model_data),

        .scene_m_valid(cmd_scene_valid),
        .scene_m_ready(cmd_scene_ready),
        .scene_m_data(cmd_scene_data),
        .scene_m_metadata(cmd_scene_metadata)
    );

    // Modelbuffer
    wire read_model_valid;
    wire read_model_ready;
    wire modelbuf_read_t read_model_data;

    wire model_read_valid;
    wire model_read_ready;
    wire triangle_t model_read_data;
    wire triangle_meta_t model_read_metadata;

    ModelBuffer #(
        .MAX_MODEL_COUNT(MAX_MODEL_COUNT),
        .MAX_TRIANGLE_COUNT(MAX_TRIANGLE_COUNT)
    ) modelbuffer_inst (
        .clk(clk),
        .rstn(rstn),

        .write_s_valid(cmd_model_valid),
        .write_s_ready(cmd_model_ready),
        .write_s_data(cmd_model_data),

        .read_s_valid(read_model_valid),
        .read_s_ready(read_model_ready),
        .read_s_data(read_model_data),

        .read_m_valid(model_read_valid),
        .read_m_ready(model_read_ready),
        .read_m_data(model_read_data),
        .read_m_metadata(model_read_metadata)
    );
    // Scenebuffer
    wire scene_read_valid;
    wire scene_read_ready;
    wire modelinstance_t scene_read_data;
    wire modelinstance_meta_t scene_read_metadata;
    SceneBuffer #(
        .SCENE_COUNT(2),
        .TRANSFORM_COUNT(50)
    ) scenebuffer_inst (
        .clk(clk),
        .rstn(rstn),

        .write_s_valid(cmd_scene_valid),
        .write_s_ready(cmd_scene_ready),
        .write_s_data(cmd_scene_data),
        .write_s_metadata(cmd_scene_metadata),

        .read_m_valid(scene_read_valid),
        .read_m_ready(scene_read_ready),
        .read_m_data(scene_read_data),
        .read_m_metadata(scene_read_metadata)
    );

    SceneReader #(
        .MAX_MODEL_COUNT(MAX_MODEL_COUNT),
        .MAX_TRIANGLE_COUNT(MAX_TRIANGLE_COUNT)
    ) scenereader_inst (
        .clk(clk),
        .rstn(rstn),

        .scene_s_valid(scene_read_valid),
        .scene_s_ready(scene_read_ready),
        .scene_s_data(scene_read_data),
        .scene_s_metadata(scene_read_metadata),

        .model_m_valid(read_model_valid),
        .model_m_ready(read_model_ready),
        .model_m_data(read_model_data),

        .model_s_valid(model_read_valid),
        .model_s_ready(model_read_ready),
        .model_s_data(model_read_data),
        .model_s_metadata(model_read_metadata),

        .triangle_tf_m_valid(triangle_tf_m_valid),
        .triangle_tf_m_ready(triangle_tf_m_ready),
        .triangle_tf_m_data(triangle_tf_m_data),
        .triangle_tf_m_metadata(triangle_tf_m_metadata)
    );
endmodule
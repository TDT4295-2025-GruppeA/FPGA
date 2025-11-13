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
    input  logic  cmd_in_valid,
    output logic  cmd_in_ready,
    input  byte_t cmd_in_data,

    // Command response
    input  logic  cmd_out_ready,
    output logic  cmd_out_valid,
    output byte_t cmd_out_data,

    // Command system reset signal
    output logic cmd_reset,

    // To graphics pipeline
    output logic                triangle_tf_out_valid,
    input  logic                triangle_tf_out_ready,
    output triangle_tf_t        triangle_tf_out_data,
    output triangle_tf_meta_t   triangle_tf_out_metadata
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

        .cmd_in_valid(cmd_in_valid),
        .cmd_in_ready(cmd_in_ready),
        .cmd_in_data(cmd_in_data),

        .cmd_out_ready(cmd_out_ready),
        .cmd_out_valid(cmd_out_valid),
        .cmd_out_data(cmd_out_data),

        .cmd_reset(cmd_reset),

        .model_out_valid(cmd_model_valid),
        .model_out_ready(cmd_model_ready),
        .model_out_data(cmd_model_data),

        .scene_out_valid(cmd_scene_valid),
        .scene_out_ready(cmd_scene_ready),
        .scene_out_data(cmd_scene_data),
        .scene_out_metadata(cmd_scene_metadata)
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

        .write_in_valid(cmd_model_valid),
        .write_in_ready(cmd_model_ready),
        .write_in_data(cmd_model_data),

        .read_in_valid(read_model_valid),
        .read_in_ready(read_model_ready),
        .read_in_data(read_model_data),

        .read_out_valid(model_read_valid),
        .read_out_ready(model_read_ready),
        .read_out_data(model_read_data),
        .read_out_metadata(model_read_metadata)
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

        .write_in_valid(cmd_scene_valid),
        .write_in_ready(cmd_scene_ready),
        .write_in_data(cmd_scene_data),
        .write_in_metadata(cmd_scene_metadata),

        .read_out_valid(scene_read_valid),
        .read_out_ready(scene_read_ready),
        .read_out_data(scene_read_data),
        .read_out_metadata(scene_read_metadata)
    );

    SceneReader #(
        .MAX_MODEL_COUNT(MAX_MODEL_COUNT),
        .MAX_TRIANGLE_COUNT(MAX_TRIANGLE_COUNT)
    ) scenereader_inst (
        .clk(clk),
        .rstn(rstn),

        .scene_in_valid(scene_read_valid),
        .scene_in_ready(scene_read_ready),
        .scene_in_data(scene_read_data),
        .scene_in_metadata(scene_read_metadata),

        .model_out_valid(read_model_valid),
        .model_out_ready(read_model_ready),
        .model_out_data(read_model_data),

        .model_in_valid(model_read_valid),
        .model_in_ready(model_read_ready),
        .model_in_data(model_read_data),
        .model_in_metadata(model_read_metadata),

        .triangle_tf_out_valid(triangle_tf_out_valid),
        .triangle_tf_out_ready(triangle_tf_out_ready),
        .triangle_tf_out_data(triangle_tf_out_data),
        .triangle_tf_out_metadata(triangle_tf_out_metadata)
    );
endmodule
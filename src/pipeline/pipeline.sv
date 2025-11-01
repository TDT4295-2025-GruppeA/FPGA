// This module is a collection conneting parts of the pipeline together.
// These parts are:
// Pipeline head - command handling, model/scene storage, feed pipeline
// Pipeline math - Main calculations, transform, projection, rasterizer etc..
// Pipeline tail - put rendered pixels in framebuffer and output vga
module Pipeline #(
    parameter BUFFER_WIDTH = 160,
    parameter BUFFER_HEIGHT = 120
)(
    input clk,
    input rstn,

    input logic cmd_in_valid,
    output logic cmd_in_ready,
    input byte_t cmd_in_data,

    output logic cmd_out_valid,
    input logic cmd_out_ready,
    output byte_t cmd_out_data,

    // VGA output
    output logic pixel_m_valid,
    input logic pixel_m_ready,
    output pixel_data_t pixel_m_data,
    output pixel_metadata_t pixel_m_metadata
);

    wire logic head_math_valid;
    wire logic head_math_ready;
    wire triangle_tf_t head_math_data;
    wire triangle_tf_meta_t head_math_metadata;
    PipelineHead pipeline_head(
        .clk(clk),
        .rstn(rstn),

        .cmd_in_valid(cmd_in_valid),
        .cmd_in_ready(cmd_in_ready),
        .cmd_in_data(cmd_in_data),

        .cmd_out_valid(cmd_out_valid),
        .cmd_out_ready(cmd_out_ready),
        .cmd_out_data(cmd_out_data),
        
        .triangle_tf_out_valid(head_math_valid),
        .triangle_tf_out_ready(head_math_ready),
        .triangle_tf_out_data(head_math_data),
        .triangle_tf_out_metadata(head_math_metadata)
    );

    wire logic math_tail_ready;
    wire logic math_tail_valid;
    wire pixel_data_t math_tail_data;
    wire pixel_metadata_t math_tail_metadata;

    PipelineMath #(
        .BUFFER_WIDTH(BUFFER_WIDTH),
        .BUFFER_HEIGHT(BUFFER_HEIGHT)
    ) pipelinemath_inst (
        .clk(clk),
        .rstn(rstn),

        .triangle_tf_s_ready(head_math_ready),
        .triangle_tf_s_valid(head_math_valid),
        .triangle_tf_s_data(head_math_data),
        .triangle_tf_s_metadata(head_math_metadata),

        .pixel_data_m_ready(math_tail_ready),
        .pixel_data_m_valid(math_tail_valid),
        .pixel_data_m_data(math_tail_data),
        .pixel_data_m_metadata(math_tail_metadata)
    );
    assign pixel_m_valid = math_tail_valid;
    assign math_tail_ready = pixel_m_ready;
    assign pixel_m_data = math_tail_data;
    assign pixel_m_metadata = math_tail_metadata;
    // PipelineTail pipeline_tail (

    // );
endmodule
import video_modes_pkg::*;
import buffer_config_pkg::*;

// This module is a collection conneting parts of the pipeline together.
// These parts are:
// Pipeline head - command handling, model/scene storage, feed pipeline
// Pipeline math - Main calculations, transform, projection, rasterizer etc..
// Pipeline tail - put rendered pixels in framebuffer and output vga
module Pipeline #(
    parameter buffer_config_t BUFFER_CONFIG = BUFFER_160x120x12,
    parameter video_mode_t VIDEO_MODE = VMODE_640x480p60
)(
    input clk_system,
    input rstn_system,

    input clk_display,
    input rstn_display,

    input logic cmd_in_valid,
    output logic cmd_in_ready,
    input byte_t cmd_in_data,

    output logic cmd_out_valid,
    input logic cmd_out_ready,
    output byte_t cmd_out_data,

    output logic vga_hsync,
    output logic vga_vsync,
    output logic[3:0] vga_red,
    output logic[3:0] vga_green,
    output logic[3:0] vga_blue,

    // debug
    input logic [3:0] sw

);

    wire logic head_math_valid;
    wire logic head_math_ready;
    wire triangle_tf_t head_math_data;
    wire triangle_tf_meta_t head_math_metadata;
    PipelineHead pipeline_head(
        .clk(clk_system),
        .rstn(rstn_system),

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
        .BUFFER_WIDTH(BUFFER_CONFIG.width),
        .BUFFER_HEIGHT(BUFFER_CONFIG.height)
    ) pipeline_math (
        .clk(clk_system),
        .rstn(rstn_system),

        .triangle_tf_s_ready(head_math_ready),
        .triangle_tf_s_valid(head_math_valid),
        .triangle_tf_s_data(head_math_data),
        .triangle_tf_s_metadata(head_math_metadata),

        .pixel_data_m_ready(math_tail_ready),
        .pixel_data_m_valid(math_tail_valid),
        .pixel_data_m_data(math_tail_data),
        .pixel_data_m_metadata(math_tail_metadata)
    );

    PipelineTail #(
        .BUFFER_CONFIG(BUFFER_CONFIG),
        .VIDEO_MODE(VIDEO_MODE)
    ) pipeline_tail (
        .clk_system(clk_system),
        .rstn_system(rstn_system),

        .clk_display(clk_display),
        .rstn_display(rstn_display),

        .pixel_data_s_ready(math_tail_ready),
        .pixel_data_s_valid(math_tail_valid),
        .pixel_data_s_data(math_tail_data),
        .pixel_data_s_metadata(math_tail_metadata),

        .vga_hsync(vga_hsync),
        .vga_vsync(vga_vsync),
        .vga_red(vga_red),
        .vga_green(vga_green),
        .vga_blue(vga_blue),

        .sw(sw)
    );

endmodule
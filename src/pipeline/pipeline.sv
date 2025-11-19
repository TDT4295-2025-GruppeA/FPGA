import video_modes_pkg::*;
import buffer_config_pkg::*;

// This module is a collection conneting parts of the pipeline together.
// These parts are:
// Pipeline head - command handling, model/scene storage, feed pipeline
// Pipeline math - Main calculations, transform, projection, rasterizer etc..
// Pipeline tail - put rendered pixels in framebuffer and output vga
module Pipeline #(
    parameter buffer_config_t BUFFER_CONFIG = BUFFER_160x120x12,
    parameter video_mode_t VIDEO_MODE = VMODE_640x480p60,
    parameter bit IGNORE_DRAW_ACK = 0,
    parameter bit FLIP_VERTICAL = 0,
    parameter bit FLIP_HORIZONTAL = 0
)(
    input clk_system,
    input rstn_system,

    input clk_display,
    input rstn_display,

    input logic cmd_s_valid,
    output logic cmd_s_ready,
    input byte_t cmd_s_data,

    output logic cmd_m_valid,
    input logic cmd_m_ready,
    output byte_t cmd_m_data,

    output logic cmd_reset,

    output logic vga_hsync,
    output logic vga_vsync,
    output logic screen_data_enable,
    output color_red_t vga_red,
    output color_green_t vga_green,
    output color_blue_t vga_blue,

    // debug
    input logic debug_depth_buffer,
    input logic debug_active_frame_buffer
);

    wire logic head_math_valid;
    wire logic head_math_ready;
    wire pipeline_entry_t head_math_data;
    wire last_t head_math_metadata;
    PipelineHead pipeline_head(
        .clk(clk_system),
        .rstn(rstn_system),

        .cmd_s_valid(cmd_s_valid),
        .cmd_s_ready(cmd_s_ready),
        .cmd_s_data(cmd_s_data),

        .cmd_m_valid(cmd_m_valid),
        .cmd_m_ready(cmd_m_ready),
        .cmd_m_data(cmd_m_data),

        .cmd_reset(cmd_reset),
        
        .triangle_tf_m_valid(head_math_valid),
        .triangle_tf_m_ready(head_math_ready),
        .triangle_tf_m_data(head_math_data),
        .triangle_tf_m_metadata(head_math_metadata)
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
        .VIDEO_MODE(VIDEO_MODE),
        .IGNORE_DRAW_ACK(IGNORE_DRAW_ACK),
        .FLIP_VERTICAL(FLIP_VERTICAL),
        .FLIP_HORIZONTAL(FLIP_HORIZONTAL)
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
        .screen_data_enable(screen_data_enable),
        .vga_red(vga_red),
        .vga_green(vga_green),
        .vga_blue(vga_blue),

        .debug_depth_buffer(debug_depth_buffer),
        .debug_active_frame_buffer(debug_active_frame_buffer)
    );

endmodule
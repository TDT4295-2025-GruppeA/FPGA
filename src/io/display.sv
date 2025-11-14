// Inspired by projectf:
// https://github.com/projf/projf-explore/blob/main/lib/clock/xc7/clock_480p.sv

import video_modes_pkg::*;
import buffer_config_pkg::*;
import types_pkg::*;

module Display #(
    parameter video_mode_t VIDEO_MODE = VMODE_640x480p60,
    parameter buffer_config_t BUFFER_CONFIG = BUFFER_160x120x12
)(
    input logic clk_pixel,
    input logic rstn_pixel,

    output logic vga_hsync,
    output logic vga_vsync,
    output logic[3:0] vga_red,
    output logic[3:0] vga_green,
    output logic[3:0] vga_blue,

    output logic[BUFFER_CONFIG.addr_width-1:0] read_addr,
    input color_t read_data
);
    // Generate pixel coords and hsync/vsync
    localparam int H_RESOLUTION = VIDEO_MODE.h_resolution;
    localparam int H_FRONT_PORCH = VIDEO_MODE.h_front_porch;
    localparam int H_SYNC = VIDEO_MODE.h_sync;
    localparam int H_BACK_PORCH = VIDEO_MODE.h_back_porch;
    localparam int LINEWIDTH = H_RESOLUTION + H_FRONT_PORCH + H_SYNC + H_BACK_PORCH;

    localparam int V_RESOLUTION = VIDEO_MODE.v_resolution;
    localparam int V_FRONT_PORCH = VIDEO_MODE.v_front_porch;
    localparam int V_SYNC = VIDEO_MODE.v_sync;
    localparam int V_BACK_PORCH = VIDEO_MODE.v_back_porch;
    localparam int LINEHEIGHT = V_RESOLUTION + V_FRONT_PORCH + V_SYNC + V_BACK_PORCH;

    localparam int VW = $clog2(LINEWIDTH) + 1;
    localparam int VH = $clog2(LINEHEIGHT) + 1;
    logic [VW - 1:0] x;
    logic [VH - 1:0] y;

    // Set hsync and vsync flags
    logic hsync, vsync;
    logic hsync_nopol, vsync_nopol;
    logic data_enable;
    always_comb begin
        hsync_nopol = (x >= VW'(H_RESOLUTION-1 + H_FRONT_PORCH) 
                    && x < VW'(H_RESOLUTION-1 + H_FRONT_PORCH + H_SYNC));
        vsync_nopol = (y >= VH'(V_RESOLUTION-1 + V_FRONT_PORCH)
                    && y < VH'(V_RESOLUTION-1 + V_FRONT_PORCH + V_SYNC));

        hsync = (VIDEO_MODE.h_sync_pol) ? hsync_nopol : ~hsync_nopol;
        vsync = (VIDEO_MODE.v_sync_pol) ? vsync_nopol : ~vsync_nopol;
        data_enable = (x <= VW'(H_RESOLUTION - 1)
                    && y <= VH'(V_RESOLUTION - 1));
    end

    always_ff @(posedge clk_pixel or negedge rstn_pixel) begin
        if (x == VW'(LINEWIDTH-1)) begin
            x <= 0;
            if (y == VH'(LINEHEIGHT-1)) begin
                y <= 0;
            end else begin
                y <= y + 1;
            end
        end else begin
            x <= x + 1;
        end

        // Reset values
        if (!rstn_pixel) begin
            x <= 0;
            y <= 0;
        end
    end

    // Assign read address from VGA controller to the output port
    localparam int SCALE = $clog2(VIDEO_MODE.h_resolution / BUFFER_CONFIG.width);
    assign read_addr = BUFFER_CONFIG.addr_width'(
        ((32'(y) >> SCALE) * BUFFER_CONFIG.width) + (32'(x) >> SCALE)
    );

    // Use the single read_data input to drive the VGA color outputs
    logic [3:0] paint_r, paint_g, paint_b;
    logic [3:0] display_r, display_g, display_b;
    always_comb begin
        paint_r = read_data[3:0];
        paint_g = read_data[7:4];
        paint_b = read_data[11:8];

        display_r = (data_enable) ? paint_r : 4'h0;
        display_g = (data_enable) ? paint_g : 4'h0;
        display_b = (data_enable) ? paint_b : 4'h0;
    end

    // Flip-flops for output
    logic hsync_delay;
    logic vsync_delay;
    logic hsync_delay2;
    logic vsync_delay2;
    always_ff @(posedge clk_pixel) begin
        hsync_delay <= hsync;
        vsync_delay <= vsync;
        hsync_delay2 <= hsync_delay;
        vsync_delay2 <= vsync_delay;
        vga_hsync <= hsync_delay2;
        vga_vsync <= vsync_delay2;
        vga_red <= display_r;
        vga_green <= display_g;
        vga_blue <= display_b;
    end
endmodule
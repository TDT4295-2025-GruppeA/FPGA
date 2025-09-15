// Inspired by projectf:
// https://github.com/projf/projf-explore/blob/main/lib/clock/xc7/clock_480p.sv

import video_modes_pkg::*;

module Display #(
    parameter video_mode_t VIDEO_MODE = VMODE_640x480p60,
    parameter int BUFFER_WIDTH = 320,
    parameter int BUFFER_HEIGHT = 240,
    parameter int BUFFER_DATA_WIDTH = 12
) (
    input logic clk_pixel,
    input logic rstn_pixel,

    output logic vga_hsync,
    output logic vga_vsync,
    output logic[3:0] vga_red,
    output logic[3:0] vga_green,
    output logic[3:0] vga_blue
);
    // Generate pixel coords and hsync/vsync
    // TODO: this can probably be simplified.
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


    // These are intentionally 1 bit wider than resolution, due to
    // front+back porch and sync window.
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


    // Iterate through pixels in image
    always_ff @(posedge clk_pixel or negedge rstn_pixel) begin
        if (x == VW'(LINEWIDTH-1)) begin
            x <= 0;
            y <= (y == VH'(LINEHEIGHT-1)) ? 0 : y + 1;
        end else begin
            x <= x + 1;
        end

        // Reset values
        if (!rstn_pixel) begin
            x <= 0;
            y <= 0;
        end
    end


    // TODO: move this to drawing module or something. Not here.
    // ##############################
    // ##### Drawing from image #####
    // ##############################

    localparam int BUFFER_SIZE = BUFFER_WIDTH * BUFFER_HEIGHT;
    // Determine the address width required for the buffer
    localparam int BUFFER_ADDR_WIDTH = $clog2(BUFFER_SIZE);
    logic[BUFFER_ADDR_WIDTH-1:0] pixel_addr;
    logic[BUFFER_DATA_WIDTH-1:0] fb_data;
    
    // Only scales based on width, and assumes a multiple of 2.
    localparam int SCALE = $clog2(H_RESOLUTION / BUFFER_WIDTH);
    assign pixel_addr = (32'(y) >> SCALE) * BUFFER_WIDTH + (32'(x) >> SCALE);

    Buffer #(
        .FILE_SOURCE("static/red_320x240p12.mem"),
        .FILE_SIZE(BUFFER_WIDTH * BUFFER_HEIGHT),
        .DATA_WIDTH(BUFFER_DATA_WIDTH)
    ) buffer_inst (
        .clk(clk_pixel),
        .rstn(rstn_pixel),
        .addr(pixel_addr),
        .data(fb_data)
    );

    // Draw from image buffer
    logic [3:0] paint_r, paint_g, paint_b;
    logic [3:0] display_r, display_g, display_b;
    always_comb begin
        paint_r = fb_data[3:0];
        paint_g = fb_data[7:4];
        paint_b = fb_data[11:8];

        display_r = (data_enable) ? paint_r : 4'h0;
        display_g = (data_enable) ? paint_g : 4'h0;
        display_b = (data_enable) ? paint_b : 4'h0;
    end

    // Flip-flops for output
    // TODO: remove/simplify
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

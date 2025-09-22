// Inspired by projectf:
// https://github.com/projf/projf-explore/blob/main/lib/clock/xc7/clock_480p.sv

import video_modes_pkg::*;
import fixed_pkg::*;

module Display #(
    parameter video_mode_t VIDEO_MODE = VMODE_640x480p60,
    parameter int BUFFER_WIDTH = 320,
    parameter int BUFFER_HEIGHT = 240
) (
    input logic [3:0] sws,
    input logic [2:0] btns,
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

    // TODO: dynamic scaled pixel_addr
    logic[31:0] pixel_addr;
    // logic[11:0] fb_data;
    
    // Only scales based on width, and assumes a multiple of 2.
    localparam int SCALE = $clog2(H_RESOLUTION / BUFFER_WIDTH);
    assign pixel_addr = (32'(y) >> 1) * BUFFER_WIDTH + (32'(x) >> 1);

    // Buffer #(
    //     .FILE_SOURCE("static/red_320x240p12.mem"),
    //     .FILE_SIZE(BUFFER_WIDTH * BUFFER_HEIGHT)
    // ) buffer_inst (
    //     .clk(clk_pixel),
    //     .rstn(rstn_pixel),
    //     .addr(pixel_addr),
    //     .data(fb_data)
    // );

    (* ram_style = "block" *) logic buffer[BUFFER_WIDTH*BUFFER_HEIGHT];

    fixed v0 [3] = '{itof( 50), itof( 50), itof(  0)};
    fixed v1 [3] = '{itof(100), itof(200), itof(  0)};
    fixed v2 [3] = '{itof(250), itof(  0), itof(  0)};

    localparam fixed dx = rtof(0.5);
    localparam fixed dy = rtof(0.5);

    logic [12:0] px;
    logic [12:0] py;
    logic pc;

    logic [18:0] counter = 0;

    // Use sws to select vertex and direction
    // sws[0] = select v0
    // sws[1] = select v1
    // sws[2] = select v2
    // sws[3] = horizontal/vertical
    // Use btns to move selected vertex
    // btns[0] = forward
    // btns[1] = backward
    // (btns[2] = unused)
    always_ff @(posedge clk_pixel or negedge rstn_pixel) begin
        if (!rstn_pixel) begin
            counter <= 0;
            v0[0] <= itof(50);
            v0[1] <= itof(50);
            v0[2] <= itof(0);
            v1[0] <= itof(100);
            v1[1] <= itof(200);
            v1[2] <= itof(0);
            v2[0] <= itof(250);
            v2[1] <= itof(0);
            v2[2] <= itof(0);
        end else begin
            // Slow down movment using counter
            // Overflow is intentional
            counter <= counter + 1;

            if (btns[0] && counter == 0) begin
                if (sws[3] == 1'b0) begin
                    if (sws[0]) v0[0] <= v0[0] + dx;
                    if (sws[1]) v1[0] <= v1[0] + dx;
                    if (sws[2]) v2[0] <= v2[0] + dx;
                end else begin
                    if (sws[0]) v0[1] <= v0[1] + dy;
                    if (sws[1]) v1[1] <= v1[1] + dy;
                    if (sws[2]) v2[1] <= v2[1] + dy;
                end
            end

            if (btns[1] && counter == 0) begin
                if (sws[3] == 1'b0) begin
                    if (sws[0]) v0[0] <= v0[0] - dx;
                    if (sws[1]) v1[0] <= v1[0] - dx;
                    if (sws[2]) v2[0] <= v2[0] - dx;
                end else begin
                    if (sws[0]) v0[1] <= v0[1] - dy;
                    if (sws[1]) v1[1] <= v1[1] - dy;
                    if (sws[2]) v2[1] <= v2[1] - dy;
                end
            end
        end
    end

    logic ready;

    Rasterizer #(
        .WIDTH(BUFFER_WIDTH),
        .HEIGHT(BUFFER_HEIGHT)
    ) rasterizer_inst (
        .clk(clk_pixel),
        .rstn(rstn_pixel),
        .start(1'b1),
        .pixel_x(px),
        .pixel_y(py),
        .pixel_covered(pc),
        .vertex0(v0),
        .vertex1(v1),
        .vertex2(v2),
        .ready(ready)
    );

    always_ff @(posedge clk_pixel) begin
        buffer[py * BUFFER_WIDTH + px] <= pc;
    end

    logic de;
    always_ff @(posedge clk_pixel) begin
        de <= buffer[pixel_addr];
    end

    // Draw from image buffer
    logic [3:0] paint_r, paint_g, paint_b;
    logic [3:0] display_r, display_g, display_b;
    always_comb begin
        paint_r = 4'hF; // fb_data[3:0];
        paint_g = 4'hF; // fb_data[7:4];
        paint_b = 4'hF; // fb_data[11:8];

        display_r = (data_enable && de) ? paint_r : 4'h0;
        display_g = (data_enable && de) ? paint_g : 4'h0;
        display_b = (data_enable && de) ? paint_b : 4'h0;
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

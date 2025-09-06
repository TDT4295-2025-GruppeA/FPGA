// Inspired by projectf
// https://github.com/projf/projf-explore/blob/main/lib/clock/xc7/clock_480p.sv

import video_mode_pkg::*;

module Display #(
    parameter video_mode_t VIDEO_MODE = VMODE_640x480p60
) (
    input logic clk_100m,
    input logic rstn,

    output logic vga_hsync,
    output logic vga_vsync,
    output logic[3:0] vga_red,
    output logic[3:0] vga_green,
    output logic[3:0] vga_blue
);

    // Generate pixel clock
    logic pixel_clk;
    logic pixel_clk_rstn;
    DisplayClock  #(
        .MASTER_MULTIPLY(VIDEO_MODE.master_mul),
        .MASTER_DIVIDE(VIDEO_MODE.master_div),
        .CLK_DIVIDE_F(VIDEO_MODE.clk_div_f)
    ) display_clock (
        .clk_100m(clk_100m),
        .rstn(rstn),
        
        .pixel_clk(pixel_clk),
        .pixel_clk_rstn(pixel_clk_rstn)
    );

    // Generate pixel coords and hsync/vsync
    // TODO: this can probably be simplified.
    localparam H_RESOLUTION = VIDEO_MODE.h_resolution - 1;
    localparam H_FRONT_PORCH = VIDEO_MODE.h_front_porch;
    localparam H_SYNC = VIDEO_MODE.h_sync;
    localparam H_BACK_PORCH = VIDEO_MODE.h_back_porch;
    localparam LINEWIDTH = H_RESOLUTION + H_FRONT_PORCH + H_SYNC + H_BACK_PORCH;

    localparam V_RESOLUTION = VIDEO_MODE.v_resolution - 1;
    localparam V_FRONT_PORCH = VIDEO_MODE.v_front_porch;
    localparam V_SYNC = VIDEO_MODE.v_sync;
    localparam V_BACK_PORCH = VIDEO_MODE.v_back_porch;
    localparam LINEHEIGHT = V_RESOLUTION + V_FRONT_PORCH + V_SYNC + V_BACK_PORCH;

    logic [$clog2(LINEWIDTH):0] x;
    logic [$clog2(LINEHEIGHT):0] y;

    // Set hsync and vsync flags
    logic hsync, vsync;
    logic hsync_nopol, vsync_nopol;
    logic data_enable;
    always_comb begin
        hsync_nopol = (x >= (H_RESOLUTION + H_FRONT_PORCH) && x < (H_RESOLUTION + H_FRONT_PORCH + H_SYNC));
        vsync_nopol = (y >= (V_RESOLUTION + V_FRONT_PORCH) && y < (V_RESOLUTION + V_FRONT_PORCH + V_SYNC));
        hsync = (VIDEO_MODE.h_sync_pol) ? hsync_nopol : ~hsync_nopol;
        vsync = (VIDEO_MODE.v_sync_pol) ? vsync_nopol : ~vsync_nopol;
        data_enable = (x <= H_RESOLUTION && y <= V_RESOLUTION);
    end


    // Iterate through pixels in image
    always_ff @(posedge pixel_clk or negedge pixel_clk_rstn) begin
        if (x == LINEWIDTH) begin
            x <= 0;
            y <= (y == LINEHEIGHT) ? 0 : y + 1;
        end else begin
            x <= x + 1;
        end

        // Reset values
        if (!pixel_clk_rstn) begin
            x <= 0;
            y <= 0;
        end
    end


    // TODO: move this to drawing module or something. Not here.
    // ##############################
    // ##### Drawing from image #####
    // ##############################


    logic[31:0] pixel_addr;
    logic[11:0] fb_data;
    Buffer #(
        .FILE_SOURCE("static/forelesere_640x480p12.mem")
    ) buffer_inst (
        .clk(pixel_clk),
        .rstn(pixel_clk_rstn),
        .addr(pixel_addr),
        .data(fb_data)
    );

    always_ff @(posedge pixel_clk) begin
        // TODO: fix +1 thing
        // TODO: currently letting it overflow. do something about that?
        pixel_addr <= y * (H_RESOLUTION + 1) + x;
    end

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


    // ####################################
    // ##### Drawing stuff with maths #####
    // ####################################


    // logic [3:0] paint_r, paint_g, paint_b;
    // always_comb begin
    //     paint_r =   x; // (square) ? 4'hF : 4'h0;
    //     paint_g =   y; // (square) ? 4'hF : 4'h0;
    //     paint_b = 4'hF; // (square) ? 4'hF : 4'h0;
    // end

    // // display colour: paint colour but black in blanking interval
    // logic [3:0] display_r, display_g, display_b;
    // always_comb begin
    //     display_r = (data_enable) ? paint_r : 4'h0;
    //     display_g = (data_enable) ? paint_g : 4'h0;
    //     display_b = (data_enable) ? paint_b : 4'h0;
    // end

    
    // Flip-flopts for output
    logic hsync_delay;
    logic vsync_delay;
    always_ff @(posedge pixel_clk) begin
        hsync_delay <= hsync;
        vsync_delay <= vsync;
        vga_hsync <= hsync_delay;
        vga_vsync <= vsync_delay;
        vga_red <= display_r;
        vga_green <= display_g;
        vga_blue <= display_b;
    end
endmodule
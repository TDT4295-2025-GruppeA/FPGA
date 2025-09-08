import video_modes_pkg::*;
import clock_modes_pkg::*;

module Top (
    input btn,
    output led,

    input logic clk_ext, // 100MHz for now
    input logic reset,

    // VGA control
    output logic vga_hsync,
    output logic vga_vsync,
    output logic[3:0] vga_red,
    output logic[3:0] vga_green,
    output logic[3:0] vga_blue
);
    localparam video_mode_t VIDEO_MODE = VMODE_640x480p60;

    assign led = btn;

    ////////////////////////////////////////////////
    ////////////// CLOCK GENERATION ////////////////
    ////////////////////////////////////////////////

    logic clk_display;
    logic rstn_display;

    logic clk_system;
    logic rstn_system;

    ClockManager #(
        .CLK_DISPLAY(VIDEO_MODE.clock_config),
        .CLK_SYSTEM(CLK_100_50_MHZ)
    )(
        .clk_ext(clk_ext),
        .reset(reset),

        .clk_system(clk_system),
        .rstn_system(rstn_system),

        .clk_display(clk_display),
        .rstn_display(rstn_display)
    );


    ///////////////////////////////////////
    ////////////// DISPLAY ////////////////
    ///////////////////////////////////////

    Display #(
        .VIDEO_MODE(VIDEO_MODE)
    ) display (
        .clk_pixel(clk_display),
        .rstn_pixel(rstn_display),

        .vga_hsync(vga_hsync),
        .vga_vsync(vga_vsync),
        .vga_red(vga_red),
        .vga_green(vga_green),
        .vga_blue(vga_blue)
    );

endmodule



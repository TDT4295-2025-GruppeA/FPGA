import video_modes_pkg::*;
import clock_modes_pkg::*;

module Top (
    // Fun stuff
    input logic [2:0] btn,
    output logic [3:0] led,
    output logic [7:0] seg,

    // Boring stuff
    input logic clk_ext, // 100MHz for now
    input logic reset,

    // SPI (Sub)
    input logic spi_sclk,
    input logic spi_ssn,
    input logic spi_mosi,
    output logic spi_miso,

    // VGA control
    output logic vga_hsync,
    output logic vga_vsync,
    output logic[3:0] vga_red,
    output logic[3:0] vga_green,
    output logic[3:0] vga_blue
);
    localparam video_mode_t VIDEO_MODE = VMODE_640x480p60;

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
    ) clock_manager_inst (
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
    ) display_inst (
        .clk_pixel(clk_display),
        .rstn_pixel(rstn_display),

        .vga_hsync(vga_hsync),
        .vga_vsync(vga_vsync),
        .vga_red(vga_red),
        .vga_green(vga_green),
        .vga_blue(vga_blue)
    );

    /////////
    // SPI //
    /////////

    SpiSub spi_controller (
        // SPI interface
        .ssn(spi_ssn),
        .sclk(spi_sclk),
        .mosi(spi_mosi),
        .miso(spi_miso),

        // System interface
        .sys_clk(clk_ext),
        .sys_rstn(~reset),

        // User data interface
        .tx_data_en(1'b1), // Never sending anything.
        .rx_data_en(1'b1), // Always reading.
        .tx_data(seg), // Sending back received data.
        .rx_data(seg), // Word to receive.
        .tx_ready(), // Ignored.
        .rx_ready(), // Ignored.
        .active() // Ignored.
    );
endmodule



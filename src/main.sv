import video_mode_pkg::*;

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
    logic rstn;

    assign led = btn;
    assign rstn = ~reset;

    // Enter clock into fpga fabric
    logic clk_100m;
    BUFG clock_buf(
        .I(clk_ext),
        .O(clk_100m)
    );


    Display #(
        .VIDEO_MODE(VMODE_640x480p60)
    ) display (
        .clk_100m(clk_100m),
        .rstn(rstn),

        .vga_hsync(vga_hsync),
        .vga_vsync(vga_vsync),
        .vga_red(vga_red),
        .vga_green(vga_green),
        .vga_blue(vga_blue)
    );

endmodule



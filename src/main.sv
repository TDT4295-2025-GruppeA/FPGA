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
    ) clock_manager_inst (
        .clk_ext(clk_ext),
        .reset(reset),
        .clk_system(clk_system),
        .rstn_system(rstn_system),
        .clk_display(clk_display),
        .rstn_display(rstn_display)
    );

    // Communication wires between modules
    localparam int BUFFER_WIDTH = 160;
    localparam int BUFFER_HEIGHT = 120;
    localparam int BUFFER_DATA_WIDTH = 12;
    localparam int BUFFER_ADDR_WIDTH = $clog2(BUFFER_WIDTH * BUFFER_HEIGHT);

    // Signals from DrawingManager to the buffers
    logic dm_write_en;
    logic [BUFFER_ADDR_WIDTH-1:0] dm_write_addr;
    logic [BUFFER_DATA_WIDTH-1:0] dm_write_data;

    // Signals from buffers to the Display
    logic disp_read_en; // Not used in your Display module, but good practice
    logic [BUFFER_ADDR_WIDTH-1:0] disp_read_addr;
    logic [BUFFER_DATA_WIDTH-1:0] disp_read_data;

    // The shared buffer select signal
    logic buffer_select;

    // Frame Buffer A signals
    logic [BUFFER_ADDR_WIDTH-1:0] fb_a_read_addr;
    logic [BUFFER_DATA_WIDTH-1:0] fb_a_read_data;
    logic fb_a_write_en;
    logic [BUFFER_ADDR_WIDTH-1:0] fb_a_write_addr;
    logic [BUFFER_DATA_WIDTH-1:0] fb_a_write_data;

    // Frame Buffer B signals
    logic [BUFFER_ADDR_WIDTH-1:0] fb_b_read_addr;
    logic [BUFFER_DATA_WIDTH-1:0] fb_b_read_data;
    logic fb_b_write_en;
    logic [BUFFER_ADDR_WIDTH-1:0] fb_b_write_addr;
    logic [BUFFER_DATA_WIDTH-1:0] fb_b_write_data;

    ///////////////////////////////////////
    ////////////// DRAWING ////////////////
    ///////////////////////////////////////
    DrawingManager #(
        .BUFFER_WIDTH(BUFFER_WIDTH),
        .BUFFER_HEIGHT(BUFFER_HEIGHT),
        .BUFFER_DATA_WIDTH(BUFFER_DATA_WIDTH),
        .BUFFER_ADDR_WIDTH(BUFFER_ADDR_WIDTH)
    ) drawing_manager_inst (
        .clk(clk_system),
        .rstn(rstn_system),

        .buffer_select(buffer_select),
        .write_en(dm_write_en),
        .write_addr(dm_write_addr),
        .write_data(dm_write_data)
    );

    ///////////////////////////////////////
    ////////////// FRAME BUFFERS //////////
    ///////////////////////////////////////
    FrameBuffer #(
        .BUFFER_SIZE(BUFFER_WIDTH * BUFFER_HEIGHT),
        .DATA_WIDTH(BUFFER_DATA_WIDTH),
        .ADDR_WIDTH(BUFFER_ADDR_WIDTH)
    ) frame_buffer_A (
        .clk(clk_system),
        .rstn(rstn_system),
        .read_addr(fb_a_read_addr),
        .read_data(fb_a_read_data),
        .write_en(fb_a_write_en),
        .write_addr(fb_a_write_addr),
        .write_data(fb_a_write_data)
    );

    FrameBuffer #(
        .BUFFER_SIZE(BUFFER_WIDTH * BUFFER_HEIGHT),
        .DATA_WIDTH(BUFFER_DATA_WIDTH),
        .ADDR_WIDTH(BUFFER_ADDR_WIDTH)
    ) frame_buffer_B (
        .clk(clk_system),
        .rstn(rstn_system),
        .read_addr(fb_b_read_addr),
        .read_data(fb_b_read_data),
        .write_en(fb_b_write_en),
        .write_addr(fb_b_write_addr),
        .write_data(fb_b_write_data)
    );

    ///////////////////////////////////////
    ////////////// DISPLAY ////////////////
    ///////////////////////////////////////
    Display #(
        .VIDEO_MODE(VIDEO_MODE),
        .BUFFER_WIDTH(BUFFER_WIDTH),
        .BUFFER_HEIGHT(BUFFER_HEIGHT),
        .BUFFER_DATA_WIDTH(BUFFER_DATA_WIDTH),
        .BUFFER_ADDR_WIDTH(BUFFER_ADDR_WIDTH)
    ) display_inst (
        .clk_pixel(clk_display),
        .rstn_pixel(rstn_display),
        .vga_hsync(vga_hsync),
        .vga_vsync(vga_vsync),
        .vga_red(vga_red),
        .vga_green(vga_green),
        .vga_blue(vga_blue),
        .read_addr(disp_read_addr),
        .read_data(disp_read_data),
        .buffer_select(buffer_select)
    );

    // The buffer_select signal decides which buffer is being read from and written to.

    // Display reads from the ACTIVE buffer.
    // The Display module drives disp_read_addr.
    assign fb_a_read_addr = !buffer_select ? disp_read_addr : '0;
    assign fb_b_read_addr = buffer_select ? disp_read_addr : '0;
    assign disp_read_data = !buffer_select ? fb_a_read_data : fb_b_read_data;

    // DrawingManager writes to the INACTIVE buffer.
    assign fb_a_write_en = !buffer_select ? dm_write_en : 1'b0;
    assign fb_a_write_addr = !buffer_select ? dm_write_addr : '0;
    assign fb_a_write_data = !buffer_select ? dm_write_data : '0;
    
    assign fb_b_write_en = buffer_select ? dm_write_en : 1'b0;
    assign fb_b_write_addr = buffer_select ? dm_write_addr : '0;
    assign fb_b_write_data = buffer_select ? dm_write_data : '0;
endmodule
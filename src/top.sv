import video_modes_pkg::*;
import buffer_config_pkg::*;
import clock_modes_pkg::*;
import fixed_pkg::*;
import types_pkg::*;

module Top (
    // Fun stuff
    input logic debug_active_frame_buffer,
    input logic debug_depth_buffer,
    // input logic [2:0] btn,
    // output logic [3:0] led,
    // output logic [7:0] seg,

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
    output logic[3:0] vga_blue,

    // Screen
    output logic screen_hsync,
    output logic screen_vsync,
    output logic[4:0] screen_red,
    output logic[5:0] screen_green,
    output logic[4:0] screen_blue,
    output logic screen_enable,
    output logic screen_data_enable,
    output logic screen_clk,

    // GPIO test
    output logic[5:0] gpio
);
    logic done;

    // GPIO output
    assign gpio[0] = done;
    assign gpio[1] = screen_enable;
    assign gpio[2] = screen_data_enable;
    assign gpio[3] = screen_clk;
    assign gpio[4] = screen_hsync;
    assign gpio[5] = screen_vsync;
    // assign gpio[5:4] = screen_green[1:0];

    // Settings for VGA
    // localparam video_mode_t VIDEO_MODE = VMODE_640x480p60;
    // localparam buffer_config_t BUFFER_CONFIG = BUFFER_320x240x12;
    // localparam FLIP_VERTICAL = 0;

    // Settings for MIDAS display
    localparam video_mode_t VIDEO_MODE = VMODE_800x480p60;
    localparam buffer_config_t BUFFER_CONFIG = BUFFER_400x240x12;
    // Flip screen since display is upside down on PCB
    localparam FLIP_VERTICAL = 1;

    ////////////////////////////////////////////////
    ////////////// CLOCK GENERATION ////////////////
    ////////////////////////////////////////////////

    // Logic to ensure that the reset signal from the command
    // module is held for a sufficient number of cycles.
    localparam CMD_RESET_HOLD_CYCLES = 128;

    logic cmd_reset, cmd_reset_d;
    logic [$clog2(CMD_RESET_HOLD_CYCLES)-1:0] cmd_reset_counter;

    always_ff @(posedge clk_ext or posedge reset) begin
        if (reset) begin
            cmd_reset_d <= 1'b0;
            cmd_reset_counter <= '0;
        end else begin
            if (cmd_reset && !cmd_reset_d) begin
                // Start the reset pulse if we get signal from command module.
                cmd_reset_d <= 1'b1;
                cmd_reset_counter <= $clog2(CMD_RESET_HOLD_CYCLES)'(CMD_RESET_HOLD_CYCLES - 1);
            end else if (cmd_reset_counter > 0) begin
                // Decrement the reset counter while it's non zero.
                cmd_reset_counter <= cmd_reset_counter - 1;
            end else if (!cmd_reset && cmd_reset_d) begin
                // When counter has reached zero, deassert the reset signal.
                cmd_reset_d <= 1'b0;
            end
        end
    end

    logic clk_display;
    logic rstn_display;

    logic clk_system;
    logic rstn_system;
    always_comb begin
        if (rstn_system) begin
            done = 1;
        end else begin
            done = 0;
        end
    end
    ClockManager #(
        .CLK_DISPLAY(VIDEO_MODE.clock_config),
        .CLK_SYSTEM(CLK_100_40_MHZ)
    ) clock_manager_inst (
        .clk_ext(clk_ext),
        .reset(reset),
        .clk_system(clk_system),
        .rstn_system(rstn_system),
        .clk_display(clk_display),
        .rstn_display(rstn_display)
    );

    ///////////////////
    // MIDAS Display //
    ///////////////////

    // Constant values for the midas display
    assign screen_hsync = 0;
    assign screen_vsync = 0;
    assign screen_clk = clk_display;
    assign screen_enable = 1;

    /////////
    // SPI //
    /////////

    wire logic spi_cmd_valid;
    wire logic spi_cmd_ready;
    wire byte_t spi_cmd_data;

    wire logic cmd_spi_valid;
    wire logic cmd_spi_ready;
    wire byte_t cmd_spi_data;

    SpiSub #(
        .WORD_SIZE($bits(byte_t)),
        .RX_QUEUE_LENGTH(2),
        .TX_QUEUE_LENGTH(2)
    ) spi_controller (
        // SPI interface
        .ssn(spi_ssn),
        .sclk(spi_sclk),
        .mosi(spi_mosi),
        .miso(spi_miso),

        // System interface
        .sys_clk(clk_system),
        .sys_rstn(rstn_system),

        // User data interface
        .tx_s_valid(cmd_spi_valid),
        .tx_s_ready(cmd_spi_ready),
        .tx_s_data(cmd_spi_data),

        .rx_m_ready(spi_cmd_ready),
        .rx_m_valid(spi_cmd_valid),
        .rx_m_data(spi_cmd_data),
        .active() // Ignored.
    );

    //////////////
    // Pipeline //
    //////////////

    Pipeline #(
        .BUFFER_CONFIG(BUFFER_CONFIG),
        .VIDEO_MODE(VIDEO_MODE),
        .FLIP_VERTICAL(FLIP_VERTICAL)
    ) pipeline_inst (
        .clk_system(clk_system),
        .rstn_system(rstn_system),

        .clk_display(clk_display),
        .rstn_display(rstn_display),

        .cmd_s_valid(spi_cmd_valid),
        .cmd_s_ready(spi_cmd_ready),
        .cmd_s_data(spi_cmd_data),

        .cmd_m_valid(cmd_spi_valid),
        .cmd_m_ready(cmd_spi_ready),
        .cmd_m_data(cmd_spi_data),

        .cmd_reset(cmd_reset),

        .vga_vsync(vga_vsync),
        .vga_hsync(vga_hsync),
        .vga_red(screen_red),
        .vga_green(screen_green),
        .vga_blue(screen_blue),
        .screen_data_enable(screen_data_enable),

        // Debug signals
        .debug_depth_buffer(debug_depth_buffer),
        .debug_active_frame_buffer(debug_active_frame_buffer)
    );

endmodule

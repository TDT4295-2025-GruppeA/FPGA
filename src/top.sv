import video_modes_pkg::*;
import buffer_config_pkg::*;
import clock_modes_pkg::*;
import fixed_pkg::*;
import types_pkg::*;

module Top (
    // Fun stuff
    input logic [3:0] sw,
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
    localparam buffer_config_t BUFFER_CONFIG = BUFFER_160x120x12;

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
                cmd_reset_counter <= CMD_RESET_HOLD_CYCLES - 1;
            end else if (cmd_reset_counter) begin
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

    ClockManager #(
        .CLK_DISPLAY(VIDEO_MODE.clock_config),
        .CLK_SYSTEM(CLK_100_50_MHZ)
    ) clock_manager_inst (
        .clk_ext(clk_ext),
        .reset(reset | cmd_reset_d),
        .clk_system(clk_system),
        .rstn_system(rstn_system),
        .clk_display(clk_display),
        .rstn_display(rstn_display)
    );

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
        .tx_in_valid(cmd_spi_valid),
        .tx_in_ready(cmd_spi_ready),
        .tx_in_data(cmd_spi_data),

        .rx_out_ready(spi_cmd_ready),
        .rx_out_valid(spi_cmd_valid),
        .rx_out_data(spi_cmd_data),
        .active() // Ignored.
    );

    //////////////
    // Pipeline //
    //////////////

    Pipeline #(
        .BUFFER_CONFIG(BUFFER_CONFIG),
        .VIDEO_MODE(VIDEO_MODE)
    ) pipeline_inst (
        .clk_system(clk_system),
        .rstn_system(rstn_system),

        .clk_display(clk_display),
        .rstn_display(rstn_display),

        .cmd_in_valid(spi_cmd_valid),
        .cmd_in_ready(spi_cmd_ready),
        .cmd_in_data(spi_cmd_data),

        .cmd_out_valid(cmd_spi_valid),
        .cmd_out_ready(cmd_spi_ready),
        .cmd_out_data(cmd_spi_data),

        .cmd_reset(cmd_reset),

        .vga_vsync(vga_vsync),
        .vga_hsync(vga_hsync),
        .vga_red(vga_red),
        .vga_green(vga_green),
        .vga_blue(vga_blue),

        // debug
        .sw(sw)
    );

endmodule

import video_modes_pkg::*;
import clock_modes_pkg::*;

module Top (
    // Fun stuff
    input logic [2:0] btn,
    input logic [3:0] sw,
    output logic [3:0] led,

    // Boring stuff
    input logic clk_ext, // 100MHz for now
    input logic reset,

    // SRAM interface
    inout logic [7:0] sram_data,
    output logic [6:0] sram_address,
    output logic sram_write_en_n,

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

    //////////
    // SRAM //
    //////////

    logic [24:0] sram_clk_counter;
    always_ff @(posedge clk_system or negedge rstn_system) begin
        if (!rstn_system) begin
            sram_clk_counter <= 0;
            curr_btn <= 0;
            prev_btn <= 0;
        end else begin
            sram_clk_counter <= sram_clk_counter + 1;
            curr_btn <= btn;
            prev_btn <= curr_btn;
        end
    end
    logic sram_clk;
    assign sram_clk = sram_clk_counter[0];

    logic [7:0] data_buffer, new_data_buffer;
    logic [2:0] curr_btn, prev_btn, delta_btn;
    // Detect button changes, both rising and falling.
    assign delta_btn = curr_btn ^ prev_btn;

    logic write_enable;
    assign write_enable = btn[2];

    always_ff @(posedge sram_clk or negedge rstn_system) begin
        if (!rstn_system) begin
            new_data_buffer <= 0;
        end else begin
            // Capture new data when button is pressed.
            if (delta_btn) begin
                new_data_buffer <= data_buffer + curr_btn[0] - curr_btn[1];
            end
        end
    end

    SramController sram_controller (
        .clk(sram_clk),
        .rstn(rstn_system),

        .address(sw), // Ignored.
        .write_data(new_data_buffer),
        .read_data(data_buffer), // Ignored.
        .read_en(~write_enable), // Ignored.
        .write_en(write_enable), // Ignored.
        .ready(), // Ignored.

        .sram_data(sram_data),
        .sram_address(sram_address),
        .sram_write_en_n(sram_write_en_n)
    );

endmodule



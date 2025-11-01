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

    // Signals from DrawingManager to the buffers
    logic dm_write_en;
    logic [BUFFER_CONFIG.addr_width-1:0] dm_write_addr;
    logic [BUFFER_CONFIG.data_width-1:0] dm_write_data;
    logic dm_frame_done; // Signal from DrawingManager to Top
    logic draw_ack;      // Acknowledgment from Top to DrawingManager

    logic [BUFFER_CONFIG.addr_width-1:0] disp_read_addr;
    logic [BUFFER_CONFIG.data_width-1:0] disp_read_data;

    logic buffer_select;
    logic buffer_select_reg;

    assign buffer_select = buffer_select_reg;

    // Frame Buffer A
    logic [BUFFER_CONFIG.addr_width-1:0] fb_a_read_addr;
    logic [BUFFER_CONFIG.data_width-1:0] fb_a_read_data;
    logic fb_a_write_en;
    logic [BUFFER_CONFIG.addr_width-1:0] fb_a_write_addr;
    logic [BUFFER_CONFIG.data_width-1:0] fb_a_write_data;

    // Frame Buffer B
    logic [BUFFER_CONFIG.addr_width-1:0] fb_b_read_addr;
    logic [BUFFER_CONFIG.data_width-1:0] fb_b_read_data;
    logic fb_b_write_en;
    logic [BUFFER_CONFIG.addr_width-1:0] fb_b_write_addr;
    logic [BUFFER_CONFIG.data_width-1:0] fb_b_write_data;

    ///////////////////////////////////////
    ////////////// DRAWING ////////////////
    ///////////////////////////////////////
    
    // Synchronize buffer_select to system domain to generate draw_start
    logic buffer_select_sync_sys;
    logic buffer_select_sync_sys_d;

    SingleBitSync buffer_select_sync_inst (
        .clk_dst(clk_system),
        .rst_dst_n(rstn_system),
        .data_in_src(buffer_select),
        .data_out_dst(buffer_select_sync_sys)
    );

    // Edge detection for draw_start generation
    always_ff @(posedge clk_system or negedge rstn_system) begin
        if (!rstn_system) begin
            buffer_select_sync_sys_d <= 1'b0;
        end else begin
            buffer_select_sync_sys_d <= buffer_select_sync_sys;
        end
    end

    logic rstn_sys_d;
    logic rst_deassert_pulse;

    always_ff @(posedge clk_system or negedge rstn_system) begin
        if (!rstn_system) begin
            rstn_sys_d <= 1'b0;
        end else begin
            rstn_sys_d <= 1'b1;
        end
    end

    assign rst_deassert_pulse = rstn_system & !rstn_sys_d;

    logic draw_start;
    assign draw_start = rst_deassert_pulse | (buffer_select_sync_sys != buffer_select_sync_sys_d);

    transform_t transform;

    wire logic pipe_dm_valid;
    wire logic pipe_dm_ready;
    wire pixel_data_t pipe_dm_data;
    wire pixel_metadata_t pipe_dm_metadata;

    DrawingManager #(
        .BUFFER_WIDTH(BUFFER_CONFIG.width),
        .BUFFER_HEIGHT(BUFFER_CONFIG.height),
        .BUFFER_DATA_WIDTH(BUFFER_CONFIG.data_width),
        .BUFFER_ADDR_WIDTH(BUFFER_CONFIG.addr_width)
    ) drawing_manager_inst (
        .clk(clk_system),
        .rstn(rstn_system),
        .sw(sw),
        .draw_start(draw_start),
        .draw_ack(draw_ack),
        .write_en(dm_write_en),
        .write_addr(dm_write_addr),
        .write_data(dm_write_data),
        .frame_done(dm_frame_done),

        .pixel_s_valid(pipe_dm_valid),
        .pixel_s_ready(pipe_dm_ready),
        .pixel_s_data(pipe_dm_data),
        .pixel_s_metadata(pipe_dm_metadata)
    );

    ///////////////////////////////////////
    ////////////// CDC LOGIC //////////////
    ///////////////////////////////////////

    logic vga_vsync_d;
    always_ff @(posedge clk_display or negedge rstn_display) begin
        if (!rstn_display) begin
            vga_vsync_d <= 1'b0;
        end else begin
            vga_vsync_d <= vga_vsync;
        end
    end

    logic vga_vsync_blank_edge_start;
    if (VIDEO_MODE.v_sync_pol) begin
        assign vga_vsync_blank_edge_start = vga_vsync && !vga_vsync_d;
    end else begin
        assign vga_vsync_blank_edge_start = !vga_vsync && vga_vsync_d;
    end

    // Synchronize dm_frame_done from system domain to display domain
    logic dm_frame_done_sync;
    
    SingleBitSync dm_frame_done_sync_inst (
        .clk_dst(clk_display),
        .rst_dst_n(rstn_display),
        .data_in_src(dm_frame_done),
        .data_out_dst(dm_frame_done_sync)
    );

    // Request a swap when VSync blanking interval starts and frame is done
    logic swap_req;
    assign swap_req = vga_vsync_blank_edge_start && dm_frame_done_sync;

    // Buffer swap logic in display domain
    always_ff @(posedge clk_display or negedge rstn_display) begin
        if (!rstn_display) begin
            buffer_select_reg <= 1'b0;
        end else begin
            if (swap_req) begin
                buffer_select_reg <= !buffer_select_reg;
            end
        end
    end

    // Use pulse synchronizer to send acknowledgment back to system domain
    PulseSync draw_ack_sync_inst (
        .clk_src(clk_display),
        .rst_src_n(rstn_display),
        .clk_dst(clk_system),
        .rst_dst_n(rstn_system),
        .pulse_in_src(swap_req),
        .pulse_out_dst(draw_ack)
    );

    ///////////////////////////////////////
    ////////////// FRAME BUFFERS //////////
    ///////////////////////////////////////
    FrameBuffer #(
        .BUFFER_CONFIG(BUFFER_CONFIG)
    ) frame_buffer_A (
        .clk_write(clk_system),
        .rstn_write(rstn_system),
        .clk_read(clk_display),
        .read_addr(fb_a_read_addr),
        .read_data(fb_a_read_data),
        .write_en(fb_a_write_en),
        .write_addr(fb_a_write_addr),
        .write_data(fb_a_write_data)
    );

    FrameBuffer #(
        .BUFFER_CONFIG(BUFFER_CONFIG)
    ) frame_buffer_B (
        .clk_write(clk_system),
        .rstn_write(rstn_system),
        .clk_read(clk_display),
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
        .BUFFER_CONFIG(BUFFER_CONFIG)
    ) display_inst (
        .clk_pixel(clk_display),
        .rstn_pixel(rstn_display),
        .vga_hsync(vga_hsync),
        .vga_vsync(vga_vsync),
        .vga_red(vga_red),
        .vga_green(vga_green),
        .vga_blue(vga_blue),
        .read_addr(disp_read_addr),
        .read_data(disp_read_data)
    );

    ////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////
    ///////////                                              ///////////
    ///////////                 Pipeline                     ///////////
    ///////////                                              ///////////
    ////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////
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

    Pipeline #(
        .BUFFER_WIDTH(BUFFER_CONFIG.width),
        .BUFFER_HEIGHT(BUFFER_CONFIG.height)
    ) pipeline_inst (
        .clk(clk_system),
        .rstn(rstn_system),

        .cmd_in_valid(spi_cmd_valid),
        .cmd_in_ready(spi_cmd_ready),
        .cmd_in_data(spi_cmd_data),

        .cmd_out_valid(cmd_spi_valid),
        .cmd_out_ready(cmd_spi_ready),
        .cmd_out_data(cmd_spi_data),

        .pixel_m_valid(pipe_dm_valid),
        .pixel_m_ready(pipe_dm_ready),
        .pixel_m_data(pipe_dm_data),
        .pixel_m_metadata(pipe_dm_metadata)
    );

    ///////////////////////////////////////
    ////////////// BUFFER ROUTING /////////
    ///////////////////////////////////////
    
    // Display reads from the ACTIVE buffer
    // The Display module drives disp_read_addr
    assign fb_a_read_addr = disp_read_addr;
    assign fb_b_read_addr = disp_read_addr;
    assign disp_read_data = sw[3] 
        ? (buffer_select ? fb_a_read_data : fb_b_read_data)
        : (buffer_select ? fb_b_read_data : fb_a_read_data);

    // DrawingManager writes to the INACTIVE buffer
    assign fb_a_write_en = !buffer_select_sync_sys ? dm_write_en : 1'b0;
    assign fb_a_write_addr = dm_write_addr;
    assign fb_a_write_data = dm_write_data;

    assign fb_b_write_en = buffer_select_sync_sys ? dm_write_en : 1'b0;
    assign fb_b_write_addr = dm_write_addr;
    assign fb_b_write_data = dm_write_data;

endmodule

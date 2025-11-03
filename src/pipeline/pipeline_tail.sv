import video_modes_pkg::*;
import buffer_config_pkg::*;
import clock_modes_pkg::*;
import fixed_pkg::*;
import types_pkg::*;

module PipelineTail #(
    parameter buffer_config_t BUFFER_CONFIG = BUFFER_160x120x12,
    parameter video_mode_t VIDEO_MODE = VMODE_640x480p60
)(
    input clk_system,
    input rstn_system,

    input clk_display,
    input rstn_display,

    output logic pixel_data_s_ready,
    input logic pixel_data_s_valid,
    input pixel_data_t pixel_data_s_data,
    input pixel_metadata_t pixel_data_s_metadata,

    // debug
    input logic [3:0] sw

);


    ///////////////////////////////////////
    ////////////// BUFFER ROUTING /////////
    ///////////////////////////////////////

    logic buffer_select;  // lives in display clock domain

    always_ff @(posedge clk_display or negedge rstn_display) begin
        if (!rstn_display)
            buffer_select <= 1'b0;
        else if (swap_req)
            buffer_select <= !buffer_select;
    end


    // Synchronize buffer_select to system domain to generate draw_start
    logic buffer_select_sync_sys;
    logic buffer_select_sync_sys_d;

    // Synchronize buffer_select to system clock domain
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


    ///////////////////////////////////////
    //////////// CLOCK DOMAIN CROSSING ////
    ///////////////////////////////////////

    // Capture edge of vga_vsync in display clock domain
    logic vga_vsync_d;
    always_ff @(posedge clk_display or negedge rstn_display) begin
        if (!rstn_display) begin
            vga_vsync_d <= 1'b0;
        end else begin
            vga_vsync_d <= vga_vsync;
        end
    end

    // Detect vga_vsync blanking edge start
    logic vga_vsync_blank_edge_start;
    if (VIDEO_MODE.v_sync_pol) begin
        assign vga_vsync_blank_edge_start = vga_vsync && !vga_vsync_d;
    end else begin
        assign vga_vsync_blank_edge_start = !vga_vsync && vga_vsync_d;
    end

    // Synchronize dm_frame_done signal from drawing_manager from system domain to display domain
    logic dm_frame_done_sync;
    
    SingleBitSync dm_frame_done_sync_inst (
        .clk_dst(clk_display),
        .rst_dst_n(rstn_display),
        .data_in_src(dm_frame_done),
        .data_out_dst(dm_frame_done_sync)
    );

    // Request a buffer swap when VSync blanking interval starts and frame is done
    logic swap_req;
    assign swap_req = vga_vsync_blank_edge_start && dm_frame_done_sync;

    // Use pulse synchronizer to send acknowledgment back to drawing manager in system clock domain
    PulseSync draw_ack_sync_inst (
        .clk_src(clk_display),
        .rst_src_n(rstn_display),
        .clk_dst(clk_system),
        .rst_dst_n(rstn_system),
        .pulse_in_src(swap_req),
        .pulse_out_dst(draw_ack)
    );


   ///////////////////////////////////////
   //////////// DRAWING MANAGER //////////
   ///////////////////////////////////////
   DrawingManager #(
        .BUFFER_WIDTH(BUFFER_CONFIG.width),
        .BUFFER_HEIGHT(BUFFER_CONFIG.height),
        .BUFFER_DATA_WIDTH(BUFFER_CONFIG.data_width),
        .BUFFER_ADDR_WIDTH(BUFFER_CONFIG.addr_width)
    ) drawing_manager_inst (
        .clk(clk_system),
        .rstn(rstn_system),
        .sw(sw),
        .draw_ack(draw_ack),
        .write_en(dm_write_en),
        .write_addr(dm_write_addr),
        .write_data(dm_write_data),
        .frame_done(dm_frame_done),

        .pixel_s_ready(pixel_data_s_ready),
        .pixel_s_valid(pixel_data_s_valid),
        .pixel_s_data(pixel_data_s_data),
        .pixel_s_metadata(pixel_data_s_metadata)
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
endmodule
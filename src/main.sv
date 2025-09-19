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
    logic dm_frame_done; // Signal from DrawingManager to Top
    logic draw_ack;      // Acknowledgment from Top to DrawingManager

    // Signals from buffers to the Display
    logic [BUFFER_ADDR_WIDTH-1:0] disp_read_addr;
    logic [BUFFER_DATA_WIDTH-1:0] disp_read_data;

    // The shared buffer select signal
    logic buffer_select;
    logic buffer_select_reg;
    logic buffer_select_d;
    logic draw_start;

    assign buffer_select = buffer_select_reg;

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
    
    // Edge detection for buffer_select to generate draw_start signal
    always_ff @(posedge clk_system or negedge rstn_system) begin
        if (!rstn_system) begin
            buffer_select_d <= 1'b0;
        end else begin
            buffer_select_d <= buffer_select;
        end
    end

    // Generate draw start pulse when buffer_select changes
    assign draw_start = (buffer_select != buffer_select_d);

    DrawingManager #(
        .BUFFER_WIDTH(BUFFER_WIDTH),
        .BUFFER_HEIGHT(BUFFER_HEIGHT),
        .BUFFER_DATA_WIDTH(BUFFER_DATA_WIDTH),
        .BUFFER_ADDR_WIDTH(BUFFER_ADDR_WIDTH)
    ) drawing_manager_inst (
        .clk(clk_system),
        .rstn(rstn_system),
        .draw_start(draw_start),
        .draw_ack(draw_ack), // Pass the new signal
        .write_en(dm_write_en),
        .write_addr(dm_write_addr),
        .write_data(dm_write_data),
        .frame_done(dm_frame_done)
    );

    // Synchronize dm_frame_done to clk_display domain and handle buffer swapping
    logic dm_frame_done_s1, dm_frame_done_s2;
    logic draw_ack_s1, draw_ack_s2;
    logic swap_req;

    // Synchronizer for dm_frame_done (clk_system -> clk_display)
    always_ff @(posedge clk_display or negedge rstn_display) begin
        if (!rstn_display) begin
            dm_frame_done_s1 <= 1'b0;
            dm_frame_done_s2 <= 1'b0;
        end else begin
            dm_frame_done_s1 <= dm_frame_done;
            dm_frame_done_s2 <= dm_frame_done_s1;
        end
    end

       // Add logic to detect the positive edge of vga_vsync
    logic vga_vsync_d;
    always_ff @(posedge clk_display or negedge rstn_display) begin
        if (!rstn_display) begin
            vga_vsync_d <= 1'b0;
        end else begin
            vga_vsync_d <= vga_vsync;
        end
    end

    logic vga_vsync_pos_edge;
    assign vga_vsync_pos_edge = vga_vsync && !vga_vsync_d;

    // Request a swap when VSync positive edge and the synchronized frame_done are true
    assign swap_req = vga_vsync_pos_edge && dm_frame_done_s2;

    // Buffer swap logic
    always_ff @(posedge clk_display or negedge rstn_display) begin
        if (!rstn_display) begin
            buffer_select_reg <= 1'b0;
        end else begin
            if (swap_req) begin
                buffer_select_reg <= !buffer_select_reg;
            end
        end
    end

    // Synchronizer for draw_ack (clk_display -> clk_system)
    always_ff @(posedge clk_system or negedge rstn_system) begin
        if (!rstn_system) begin
            draw_ack_s1 <= 1'b0;
            draw_ack_s2 <= 1'b0;
        end else begin
            draw_ack_s1 <= swap_req;
            draw_ack_s2 <= draw_ack_s1;
        end
    end
    
    // Generate a single-cycle pulse on the draw_ack signal
    assign draw_ack = draw_ack_s2 && !buffer_select_d;


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
        .read_data(disp_read_data)
    );

    ///////////////////////////////////////
    ////////////// BUFFER ROUTING /////////
    ///////////////////////////////////////
    
    // Display reads from the ACTIVE buffer
    // The Display module drives disp_read_addr
    assign fb_a_read_addr = !buffer_select ? disp_read_addr : '0;
    assign fb_b_read_addr = buffer_select ? disp_read_addr : '0;
    assign disp_read_data = !buffer_select ? fb_a_read_data : fb_b_read_data;

    // DrawingManager writes to the INACTIVE buffer
    assign fb_a_write_en = !buffer_select ? dm_write_en : 1'b0;
    assign fb_a_write_addr = !buffer_select ? dm_write_addr : '0;
    assign fb_a_write_data = !buffer_select ? dm_write_data : '0;
    
    assign fb_b_write_en = buffer_select ? dm_write_en : 1'b0;
    assign fb_b_write_addr = buffer_select ? dm_write_addr : '0;
    assign fb_b_write_data = buffer_select ? dm_write_data : '0;

endmodule
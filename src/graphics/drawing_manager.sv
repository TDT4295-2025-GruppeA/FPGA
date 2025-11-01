import types_pkg::*;
import fixed_pkg::*;
// import model_data_pkg::*;

module DrawingManager #(
    parameter int BUFFER_WIDTH = 160,
    parameter int BUFFER_HEIGHT = 120,
    parameter int BUFFER_DATA_WIDTH = 12,
    parameter int BUFFER_ADDR_WIDTH = $clog2(BUFFER_WIDTH * BUFFER_HEIGHT),
    parameter real NEAR_PLANE = 0.25,
    parameter real FAR_PLANE  = 1000.0
)(
    input logic clk,
    input logic rstn,
    input logic draw_start,
    input logic draw_ack,

    output logic write_en,
    output logic [BUFFER_ADDR_WIDTH-1:0] write_addr,
    output logic [BUFFER_DATA_WIDTH-1:0] write_data,
    output logic frame_done,

    input logic pixel_s_valid,
    output logic pixel_s_ready,
    input pixel_data_t pixel_s_data,
    input pixel_metadata_t pixel_s_metadata,

    // Temp inputs for debugging
    input logic [3:0] sw // Used for selecting colors
);
    typedef enum {
        IDLE,
        BACKGROUND,
        GRAPHICS,
        FRAMERATE,
        FRAME_DONE
    } pipeline_state_t;

    // Latched switch values for stable drawing during frame.
    logic [3:0] sw_r;

    /////////////////////
    // Control Signals //
    /////////////////////

    logic bg_draw_start, bg_draw_done;
    logic [BUFFER_ADDR_WIDTH-1:0] bg_write_addr;
    logic [BUFFER_DATA_WIDTH-1:0] bg_write_data;
    logic bg_write_en;


    ///////////////////////
    // Background Drawer //
    ///////////////////////

    BackgroundDrawer #(
        .BUFFER_WIDTH(BUFFER_WIDTH),
        .BUFFER_HEIGHT(BUFFER_HEIGHT),
        .BUFFER_DATA_WIDTH(BUFFER_DATA_WIDTH),
        .BUFFER_ADDR_WIDTH(BUFFER_ADDR_WIDTH)
    ) background_drawer (
        .clk(clk),
        .rstn(rstn),
        .draw_start(bg_draw_start),
        .draw_done(bg_draw_done),
        .write_en(bg_write_en),
        .write_addr(bg_write_addr),
        .write_data(bg_write_data)
    );

    //////////////////////
    // Depth (Z) Buffer //
    //////////////////////
    logic depth_write_en;
    logic [BUFFER_ADDR_WIDTH-1:0] depth_write_addr;
    pixel_data_t depth_write_pixel;

    assign pixel_s_ready = 1; // We pretend depthbuffer is always ready
    DepthBuffer #(
    .BUFFER_WIDTH(BUFFER_WIDTH),
    .BUFFER_HEIGHT(BUFFER_HEIGHT),
    .BUFFER_ADDR_WIDTH(BUFFER_ADDR_WIDTH),
    .NEAR_PLANE(NEAR_PLANE),
    .FAR_PLANE(FAR_PLANE)
    ) depth_buffer (
        .clk(clk),
        .rstn(rstn),

        .write_en_in(pixel_s_valid && pixel_s_data.covered),
        .write_pixel_in(pixel_s_data),
        .write_addr_in(BUFFER_ADDR_WIDTH'(pixel_s_data.coordinate.x + pixel_s_data.coordinate.y * BUFFER_WIDTH)),

        .write_en_out(depth_write_en),
        .write_addr_out(depth_write_addr),
        .write_pixel_out(depth_write_pixel),

        .clear_req(bg_write_en),
        .clear_addr(bg_write_addr)
    );

    ///////////////////
    // State Machine //
    ///////////////////

    pipeline_state_t state, next_state;

    logic framerate_indicator, frame_indicator_next;

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            state <= IDLE;
            framerate_indicator <= 1'b0;
            sw_r <= '0;
        end else begin
            state <= next_state;
            framerate_indicator <= frame_indicator_next;

            // Only sample update color between draws.
            if (state == FRAME_DONE) begin
                sw_r <= sw;
            end
        end
    end

    always_comb begin
        next_state = state;
        bg_draw_start = 1'b0;
        frame_done = 1'b0;

        write_en = 1'b0;
        write_addr = '0;
        write_data = '0;


        frame_indicator_next = framerate_indicator;

        case (state)
            IDLE: begin
                if (draw_start) begin
                    next_state = BACKGROUND;
                end
            end
            BACKGROUND: begin
                bg_draw_start = 1'b1;
                write_en = bg_write_en;
                write_addr = bg_write_addr;
                write_data = bg_write_data;
                if (bg_draw_done) begin
                    next_state = GRAPHICS;
                end
            end
            GRAPHICS: begin
                write_en = depth_write_en;
                write_addr = depth_write_addr;
                write_data = sw_r[0]
                    ? {4'h0, 4'(ftoi(mul(itof(15), depth_write_pixel.depth))), 4'h0}
                    : depth_write_pixel.color;

                if (pixel_s_valid && pixel_s_metadata.last) begin
                    next_state = FRAMERATE;
                end
            end
            FRAMERATE: begin
                // Toggle first pixel to be able to see framerate.
                write_en = 1;
                write_addr = BUFFER_ADDR_WIDTH'((BUFFER_WIDTH - 1) + (BUFFER_HEIGHT - 1) * BUFFER_WIDTH);
                write_data = framerate_indicator ? 12'hF00 : 12'h00F;
                frame_indicator_next = ~framerate_indicator;
                next_state = FRAME_DONE;
            end
            FRAME_DONE: begin
                // Assert frame_done for one cycle
                frame_done = 1'b1;
                if (draw_ack) begin // Acknowledge from Top
                    next_state = BACKGROUND;
                end
            end
        endcase
    end
endmodule

module DrawingManager #(
    parameter int BUFFER_WIDTH = 160,
    parameter int BUFFER_HEIGHT = 120,
    parameter int BUFFER_DATA_WIDTH = 12,
    parameter int BUFFER_ADDR_WIDTH = $clog2(BUFFER_WIDTH * BUFFER_HEIGHT)
)(
    input logic clk,
    input logic rstn,
    input logic draw_start,
    input logic draw_ack,
    input logic [3:0] sw,
    
    output logic write_en,
    output logic [BUFFER_ADDR_WIDTH-1:0] write_addr,
    output logic [BUFFER_DATA_WIDTH-1:0] write_data,
    output logic frame_done,
    input  logic buffer_select // Used for debugging atm
);

    typedef enum {
        IDLE,
        DRAWING_BACKGROUND,
        TRANSFORMING,
        RASTERIZING,
        FRAME_DONE
    } pipeline_state_t;

    pipeline_state_t state, next_state;

    logic [3:0] color;

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        if (state == FRAME_DONE)
            color <= sw;
        end
    end

    logic bg_draw_start, bg_draw_done;
    logic [BUFFER_ADDR_WIDTH-1:0] bg_write_addr;
    logic [BUFFER_DATA_WIDTH-1:0] bg_write_data;
    logic bg_write_en;

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
        .write_data(bg_write_data),
        .buffer_select(buffer_select)
    );

    triangle_tf_t triangle_tf_in;
    triangle_t triangle_transformed;

    // Example rotation (identity for now)
    rotmat_t rot_identity = '{
        m00: rtof(1.0), m01: rtof(0.0), m02: rtof(0.0),
        m10: rtof(0.0), m11: rtof(1.0), m12: rtof(0.0),
        m20: rtof(0.0), m21: rtof(0.0), m22: rtof(1.0)
    };

    // Example translation (center on screen)
    position_t pos_center = '{
        x: rtof(0.0),
        y: rtof(0.0),
        z: rtof(0.0)
    };

    // Input triangle (model-space)
    assign triangle_tf_in.triangle = '{
        v0: '{
            position: '{
                x: rtof( 0.01),
                y: rtof( 0.0),
                z: rtof( 0.5)
            },
            color: '0
        },
        v1: '{
            position: '{
                x: rtof( 0.01),
                y: rtof( 1.0),
                z: rtof( 0.0)
            },
            color: '0
        },
        v2: '{
            position: '{
                x: rtof( 1.01),
                y: rtof( 0.0),
                z: rtof( 1.0)
            },
            color: '0
        }
    };

    assign triangle_tf_in.transform.rotmat = rot_identity;
    assign triangle_tf_in.transform.position = pos_center;

    logic triangle_tf_valid, triangle_tf_ready;
    logic triangle_transformed_valid, triangle_transformed_ready;

    Transform transform (
        .clk(clk),
        .rstn(rstn),

        .triangle_tf_s_data(triangle_tf_in),
        .triangle_tf_s_metadata(1'b0),
        .triangle_tf_s_valid(triangle_tf_valid),
        .triangle_tf_s_ready(triangle_tf_ready),

        .triangle_m_data(triangle_transformed),
        .triangle_m_valid(triangle_transformed_valid),
        .triangle_m_metadata(),
        .triangle_m_ready(triangle_transformed_ready)
    );

    logic pixel_valid;
    pixel_data_t pixel;

    Rasterizer #(
        .VIEWPORT_WIDTH(BUFFER_WIDTH),
        .VIEWPORT_HEIGHT(BUFFER_HEIGHT)
    ) rasterizer (
        .clk(clk),
        .rstn(rstn),
        
        .triangle_s_ready(triangle_transformed_ready),
        .triangle_s_valid(triangle_transformed_valid),
        .triangle_s_data(triangle_transformed),

        .pixel_data_m_ready(1'b1), // We are always ready.
        .pixel_data_m_valid(pixel_valid),
        .pixel_data_m_data(pixel)
    );

    always_comb begin
        next_state = state;
        bg_draw_start = 1'b0;
        triangle_tf_valid = 1'b0;
        frame_done = 1'b0;

        write_en = 1'b0;
        write_addr = '0;
        write_data = '0;

        case (state)
            IDLE: begin
                if (draw_start) begin
                    next_state = DRAWING_BACKGROUND;
                end
            end
            DRAWING_BACKGROUND: begin
                bg_draw_start = 1'b1;
                write_en = bg_write_en;
                write_addr = bg_write_addr;
                write_data = bg_write_data;
                if (bg_draw_done) begin
                    next_state = TRANSFORMING;
                end
            end

            TRANSFORMING: begin
                // Start the transform
                triangle_tf_valid = 1'b1;
                if (triangle_transformed_valid) begin
                    next_state = RASTERIZING;
                end
            end


            RASTERIZING: begin
                if (pixel_valid) begin
                    write_en = 1'b1;
                    write_addr = pixel.coordinate.x + pixel.coordinate.y * BUFFER_WIDTH;
                    write_data = pixel.valid ? {4'h0, 4'(ftoi(mul(itof(color), pixel.depth))), 4'h0} : {4'h8, 4'h8, 4'h8};
                end

                // Check if rasterizer is done.
                if (triangle_transformed_ready) begin
                    // If so, go to next state.
                    next_state = FRAME_DONE;
                end
            end
            FRAME_DONE: begin
                // Assert frame_done for one cycle
                frame_done = 1'b1;
                if (draw_ack) begin // Acknowledge from Top
                    next_state = DRAWING_BACKGROUND;
                end
            end
        endcase
    end

endmodule
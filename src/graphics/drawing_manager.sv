import types_pkg::*;
import fixed_pkg::*;
// import model_data_pkg::*;

module DrawingManager #(
    parameter int BUFFER_WIDTH = 160,
    parameter int BUFFER_HEIGHT = 120,
    parameter int BUFFER_DATA_WIDTH = 12,
    parameter int BUFFER_ADDR_WIDTH = $clog2(BUFFER_WIDTH * BUFFER_HEIGHT),
    parameter string FILE_PATH = "static/models/teapot",
    parameter int TRIANGLE_COUNT = 160
)(
    input logic clk,
    input logic rstn,
    input logic draw_start,
    input logic draw_ack,
    
    output logic write_en,
    output logic [BUFFER_ADDR_WIDTH-1:0] write_addr,
    output logic [BUFFER_DATA_WIDTH-1:0] write_data,
    output logic frame_done,

    // Temp inputs for debugging
    input logic [3:0] sw, // Used for selecting colors
    input logic buffer_select,
    input transform_t transform
);
    typedef enum {
        IDLE,
        BACKGROUND,
        GRAPHICS,
        FRAMERATE,
        FRAME_DONE
    } pipeline_state_t;

    // Add one to triangle count to be able store when 
    // all triangles have been fed to the rasterizer.
    typedef logic [$clog2(TRIANGLE_COUNT + 1)-1:0] triangle_index_t;

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
        .write_data(bg_write_data),
        .buffer_select(buffer_select)
    );

    triangle_t triangles[TRIANGLE_COUNT];
    assign triangles[0] = '{
        v0: '{
            position: '{
                x: rtof( 0.2),
                y: rtof( 0.2),
                z: rtof( 0.0)
            },
            color: 'hF00
        },
        v1: '{
            position: '{
                x: rtof( 0.7),
                y: rtof( 0.1),
                z: rtof( 0.0)
            },
            color: 'h0F0
        },
        v2: '{
            position: '{
                x: rtof( 0.5),
                y: rtof( 0.5),
                z: rtof( 1.0)
            },
            color: 'hFFF
        }
    };
    assign triangles[1] = '{
        v0: '{
            position: '{
                x: rtof( 0.5),
                y: rtof( 0.5),
                z: rtof( 1.0)
            },
            color: 'hFFF
        },
        v1: '{
            position: '{
                x: rtof( 0.6),
                y: rtof( 0.9),
                z: rtof( 0.0)
            },
            color: 'h00F
        },
        v2: '{
            position: '{
                x: rtof( 0.2),
                y: rtof( 0.2),
                z: rtof( 0.0)
            },
            color: 'hF00
        }
    };
    assign triangles[2] = '{
        v0: '{
            position: '{
                x: rtof( 0.5),
                y: rtof( 0.5),
                z: rtof( 1.0)
            },
            color: 'hFFF
        },
        v1: '{
            position: '{
                x: rtof( 0.7),
                y: rtof( 0.1),
                z: rtof( 0.0)
            },
            color: 'h0F0
        },
        v2: '{
            position: '{
                x: rtof( 0.6),
                y: rtof( 0.9),
                z: rtof( 0.0)
            },
            color: 'h00F
        }
    };

    // Which triangle to send next.
    triangle_index_t triangle_index;
    triangle_t triangle;

    ModelRom #(
        .FILE_PATH(FILE_PATH),
        .TRIANGLE_COUNT(TRIANGLE_COUNT)
    ) mode_rom (
        .clk(clk),
        .address(triangle_index),
        .triangle(triangle)
    );

    ///////////////
    // Transform //
    ///////////////

    transform_t transform_d;

    // Input data to the transform module.
    triangle_tf_t triangle_tf_data;
    assign triangle_tf_data.transform = transform_d;
    assign triangle_tf_data.triangle = triangle;

    logic triangle_tf_metadata;
    assign triangle_tf_metadata = triangle_index == triangle_index_t'(TRIANGLE_COUNT - 1);

    // Input control signals.
    logic triangle_tf_ready, triangle_tf_valid;
    // Output control signals .
    logic triangle_transformed_ready, triangle_transformed_valid;
    // Output data.
    logic triangle_transformed_metadata;
    triangle_t triangle_transformed;

    Transform transformer (
        .clk(clk),
        .rstn(rstn),

        .triangle_tf_s_ready(triangle_tf_ready),
        .triangle_tf_s_valid(triangle_tf_valid),
        .triangle_tf_s_data(triangle_tf_data),
        .triangle_tf_s_metadata(triangle_tf_metadata),

        .triangle_m_ready(triangle_transformed_ready),
        .triangle_m_valid(triangle_transformed_valid),
        .triangle_m_data(triangle_transformed),
        .triangle_m_metadata(triangle_transformed_metadata)
    );

    triangle_t projected_triangle;
    logic projected_valid, projected_ready;
    logic projected_metadata;

    Projection #(
        .FOCAL_LENGTH(1.0),
        .ASPECT_RATIO(real'(BUFFER_WIDTH) / real'(BUFFER_HEIGHT))
    ) projection (
        .clk(clk),
        .rstn(rstn),

        .triangle_s_data(triangle_transformed),
        .triangle_s_metadata(triangle_transformed_metadata),
        .triangle_s_valid(triangle_transformed_valid),
        .triangle_s_ready(triangle_transformed_ready),

        .projected_triangle_m_data(projected_triangle),
        .projected_triangle_m_valid(projected_valid),
        .projected_triangle_m_metadata(projected_metadata),
        .projected_triangle_m_ready(projected_ready)
    );

    ///////////////////
    // Rasterization //
    ///////////////////

    logic pixel_valid;
    pixel_data_t pixel;
    pixel_metadata_t pixel_metadata;

    Rasterizer #(
        .VIEWPORT_WIDTH(BUFFER_WIDTH),
        .VIEWPORT_HEIGHT(BUFFER_HEIGHT)
    ) rasterizer (
        .clk(clk),
        .rstn(rstn),

        .triangle_s_ready(projected_ready),
        .triangle_s_valid(projected_valid),
        .triangle_s_data(projected_triangle),
        .triangle_s_metadata('{ last: projected_metadata }),

        .pixel_data_m_ready(1'b1), // We are always ready.
        .pixel_data_m_valid(pixel_valid),
        .pixel_data_m_data(pixel),
        .pixel_data_m_metadata(pixel_metadata)
    );

    ///////////////////
    // State Machine //
    ///////////////////

    triangle_index_t triangle_index_next;
    pipeline_state_t state, next_state;
    
    logic framerate_indicator, frame_indicator_next;
    logic triangle_changed;

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            state <= IDLE;
            triangle_index <= '0;
            framerate_indicator <= 1'b0;
            triangle_changed <= 1'b0;
        end else begin
            state <= next_state;
            triangle_index <= triangle_index_next;
            framerate_indicator <= frame_indicator_next;
            triangle_changed <= triangle_index_next != triangle_index;

            // Only sample update color between draws.
            if (state == FRAME_DONE) begin
                sw_r <= sw;
                transform_d <= transform;
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
        
        triangle_tf_valid = 1'b0;
        triangle_index_next = triangle_index;

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
                // So long as we have triangles to send, do so.
                // Take one cycle delay of loading into account.
                if (!triangle_changed && (triangle_index < triangle_index_t'(TRIANGLE_COUNT)))
                    triangle_tf_valid = 1'b1;

                // Advance triangle index when triangle is accepted.
                if (triangle_tf_valid && triangle_tf_ready)
                    triangle_index_next = triangle_index + 1;

                if (pixel_valid) begin
                    // Write the received pixel to the buffer.
                    write_en = pixel.covered;
                    write_addr = BUFFER_ADDR_WIDTH'(pixel.coordinate.x + pixel.coordinate.y * 10'(BUFFER_WIDTH));

                    if (sw_r[0]) begin
                        // If switch zero is set display the depth map.
                        write_data = {4'h0, 4'(ftoi(mul(itof(15), pixel.depth))), 4'h0};
                    end else begin
                        // Otherwise, write the actual pixel color.
                        write_data = pixel.color[15:4];
                    end

                    if (pixel_metadata.last) begin
                        // Move to the next state if the rasterizer is done.
                        triangle_index_next = 0;
                        next_state = FRAMERATE;
                    end
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

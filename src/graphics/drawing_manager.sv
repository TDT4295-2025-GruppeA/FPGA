import types_pkg::*;
import fixed_pkg::*;

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
        RASTERIZING,
        FRAME_DONE
    } pipeline_state_t;

    localparam int TRIANGLE_COUNT = 3;
    typedef logic [$clog2(TRIANGLE_COUNT)-1:0] triangle_index_t;

    logic [3:0] color;

    pipeline_state_t state, next_state;
    triangle_index_t triangle_index, triangle_index_next;
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            state <= IDLE;
            triangle_index <= '0;
        end else begin
            state <= next_state;
            triangle_index <= triangle_index_next;
            if (state == FRAME_DONE) 
                color <= sw;
        end
    end

    logic bg_draw_start, bg_draw_done;
    logic [BUFFER_ADDR_WIDTH-1:0] bg_write_addr;
    logic [BUFFER_DATA_WIDTH-1:0] bg_write_data;
    logic bg_write_en;

    logic sprite_draw_start, sprite_draw_done;
    logic [BUFFER_ADDR_WIDTH-1:0] sprite_write_addr;
    logic [BUFFER_DATA_WIDTH-1:0] sprite_write_data;
    logic sprite_write_en;
    
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
    assign triangles[1] = '{
        a: '{
            position: '{
                x: rtof( 0.2),
                y: rtof( 0.2),
                z: rtof( 0.0)
            },
            color: '0
        },
        b: '{
            position: '{
                x: rtof( 0.7),
                y: rtof( 0.1),
                z: rtof( 0.0)
            },
            color: '0
        },
        c: '{
            position: '{
                x: rtof( 0.5),
                y: rtof( 0.5),
                z: rtof( 1.0)
            },
            color: '0
        }
    };
    assign triangles[2] = '{
        a: '{
            position: '{
                x: rtof( 0.5),
                y: rtof( 0.5),
                z: rtof( 1.0)
            },
            color: '0
        },
        b: '{
            position: '{
                x: rtof( 0.6),
                y: rtof( 0.9),
                z: rtof( 0.0)
            },
            color: '0
        },
        c: '{
            position: '{
                x: rtof( 0.2),
                y: rtof( 0.2),
                z: rtof( 0.0)
            },
            color: '0
        }
    };
    assign triangles[0] = '{
        a: '{
            position: '{
                x: rtof( 0.5),
                y: rtof( 0.5),
                z: rtof( 1.0)
            },
            color: '0
        },
        b: '{
            position: '{
                x: rtof( 0.7),
                y: rtof( 0.1),
                z: rtof( 0.0)
            },
            color: '0
        },
        c: '{
            position: '{
                x: rtof( 0.6),
                y: rtof( 0.9),
                z: rtof( 0.0)
            },
            color: '0
        }
    };

    triangle_t triangle;
    logic triangle_ready, triangle_valid, pixel_valid;
    pixel_data_t pixel;
    pixel_metadata_t pixel_metadata;

    assign triangle = triangles[triangle_index];

    Rasterizer #(
        .VIEWPORT_WIDTH(BUFFER_WIDTH),
        .VIEWPORT_HEIGHT(BUFFER_HEIGHT)
    ) rasterizer (
        .clk(clk),
        .rstn(rstn),
        
        .triangle_s_ready(triangle_ready),
        .triangle_s_valid(triangle_valid),
        .triangle_s_data(triangle),

        .pixel_data_m_ready(1'b1), // We are alway ready.
        .pixel_data_m_valid(pixel_valid),
        .pixel_data_m_metadata(pixel_metadata),
        .pixel_data_m_data(pixel)
    );


    always_comb begin
        next_state = state;
        bg_draw_start = 1'b0;
        sprite_draw_start = 1'b0;
        frame_done = 1'b0;
        
        write_en = 1'b0;
        write_addr = '0;
        write_data = '0;
        
        triangle_valid = 1'b0;
        triangle_index_next = triangle_index;

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
                    next_state = RASTERIZING;
                    triangle_valid = 1'b1;
                end
            end
            RASTERIZING: begin
                if (pixel_valid) begin
                    write_en = pixel.covered;
                    write_addr = BUFFER_ADDR_WIDTH'(pixel.coordinate.x + pixel.coordinate.y * 10'(BUFFER_WIDTH));
                    write_data = {4'h0, 4'(ftoi(mul(itof(32'(color)), pixel.depth))), 4'h0};

                    // Check if rasterizer is done.
                    if (pixel_metadata.last) begin
                        if (triangle_index == triangle_index_t'(TRIANGLE_COUNT - 1)) begin
                            // If this was the last triangle, go to next state.
                            triangle_index_next = 0;
                            next_state = FRAME_DONE;
                        end else if (triangle_ready) begin
                            // Otherwise, start rasterizing next triangle.
                            triangle_index_next = triangle_index + 1;
                            triangle_valid = 1'b1;
                        end
                    end
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
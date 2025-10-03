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
    
    output logic write_en,
    output logic [BUFFER_ADDR_WIDTH-1:0] write_addr,
    output logic [BUFFER_DATA_WIDTH-1:0] write_data,
    output logic frame_done,
    input  logic buffer_select // Used for debugging atm
);

    typedef enum {
        IDLE,
        DRAWING_BACKGROUND,
        DRAWING_SPRITES,
        FRAME_DONE
    } pipeline_state_t;

    pipeline_state_t state, next_state;
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            state <= IDLE;
        end else begin
            state <= next_state;
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
    
    always_comb begin
        next_state = state;
        bg_draw_start = 1'b0;
        sprite_draw_start = 1'b0;
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
module BackgroundDrawer #(
    parameter int BUFFER_WIDTH = 160,
    parameter int BUFFER_HEIGHT = 120,
    parameter int BUFFER_DATA_WIDTH = 12,
    parameter int BUFFER_ADDR_WIDTH = $clog2(BUFFER_WIDTH * BUFFER_HEIGHT)
)(
    input logic clk,
    input logic rstn,
    input logic draw_start,
    input logic quadrant_select,

    output logic draw_done,
    output logic write_en,
    output logic [BUFFER_ADDR_WIDTH-1:0] write_addr,
    output logic [BUFFER_DATA_WIDTH-1:0] write_data
);

    localparam int BUFFER_SIZE = BUFFER_WIDTH * BUFFER_HEIGHT;
    localparam int QUADRANT_SIZE = (BUFFER_WIDTH * BUFFER_HEIGHT) / 4;
    localparam int QUADRANT_ADDR_START_4TH = (BUFFER_WIDTH * BUFFER_HEIGHT) / 4 * 3;

    localparam int QUADRANT_1_COLOR = 12'hF00; // Red
    localparam int QUADRANT_4_COLOR = 12'h00F; // Blue

    typedef enum {
        IDLE,
        DRAWING
    } state_t;

    state_t state, next_state;
    logic [BUFFER_ADDR_WIDTH-1:0] counter;
    logic counter_en;
    logic counter_rst;
    
    logic [BUFFER_DATA_WIDTH-1:0] current_color;
    logic [BUFFER_ADDR_WIDTH-1:0] start_addr;
    logic [BUFFER_ADDR_WIDTH-1:0] end_addr;

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            counter <= 0;
        end else if (counter_rst) begin
            counter <= 0;
        end else if (counter_en) begin
            counter <= counter + 1;
        end
    end

    always_comb begin
        next_state = state;
        counter_en = 1'b0;
        counter_rst = 1'b0;
        draw_done = 1'b0;
        write_en = 1'b0;
        write_addr = '0;
        write_data = '0;
        
        current_color = (quadrant_select == 1'b0) ? QUADRANT_1_COLOR : QUADRANT_4_COLOR;
        start_addr = (quadrant_select == 1'b0) ? 0 : QUADRANT_ADDR_START_4TH;
        end_addr = (quadrant_select == 1'b0) ? QUADRANT_SIZE - 1 : BUFFER_SIZE - 1;

        case (state)
            IDLE: begin
                if (draw_start) begin
                    next_state = DRAWING;
                    counter_rst = 1'b1; // Reset counter on transition
                end
            end
            DRAWING: begin
                counter_en = 1'b1;
                write_en = 1'b1;
                write_addr = start_addr + counter;
                write_data = current_color;

                if (counter == (QUADRANT_SIZE - 1)) begin
                    next_state = IDLE;
                    draw_done = 1'b1;
                end
            end
        endcase
    end
endmodule
module BackgroundDrawer #(
    parameter int BUFFER_WIDTH = 160,
    parameter int BUFFER_HEIGHT = 120,
    parameter int BUFFER_DATA_WIDTH = 12,
    parameter int BUFFER_ADDR_WIDTH = $clog2(BUFFER_WIDTH * BUFFER_HEIGHT)
)(
    input logic clk,
    input logic rstn,
    input logic draw_start,

    output logic draw_done,
    output logic write_en,
    output logic [BUFFER_ADDR_WIDTH-1:0] write_addr,
    output logic [BUFFER_DATA_WIDTH-1:0] write_data
);

    localparam int BUFFER_SIZE = BUFFER_WIDTH * BUFFER_HEIGHT;
    localparam int BACKGROUND_COLOR = 12'h00F;

    typedef enum {
        IDLE,
        DRAWING
    } state_t;

    state_t state, next_state;
    logic [BUFFER_ADDR_WIDTH-1:0] counter;
    logic counter_en;
    logic counter_rst;

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
        write_data = BACKGROUND_COLOR;

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
                write_addr = counter;
                if (counter == (BUFFER_SIZE >> 1)) begin
                    next_state = IDLE;
                    draw_done = 1'b1;
                end
            end
        endcase
    end
endmodule
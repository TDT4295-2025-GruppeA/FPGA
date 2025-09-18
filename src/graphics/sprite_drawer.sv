module SpriteDrawer #(
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

    // State machine to handle a single-cycle 'drawing' operation
    typedef enum {
        IDLE,
        DONE_DRAWING
    } state_t;

    state_t state, next_state;

    // Output signals default to low
    assign write_en = 1'b0;
    assign write_addr = '0;
    assign write_data = '0;
    assign draw_done = (state == DONE_DRAWING);

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    always_comb begin
        next_state = state;
        case (state)
            IDLE: begin
                if (draw_start) begin
                    next_state = DONE_DRAWING;
                end
            end
            DONE_DRAWING: begin
                // Once done, go back to idle on the next clock
                next_state = IDLE;
            end
        endcase
    end

endmodule
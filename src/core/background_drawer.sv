import types_pkg::*;

module BackgroundDrawer #(
    parameter int BUFFER_WIDTH = 160,
    parameter int BUFFER_HEIGHT = 120,
    parameter int BUFFER_ADDR_WIDTH = $clog2(BUFFER_WIDTH * BUFFER_HEIGHT)
)(
    input  logic clk,
    input  logic rstn,
    input  logic draw_start,
    
    output logic draw_done,
    output logic write_en,
    output logic [BUFFER_ADDR_WIDTH-1:0] write_addr,
    output color_t write_data
);
    localparam color_t COLOR_ABOVE = color_t'('h055F); // light blue
    localparam color_t COLOR_BELOW = color_t'('h055F); // light grey
    localparam int CY = BUFFER_HEIGHT / 2;

    typedef enum logic [0:0] {
        IDLE,
        DRAWING
    } state_t;

    state_t state, next_state;

    // X and Y counters
    localparam int XW = $clog2(BUFFER_WIDTH);
    localparam int YW = $clog2(BUFFER_HEIGHT);

    logic [XW-1:0] x;
    logic [YW-1:0] y;

    logic counter_en;
    logic counter_rst;

    // FSM state register
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn)
            state <= IDLE;
        else
            state <= next_state;
    end

    // X/Y pixel counters
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn || counter_rst) begin
            x <= '0;
            y <= '0;
        end else if (counter_en) begin
            if (x == XW'(BUFFER_WIDTH - 1)) begin
                x <= '0;
                if (y == YW'(BUFFER_HEIGHT - 1))
                    y <= '0;
                else
                    y <= y + 1;
            end else begin
                x <= x + 1;
            end
        end
    end

    // Next-state and output logic
    always_comb begin
        next_state = state;
        counter_en = 1'b0;
        counter_rst = 1'b0;
        draw_done  = 1'b0;
        write_en   = 1'b0;
        write_addr = '0;
        write_data = '0;

        case (state)
            IDLE: begin
                if (draw_start) begin
                    next_state = DRAWING;
                    counter_rst = 1'b1;
                end
            end

            DRAWING: begin
                counter_en = 1'b1;
                write_en   = 1'b1;
                write_addr = BUFFER_ADDR_WIDTH'((y * BUFFER_WIDTH) + x);

                // Flat background split horizontally
                if (y < YW'(CY))
                    write_data = COLOR_ABOVE;
                else
                    write_data = COLOR_BELOW;

                // Done condition: last pixel written
                if ((x == XW'(BUFFER_WIDTH - 1)) && (y == YW'(BUFFER_HEIGHT - 1))) begin
                    next_state = IDLE;
                    draw_done  = 1'b1;
                end
            end
        endcase
    end

endmodule

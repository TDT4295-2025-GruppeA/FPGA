module DrawingManager #(
    parameter int BUFFER_WIDTH = 160,
    parameter int BUFFER_HEIGHT = 120,
    parameter int BUFFER_DATA_WIDTH = 12,
    parameter int BUFFER_ADDR_WIDTH = $clog2(BUFFER_WIDTH * BUFFER_HEIGHT)
)(
    input logic clk,
    input logic rstn,
    input logic buffer_select,

    output logic write_en,
    output logic [BUFFER_ADDR_WIDTH-1:0] write_addr,
    output logic [BUFFER_DATA_WIDTH-1:0] write_data
);

    // State definitions
    typedef enum {
        IDLE,
        DRAWING_BACKGROUND,
        DRAWING_SPRITES,
        FRAME_DONE
    } pipeline_state_t;

    pipeline_state_t state, next_state;

    // A signal to detect the edge of the buffer select toggle
    logic buffer_select_d;
    logic start_draw_cycle;

    // Two-stage synchronizer for the buffer_select signal
    // to handle crossing clock domains safely
    logic buffer_select_s1;
    logic buffer_select_s2;
    
    // Original buffer_select_d now synchronizes the signal
    // It's a register that gets its value from the output of the synchronizer
    logic start_draw_cycle;

    // Synchronizer logic
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            buffer_select_s1 <= 1'b0;
            buffer_select_s2 <= 1'b0;
            buffer_select_d <= 1'b0;
            state <= IDLE;
        end else begin
            // First stage of synchronizer
            buffer_select_s1 <= buffer_select;
            // Second stage of synchronizer
            buffer_select_s2 <= buffer_select_s1;
            // The signal from the previous cycle is now a stable, synchronized signal
            buffer_select_d <= buffer_select_s2;
            state <= next_state;
        end
    end

    // Use the synchronized signal for the edge detection
    assign start_draw_cycle = (buffer_select_s2 != buffer_select_d);

    // Signals from sub-modules
    logic bg_draw_start, bg_draw_done;
    logic [BUFFER_ADDR_WIDTH-1:0] bg_write_addr;
    logic [BUFFER_DATA_WIDTH-1:0] bg_write_data;
    logic bg_write_en;

    logic sprite_draw_start, sprite_draw_done;
    logic [BUFFER_ADDR_WIDTH-1:0] sprite_write_addr;
    logic [BUFFER_DATA_WIDTH-1:0] sprite_write_data;
    logic sprite_write_en;
    
    // Instantiate drawing modules
    BackgroundDrawer #(
        .BUFFER_WIDTH(BUFFER_WIDTH),
        .BUFFER_HEIGHT(BUFFER_HEIGHT),
        .BUFFER_DATA_WIDTH(BUFFER_DATA_WIDTH),
        .BUFFER_ADDR_WIDTH(BUFFER_ADDR_WIDTH)
    ) background_drawer (
        .clk(clk), .rstn(rstn),
        .draw_start(bg_draw_start),
        .draw_done(bg_draw_done),
        .write_en(bg_write_en),
        .write_addr(bg_write_addr),
        .write_data(bg_write_data)
    );

    SpriteDrawer #(
    ) sprite_drawer (
        .clk(clk), .rstn(rstn),
        .draw_start(sprite_draw_start),
        .draw_done(sprite_draw_done),
        .write_en(sprite_write_en),
        .write_addr(sprite_write_addr),
        .write_data(sprite_write_data)
    );
    
    // Combinational logic for state transitions and outputs
    always_comb begin
    next_state = state;
    bg_draw_start = 1'b0;
    sprite_draw_start = 1'b0;
    
    // Default to no write
    write_en = 1'b0;
    write_addr = '0;
    write_data = '0;
    
        case (state)
            IDLE: begin
                // Transition to the first drawing state when a new frame begins
                if (start_draw_cycle) begin
                    next_state = DRAWING_BACKGROUND;
                end
            end
            DRAWING_BACKGROUND: begin
                bg_draw_start = 1'b1;
                write_en = bg_write_en;
                write_addr = bg_write_addr;
                write_data = bg_write_data;
                if (bg_draw_done) begin
                    next_state = DRAWING_SPRITES;
                end
            end
            DRAWING_SPRITES: begin
                sprite_draw_start = 1'b1;
                write_en = sprite_write_en;
                write_addr = sprite_write_addr;
                write_data = sprite_write_data;
                if (sprite_draw_done) begin
                    next_state = FRAME_DONE;
                end
            end
            FRAME_DONE: begin
                // Transition back to IDLE immediately on the next clock cycle
                next_state = IDLE;
            end
        endcase
    end

endmodule
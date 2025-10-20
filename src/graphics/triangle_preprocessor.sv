
function automatic fixed triangle_area(position_t p0, position_t p1, position_t p2);
    return add(
        add(
            mul(
                sub(p0.y, p1.y),
                p2.x
            ),
            mul(
                sub(p1.x, p0.x),
                p2.y
            )
        ),
        sub(
            mul(p0.x, p1.y),
            mul(p0.y, p1.x)
        )
    );
endfunction

module TrianglePreprocessor (
    input logic clk,
    input logic rstn,

    output logic triangle_s_ready,
    input logic triangle_s_valid,
    input triangle_t triangle_s_data,
    input triangle_metadata_t triangle_s_metadata,

    input logic attributed_triangle_m_ready,
    output logic attributed_triangle_m_valid,
    output attributed_triangle_t attributed_triangle_m_data,
    output triangle_metadata_t attributed_triangle_m_metadata
);
    typedef enum logic[1:0] {
        IDLE,                 // Waiting for a new triangle.
        CALCULATE_AREA,       // Calculating the area.
        CALCULATE_INVERSE,    // Calculating the inverse of the area.
        DONE                  // Waiting for input to be read.
    } preprocessor_state_t;

    preprocessor_state_t state, state_next;

    assign triangle_s_ready = (state == IDLE);
    assign attributed_triangle_m_valid = (state == DONE);

    triangle_t triangle;
    triangle_metadata_t triangle_metadata;
    fixed area, area_inv;
    logic area_inv_valid;

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            state <= IDLE;
            triangle <= '0;
            triangle_metadata <= '0;
            attributed_triangle_m_data <= '0;
            attributed_triangle_m_metadata <= '0;
        end else begin
            state <= state_next;

            if (triangle_s_valid && triangle_s_ready) begin
                triangle <= triangle_s_data;
                triangle_metadata <= triangle_s_metadata;
            end

            if (area_inv_valid) begin
                attributed_triangle_m_data.triangle <= triangle;
                attributed_triangle_m_data.area_inv <= area_inv;
                attributed_triangle_m_metadata <= triangle_metadata;
            end
        end
    end

    always_comb begin
        state_next = state;

        case (state)
            IDLE: begin
                if (triangle_s_valid && triangle_s_ready) begin
                    state_next = CALCULATE_AREA;
                end
            end
            CALCULATE_AREA: begin
                // This just takes one cycle.
                state_next = CALCULATE_INVERSE;
            end
            CALCULATE_INVERSE: begin
                if (area_inv_valid) begin
                    state_next = DONE;
                end
            end
            DONE: begin
                if (attributed_triangle_m_valid && attributed_triangle_m_ready) begin
                    state_next = IDLE;
                end
            end
        endcase
    end

    assign area = triangle_area(
        triangle.a.position,
        triangle.b.position,
        triangle.c.position
    );

    FixedDivider divider (
        .clk(clk),
        
        .dividend_s_ready(), // Ignored.
        .dividend_s_valid(1'b1), // Always valid.
        .dividend_s_data(itof(1)), // We want 1 / area.

        .divisor_s_ready(), // Ignored
        .divisor_s_valid(state == CALCULATE_AREA),
        .divisor_s_data(area),

        .result_m_ready(1'b1), // Always ready.
        .result_m_valid(area_inv_valid),
        .result_m_data(area_inv)
    );

endmodule
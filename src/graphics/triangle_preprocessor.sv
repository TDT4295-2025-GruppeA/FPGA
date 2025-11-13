import fixed_pkg::*;
import types_pkg::*;

function automatic fixed triangle_area(position_t p0, position_t p1, position_t p2);
    return add(
        add(
            mul(
                sub(p1.y, p2.y),
                p0.x,
                PIXEL_FRACTIONAL_BITS
            ),
            mul(
                sub(p2.y, p0.y),
                p1.x,
                PIXEL_FRACTIONAL_BITS
            )
        ),
        mul(
            sub(p0.y, p1.y),
            p2.x,
            PIXEL_FRACTIONAL_BITS
        )
    );
endfunction

function automatic fixed max(fixed a, fixed b, fixed c);
    fixed m;
    m = (a > b) ? a : b;
    m = (m > c) ? m : c;
    return m;
endfunction

function automatic fixed min(fixed a, fixed b, fixed c);
    fixed m;
    m = (a < b) ? a : b;
    m = (m < c) ? m : c;
    return m;
endfunction

module TrianglePreprocessor (
    input logic clk,
    input logic rstn,

    output logic triangle_s_ready,
    input logic triangle_s_valid,
    input triangle_t triangle_s_data,
    input triangle_meta_t triangle_s_metadata,

    input logic attributed_triangle_m_ready,
    output logic attributed_triangle_m_valid,
    output attributed_triangle_t attributed_triangle_m_data,
    output triangle_meta_t attributed_triangle_m_metadata
);
    typedef enum {
        IDLE,                 // Waiting for a new triangle.
        CALCULATE_AREA,       // Calculating the area by summing the three terms.
        LATCH_AREA,           // Latching the area result.
        CALCULATE_INVERSE,    // Calculating the inverse of the area.
        DONE                  // Waiting for input to be read.
    } preprocessor_state_t;

    preprocessor_state_t state, state_next;

    assign triangle_s_ready = (state == IDLE);
    assign attributed_triangle_m_valid = (state == DONE);

    triangle_t triangle;
    triangle_meta_t triangle_metadata;
    fixed area_c, area_r, area_inv;
    logic area_inv_valid;
    logic small_area;
    bounding_box_t bounding_box;

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            state <= IDLE;
            triangle <= '0;
            triangle_metadata <= '0;
            attributed_triangle_m_data <= '0;
            attributed_triangle_m_metadata <= '0;
            area_r <= '0;
        end else begin
            state <= state_next;
            area_r <= area_c;

            if (triangle_s_valid && triangle_s_ready) begin
                triangle <= triangle_s_data;
                triangle_metadata <= triangle_s_metadata;
            end

            if (area_inv_valid) begin
                attributed_triangle_m_data.triangle <= triangle;
                attributed_triangle_m_data.area_inv <= area_inv;
                attributed_triangle_m_data.small_area <= small_area;
                attributed_triangle_m_data.bounding_box <= bounding_box;
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
                // This takes just one cycle.
                state_next = LATCH_AREA;
            end
            LATCH_AREA: begin
                // Latch the area result.
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

    assign area_c = triangle_area(
        triangle.v0.position,
        triangle.v1.position,
        triangle.v2.position
    );

    // TODO: Remove magic number.
    // This could probably be calculated based 
    // on the area of a single pixel
    assign small_area = (area_r <= 4);

    assign bounding_box.top = min(
        triangle.v0.position.y,
        triangle.v1.position.y,
        triangle.v2.position.y
    );
    assign bounding_box.bottom = max(
        triangle.v0.position.y,
        triangle.v1.position.y,
        triangle.v2.position.y
    );
    assign bounding_box.left = min(
        triangle.v0.position.x,
        triangle.v1.position.x,
        triangle.v2.position.x
    );
    assign bounding_box.right = max(
        triangle.v0.position.x,
        triangle.v1.position.x,
        triangle.v2.position.x
    );

    FixedReciprocalDivider #(
        .INPUT_FRACTIONAL_BITS(PIXEL_FRACTIONAL_BITS),
        .OUTPUT_FRACTIONAL_BITS(PRECISION_FRACTIONAL_BITS)
    ) divider (
        .clk(clk),

        .divisor_s_ready(), // Ignored
        .divisor_s_valid(state == LATCH_AREA),
        .divisor_s_data(area_r),

        .result_m_ready(1'b1), // Always ready.
        .result_m_valid(area_inv_valid),
        .result_m_data(area_inv)
    );

endmodule
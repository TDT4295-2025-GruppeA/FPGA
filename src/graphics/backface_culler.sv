import fixed_pkg::*;
import types_pkg::*;

function automatic position_t sub3(position_t a, position_t b);
    position_t c;
    c.x = sub(a.x, b.x);
    c.y = sub(a.y, b.y);
    c.z = sub(a.z, b.z);
    return c;
endfunction

function automatic position_t cross3(position_t a, position_t b);
    position_t c;
    c.x = sub(mul(a.y, b.z), mul(a.z, b.y));
    c.y = sub(mul(a.z, b.x), mul(a.x, b.z));
    c.z = sub(mul(a.x, b.y), mul(a.y, b.x));
    return c;
endfunction

function automatic fixed dot3(position_t a, position_t b);
    return add(
        add(
            mul(a.x, b.x),
            mul(a.y, b.y)
        ),
        mul(a.z, b.z)
    );
endfunction

typedef struct packed {
    triangle_t triangle;
    logic keep;
} backface_culler_input_t;

// Removes back facing triangles by simply discarding them.
// Optionally, the triangle can be passed through, but nulled,
// in case some metadata needs to be preserved.
module BackfaceCuller (
    input logic clk,
    input logic rstn,

    input logic triangle_s_valid,
    output logic triangle_s_ready,
    input backface_culler_input_t triangle_s_data,
    input triangle_meta_t triangle_s_metadata,

    output logic triangle_m_valid,
    input logic triangle_m_ready,
    output triangle_t triangle_m_data,
    output triangle_meta_t triangle_m_metadata
);
    typedef enum logic [2:0] {
        IDLE,
        PROCESS_1,
        PROCESS_2,
        PROCESS_3,
        PROCESS_4,
        DONE
    } state_t;

    state_t state, state_next;

    triangle_t triangle;
    logic keep;
    triangle_meta_t triangle_metadata;

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            state <= IDLE;
            triangle <= '0;
            keep <= 0;
            triangle_metadata <= '0;
        end else begin
            state <= state_next;

            if (triangle_s_valid && triangle_s_ready) begin
                triangle <= triangle_s_data.triangle;
                keep <= triangle_s_data.keep;
                triangle_metadata <= triangle_s_metadata;
            end
        end
    end

    position_t u, v, n;
    fixed dot_product;
    
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            u <= '0;
            v <= '0;
            n <= '0;
        end else if (state == PROCESS_1 || state == PROCESS_2 || state == PROCESS_3) begin
            u <= sub3(triangle.v1.position, triangle.v0.position);
            v <= sub3(triangle.v2.position, triangle.v0.position);
            n <= cross3(u, v);
            dot_product <= dot3(n, triangle.v0.position);
        end
    end

    logic is_backface;
    assign is_backface = (dot_product < rtof(0.0));

    always_comb begin
        state_next = state;

        case (state)
            IDLE: begin
                if (triangle_s_valid && triangle_s_ready) begin
                    state_next = PROCESS_1;
                end
            end

            PROCESS_1: begin
                state_next = PROCESS_2;
            end

            PROCESS_2: begin
                state_next = PROCESS_3;
            end

            PROCESS_3: begin
                state_next = PROCESS_4;
            end

            PROCESS_4: begin
                // Go to done if the triangle should be kept or it is not a backface.
                if (keep || !is_backface) begin
                    state_next = DONE;
                end else begin
                    state_next = IDLE;
                end
            end

            DONE: begin
                if (triangle_m_valid && triangle_m_ready) begin
                    state_next = IDLE;
                end
            end

            default: begin
                state_next = IDLE;
            end
        endcase
    end

    assign triangle_s_ready = (state == IDLE);
    assign triangle_m_valid = (state == DONE);
    // If the triangle is a backface output an empty triangle.
    // This is done so that the metadata can still be passed through if needed.
    assign triangle_m_data = (is_backface) ? '0 : triangle;
    assign triangle_m_metadata = triangle_metadata;
endmodule

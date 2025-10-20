import types_pkg::*;
import fixed_pkg::*;

module Transform #(
)(
    input  logic        clk,
    input  logic        rstn,

    input  triangle_tf_t triangle_tf_s_data,
    input  logic         triangle_tf_s_metadata,
    input  logic         triangle_tf_s_valid,
    output logic         triangle_tf_s_ready,

    output triangle_t    triangle_m_data,
    output logic         triangle_m_valid,
    output logic         triangle_m_metadata,
    input  logic         triangle_m_ready
);

    // FSM states
    typedef enum logic [1:0] {
        S_IDLE,   // waiting for input
        S_MUL,    // perform multiplication
        S_ADD,    // perform addition
        S_OUT     // wait for consumer to accept output
    } state_t;

    state_t state, next_state;

    // Input regs
    triangle_t triangle_reg;
    rotmat_t   rotmat_reg;
    position_t pos_reg;
    logic      m_reg;

    typedef struct packed {
        fixed m00x, m01y, m02z;
        fixed m10x, m11y, m12z;
        fixed m20x, m21y, m22z;
    } vertex_partial_t; // Helper struct to hold multiplication results

    vertex_partial_t v0_mul, v1_mul, v2_mul;
    triangle_t triangle_out;
    logic      m_stage1, m_stage2;

    // State transition logic
    always_comb begin
        next_state = state;

        case (state)
            S_IDLE: begin
                if (triangle_tf_s_valid)
                    next_state = S_MUL;
            end

            S_MUL: begin
                next_state = S_ADD;
            end

            S_ADD: begin
                next_state = S_OUT;
            end

            S_OUT: begin
                if (triangle_m_valid && triangle_m_ready)
                    next_state = S_IDLE;
            end
        endcase
    end

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn)
            state <= S_IDLE;
        else
            state <= next_state;
    end

    // Input handshake
    assign triangle_tf_s_ready = (state == S_IDLE);

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            triangle_reg <= '0;
            rotmat_reg   <= '0;
            pos_reg      <= '0;
            m_reg        <= '0;
        end
        else if (triangle_tf_s_ready && triangle_tf_s_valid) begin
            triangle_reg <= triangle_tf_s_data.triangle;
            rotmat_reg   <= triangle_tf_s_data.transform.rotmat;
            pos_reg      <= triangle_tf_s_data.transform.position;
            m_reg        <= triangle_tf_s_metadata;
        end
    end

    // Multiplication part of the transform
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            v0_mul <= '0;
            v1_mul <= '0;
            v2_mul <= '0;
            m_stage1 <= '0;
        end
        else if (state == S_MUL) begin
            // Vertex 0
            v0_mul.m00x <= mul(rotmat_reg.m00, triangle_reg.v0.position.x);
            v0_mul.m01y <= mul(rotmat_reg.m01, triangle_reg.v0.position.y);
            v0_mul.m02z <= mul(rotmat_reg.m02, triangle_reg.v0.position.z);
            v0_mul.m10x <= mul(rotmat_reg.m10, triangle_reg.v0.position.x);
            v0_mul.m11y <= mul(rotmat_reg.m11, triangle_reg.v0.position.y);
            v0_mul.m12z <= mul(rotmat_reg.m12, triangle_reg.v0.position.z);
            v0_mul.m20x <= mul(rotmat_reg.m20, triangle_reg.v0.position.x);
            v0_mul.m21y <= mul(rotmat_reg.m21, triangle_reg.v0.position.y);
            v0_mul.m22z <= mul(rotmat_reg.m22, triangle_reg.v0.position.z);

            // Vertex 1
            v1_mul.m00x <= mul(rotmat_reg.m00, triangle_reg.v1.position.x);
            v1_mul.m01y <= mul(rotmat_reg.m01, triangle_reg.v1.position.y);
            v1_mul.m02z <= mul(rotmat_reg.m02, triangle_reg.v1.position.z);
            v1_mul.m10x <= mul(rotmat_reg.m10, triangle_reg.v1.position.x);
            v1_mul.m11y <= mul(rotmat_reg.m11, triangle_reg.v1.position.y);
            v1_mul.m12z <= mul(rotmat_reg.m12, triangle_reg.v1.position.z);
            v1_mul.m20x <= mul(rotmat_reg.m20, triangle_reg.v1.position.x);
            v1_mul.m21y <= mul(rotmat_reg.m21, triangle_reg.v1.position.y);
            v1_mul.m22z <= mul(rotmat_reg.m22, triangle_reg.v1.position.z);

            // Vertex 2
            v2_mul.m00x <= mul(rotmat_reg.m00, triangle_reg.v2.position.x);
            v2_mul.m01y <= mul(rotmat_reg.m01, triangle_reg.v2.position.y);
            v2_mul.m02z <= mul(rotmat_reg.m02, triangle_reg.v2.position.z);
            v2_mul.m10x <= mul(rotmat_reg.m10, triangle_reg.v2.position.x);
            v2_mul.m11y <= mul(rotmat_reg.m11, triangle_reg.v2.position.y);
            v2_mul.m12z <= mul(rotmat_reg.m12, triangle_reg.v2.position.z);
            v2_mul.m20x <= mul(rotmat_reg.m20, triangle_reg.v2.position.x);
            v2_mul.m21y <= mul(rotmat_reg.m21, triangle_reg.v2.position.y);
            v2_mul.m22z <= mul(rotmat_reg.m22, triangle_reg.v2.position.z);

            m_stage1 <= m_reg;
        end
    end

    // Addition part of the transform
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            triangle_out <= '0;
            m_stage2 <= '0;
        end
        else if (state == S_ADD) begin
            triangle_out.v0.position.x <= add(add(v0_mul.m00x, v0_mul.m01y), add(v0_mul.m02z, pos_reg.x));
            triangle_out.v0.position.y <= add(add(v0_mul.m10x, v0_mul.m11y), add(v0_mul.m12z, pos_reg.y));
            triangle_out.v0.position.z <= add(add(v0_mul.m20x, v0_mul.m21y), add(v0_mul.m22z, pos_reg.z));

            triangle_out.v1.position.x <= add(add(v1_mul.m00x, v1_mul.m01y), add(v1_mul.m02z, pos_reg.x));
            triangle_out.v1.position.y <= add(add(v1_mul.m10x, v1_mul.m11y), add(v1_mul.m12z, pos_reg.y));
            triangle_out.v1.position.z <= add(add(v1_mul.m20x, v1_mul.m21y), add(v1_mul.m22z, pos_reg.z));

            triangle_out.v2.position.x <= add(add(v2_mul.m00x, v2_mul.m01y), add(v2_mul.m02z, pos_reg.x));
            triangle_out.v2.position.y <= add(add(v2_mul.m10x, v2_mul.m11y), add(v2_mul.m12z, pos_reg.y));
            triangle_out.v2.position.z <= add(add(v2_mul.m20x, v2_mul.m21y), add(v2_mul.m22z, pos_reg.z));

            triangle_out.v0.color <= triangle_reg.v0.color;
            triangle_out.v1.color <= triangle_reg.v1.color;
            triangle_out.v2.color <= triangle_reg.v2.color;

            m_stage2 <= m_stage1;
        end
    end

    // Output handshake
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn)
            triangle_m_valid <= 1'b0;
        else if (state == S_ADD)
            triangle_m_valid <= 1'b1;
        else if (state == S_OUT && triangle_m_valid && triangle_m_ready)
            triangle_m_valid <= 1'b0;
    end

    assign triangle_m_data     = triangle_out;
    assign triangle_m_metadata = m_stage2;

endmodule

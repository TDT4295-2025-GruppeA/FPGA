import types_pkg::*;
import fixed_pkg::*;

module Transform #(
    parameter TRIANGLE_META_WIDTH = 1
)(
    input  logic        clk,
    input  logic        rstn,

    input  triangle_tf              triangle_tf_s_data,
    input  logic [TRIANGLE_META_WIDTH-1:0]  triangle_tf_s_metadata,
    input  logic                      triangle_tf_s_valid,
    output logic                      triangle_tf_s_ready,

    output triangle_t                 triangle_m_data,
    output logic                      triangle_m_valid,
    output logic [TRIANGLE_META_WIDTH-1:0]  triangle_m_metadata,
    input  logic                      triangle_m_ready
);

    // FSM states
    typedef enum logic [3:0] {
        S_IDLE,       // waiting for input
        S_MUL_V0,     // multiply vertex 0
        S_ADD_V0,     // add vertex 0
        S_MUL_V1,     // multiply vertex 1
        S_ADD_V1,     // add vertex 1
        S_MUL_V2,     // multiply vertex 2
        S_ADD_V2,     // add vertex 2
        S_OUT          // output
    } state_t;

    state_t state, next_state;

    // Input regs
    triangle_t triangle_reg;
    rotmat_t   rotmat_reg;
    position_t pos_reg;
    logic [TRIANGLE_META_WIDTH-1:0] m_reg;

    // Shared multiplier outputs (combinational)
    fixed m00x, m01y, m02z;
    fixed m10x, m11y, m12z;
    fixed m20x, m21y, m22z;

    // Registered multiplier results (pipeline stage)
    typedef struct packed {
        fixed m00x, m01y, m02z;
        fixed m10x, m11y, m12z;
        fixed m20x, m21y, m22z;
    } mul_result_t;
    mul_result_t mul_r;

    // Output vertex registers
    vertex_t v0_out, v1_out, v2_out;

    // Active vertex selector
    vertex_t active_vertex;

    // State transition logic
    always_comb begin
        next_state = state;
        case (state)
            S_IDLE: begin
                if (triangle_tf_s_valid)
                    next_state = S_MUL_V0;
            end

            S_MUL_V0: begin
                next_state = S_ADD_V0;
            end
            S_ADD_V0: begin
                next_state = S_MUL_V1;
            end

            S_MUL_V1: begin
                next_state = S_ADD_V1;
            end

            S_ADD_V1: begin
                next_state = S_MUL_V2;
            end

            S_MUL_V2: begin
                next_state = S_ADD_V2;
            end

            S_ADD_V2: begin
                next_state = S_OUT;
            end

            S_OUT: begin
                if (triangle_m_valid && triangle_m_ready)
                             next_state = S_IDLE;
            end

            default: begin
                 next_state = S_IDLE;
            end
        endcase
    end

    // Sequential state
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

    // Select the active vertex (used in MUL states)
    always_comb begin
        case (state)
            S_MUL_V0, S_ADD_V0: active_vertex = triangle_reg.v0;
            S_MUL_V1, S_ADD_V1: active_vertex = triangle_reg.v1;
            S_MUL_V2, S_ADD_V2: active_vertex = triangle_reg.v2;
            default:             active_vertex = '0;
        endcase
    end

    // Time-multiplexed vertex multiplication
    assign m00x = mul(rotmat_reg.m00, active_vertex.position.x);
    assign m01y = mul(rotmat_reg.m01, active_vertex.position.y);
    assign m02z = mul(rotmat_reg.m02, active_vertex.position.z);
    assign m10x = mul(rotmat_reg.m10, active_vertex.position.x);
    assign m11y = mul(rotmat_reg.m11, active_vertex.position.y);
    assign m12z = mul(rotmat_reg.m12, active_vertex.position.z);
    assign m20x = mul(rotmat_reg.m20, active_vertex.position.x);
    assign m21y = mul(rotmat_reg.m21, active_vertex.position.y);
    assign m22z = mul(rotmat_reg.m22, active_vertex.position.z);

    // Register the multiplier results (pipeline stage)
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn)
            mul_r <= '0;
        else if (state inside {S_MUL_V0, S_MUL_V1, S_MUL_V2}) begin
            mul_r.m00x <= m00x;  mul_r.m01y <= m01y;  mul_r.m02z <= m02z;
            mul_r.m10x <= m10x;  mul_r.m11y <= m11y;  mul_r.m12z <= m12z;
            mul_r.m20x <= m20x;  mul_r.m21y <= m21y;  mul_r.m22z <= m22z;
        end
    end

    // Add stage (uses registered multiplier results)
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            v0_out <= '0;
            v1_out <= '0;
            v2_out <= '0;
        end else begin
            case (state)
                S_ADD_V0: begin
                    v0_out.position.x <= add(add(mul_r.m00x, mul_r.m01y), add(mul_r.m02z, pos_reg.x));
                    v0_out.position.y <= add(add(mul_r.m10x, mul_r.m11y), add(mul_r.m12z, pos_reg.y));
                    v0_out.position.z <= add(add(mul_r.m20x, mul_r.m21y), add(mul_r.m22z, pos_reg.z));
                    v0_out.color      <= triangle_reg.v0.color;
                end
                S_ADD_V1: begin
                    v1_out.position.x <= add(add(mul_r.m00x, mul_r.m01y), add(mul_r.m02z, pos_reg.x));
                    v1_out.position.y <= add(add(mul_r.m10x, mul_r.m11y), add(mul_r.m12z, pos_reg.y));
                    v1_out.position.z <= add(add(mul_r.m20x, mul_r.m21y), add(mul_r.m22z, pos_reg.z));
                    v1_out.color      <= triangle_reg.v1.color;
                end
                S_ADD_V2: begin
                    v2_out.position.x <= add(add(mul_r.m00x, mul_r.m01y), add(mul_r.m02z, pos_reg.x));
                    v2_out.position.y <= add(add(mul_r.m10x, mul_r.m11y), add(mul_r.m12z, pos_reg.y));
                    v2_out.position.z <= add(add(mul_r.m20x, mul_r.m21y), add(mul_r.m22z, pos_reg.z));
                    v2_out.color      <= triangle_reg.v2.color;
                end
                default: begin
                    // Do nothing
                end
            endcase
        end
    end

    // Output handshake
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn)
            triangle_m_valid <= 1'b0;
        else if (state == S_ADD_V2)
            triangle_m_valid <= 1'b1;
        else if (state == S_OUT && triangle_m_valid && triangle_m_ready)
            triangle_m_valid <= 1'b0;
    end

    assign triangle_m_data.v0 = v0_out;
    assign triangle_m_data.v1 = v1_out;
    assign triangle_m_data.v2 = v2_out;
    assign triangle_m_metadata = m_reg;

endmodule

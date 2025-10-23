import types_pkg::*;
import fixed_pkg::*;

// Projects a single coordinate using the formula:
//   p' = f * p * (1/z) + c
function automatic fixed project(fixed f, fixed point, fixed rec_z, fixed c);
    return add(mul(f, mul(point, rec_z)), c);
endfunction

// Projection module: converts 3D triangle vertices to 2D
// screen coordinates using camera intrinsics.
// Each vertex is projected as:
//   x' = fx * x / z + cx
//   y' = fy * y / z + cy
//   z' = 1/z
module Projection #(
    parameter camera_intrinsics_t intrinsics = '{
        fx: itof(69.0),
        fy: itof(69.0),
        cx: itof(80.0),
        cy: itof(60.0)
    }
)(
    input  logic        clk,
    input  logic        rstn,

    input  triangle_t   triangle_s_data,
    input  logic        triangle_s_metadata,
    input  logic        triangle_s_valid,
    output logic        triangle_s_ready,

    output triangle_t   projected_triangle_m_data,
    output logic        projected_triangle_m_valid,
    output logic        projected_triangle_m_metadata,
    input  logic        projected_triangle_m_ready
);

    // FSM states
    typedef enum logic [2:0] {
        S_IDLE,
        S_DIV_V0,
        S_DIV_V1,
        S_DIV_V2,
        S_PROJ,
        S_OUT
    } state_t;

    state_t state, next_state;

    // Input regs
    triangle_t t_in;
    triangle_t t_proj;
    logic      m_in, m_stage1, m_stage2;

    fixed rec_z0, rec_z1, rec_z2;
    fixed current_z;
    logic divisor_valid, divisor_ready, z_reciprocal_valid;
    fixed z_reciprocal;

    
    FixedReciprocalDivider divider (
        .clk(clk),

        .divisor_s_ready(divisor_ready),
        .divisor_s_valid(divisor_valid),
        .divisor_s_data(current_z),      // current z value

        .result_m_ready(1'b1),
        .result_m_valid(z_reciprocal_valid),
        .result_m_data(z_reciprocal)
    );

    // State transition logic
    always_comb begin
        next_state = state;

        case (state)
            S_IDLE: begin
                if (triangle_s_valid)
                    next_state = S_DIV_V0;
            end

            S_DIV_V0: begin
                if (z_reciprocal_valid)
                    next_state = S_DIV_V1;
            end

            S_DIV_V1: begin
                if (z_reciprocal_valid)
                    next_state = S_DIV_V2;
            end

            S_DIV_V2: begin
                if (z_reciprocal_valid)
                    next_state = S_PROJ;
            end

            S_PROJ: begin
                next_state = S_OUT;
            end

            S_OUT: begin
                if (projected_triangle_m_valid && projected_triangle_m_ready)
                    next_state = S_IDLE;
            end

            default: begin
                // Do nothing
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
    assign triangle_s_ready = (state == S_IDLE);

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            t_in <= '0;
            m_in <= '0;
        end else if (triangle_s_ready && triangle_s_valid) begin
            t_in <= triangle_s_data;
            m_in <= triangle_s_metadata;
        end
    end

    // Divider input control
    always_comb begin
        divisor_valid = 1'b0;
        current_z     = '0;

        case (state)
            S_DIV_V0: begin
                divisor_valid = divisor_ready;
                current_z     = t_in.v0.position.z;
            end

            S_DIV_V1: begin
                divisor_valid = divisor_ready;
                current_z     = t_in.v1.position.z;
            end

            S_DIV_V2: begin
                divisor_valid = divisor_ready;
                current_z     = t_in.v2.position.z;
            end

            default: begin
                // Do nothing
            end
        endcase
    end

    // Capture reciprocal results
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            rec_z0 <= '0;
            rec_z1 <= '0;
            rec_z2 <= '0;
            m_stage1 <= 1'b0;
        end else begin
            case (state)
                S_DIV_V0: if (z_reciprocal_valid) rec_z0 <= z_reciprocal;
                S_DIV_V1: if (z_reciprocal_valid) rec_z1 <= z_reciprocal;
                S_DIV_V2: if (z_reciprocal_valid) rec_z2 <= z_reciprocal;
                default: begin
                    // Do nothing
                end
            endcase
            if (state == S_DIV_V2 && z_reciprocal_valid)
                m_stage1 <= m_in;
        end
    end

    // Projection math
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            t_proj <= '0;
            m_stage2 <= 1'b0;
        end else if (state == S_PROJ) begin
            // Vertex 0
            t_proj.v0.position.x <= project(intrinsics.fx,
                                        t_in.v0.position.x, rec_z0, intrinsics.cx);
            t_proj.v0.position.y <= project(intrinsics.fy,
                                        t_in.v0.position.y, rec_z0, intrinsics.cy);
            t_proj.v0.position.z <= rec_z0;
            t_proj.v0.color      <= t_in.v0.color;

            // Vertex 1
            t_proj.v1.position.x <= project(intrinsics.fx,
                                        t_in.v1.position.x, rec_z1, intrinsics.cx);
            t_proj.v1.position.y <= project(intrinsics.fy,
                                        t_in.v1.position.y, rec_z1, intrinsics.cy);
            t_proj.v1.position.z <= rec_z1;
            t_proj.v1.color      <= t_in.v1.color;

            // Vertex 2
            t_proj.v2.position.x <= project(intrinsics.fx,
                                        t_in.v2.position.x, rec_z2, intrinsics.cx);
            t_proj.v2.position.y <= project(intrinsics.fy,
                                        t_in.v2.position.y, rec_z2, intrinsics.cy);
            t_proj.v2.position.z <= rec_z2;
            t_proj.v2.color      <= t_in.v2.color;

            m_stage2 <= m_stage1;
        end
    end

    // Output handshake
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn)
            projected_triangle_m_valid <= 1'b0;
        else if (state == S_PROJ)
            projected_triangle_m_valid <= 1'b1;
        else if (state == S_OUT && projected_triangle_m_valid &&
                 projected_triangle_m_ready)
            projected_triangle_m_valid <= 1'b0;
    end

    assign projected_triangle_m_data     = t_proj;
    assign projected_triangle_m_metadata = m_stage2;

endmodule

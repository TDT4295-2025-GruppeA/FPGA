import types_pkg::*;
import fixed_pkg::*;

// Projects a single coordinate using the formula:
//   p' = f * p * (1/z) + c
function automatic fixed project(fixed f, fixed point, fixed rec_z);
    return mul(f, mul(point, rec_z));
endfunction

// Projection module: converts 3D triangle vertices to NDC space.
// Each vertex is projected as:
//   x' = f * x / z
//   y' = f * y / z
//   z' = 1/z
module Projection #(
    parameter real FOCAL_LENGTH = 0.1,
    parameter real ASPECT_RATIO = 1.0
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
    localparam fixed FOCAL_LENGTH_X = rtof(FOCAL_LENGTH / ASPECT_RATIO);
    localparam fixed FOCAL_LENGTH_Y = rtof(FOCAL_LENGTH);

    // FSM states
    typedef enum {
        S_IDLE,
        S_LOAD_DIV_V0,
        S_WAIT_DIV_V0,
        S_LOAD_DIV_V1,
        S_WAIT_DIV_V1,
        S_LOAD_DIV_V2,
        S_WAIT_DIV_V2,
        S_PROJ,
        S_OUT
    } state_t;

    state_t state, next_state;

    // Input regs
    triangle_t triangle_in;
    triangle_t triangle_projected;
    logic      metadata_in, m_stage1, m_stage2;

    fixed rec_z0, rec_z1, rec_z2;
    fixed current_z;
    logic divisor_valid, divisor_ready, z_reciprocal_valid, z_reciprocal_ready;
    fixed z_reciprocal;

    
    FixedReciprocalDivider divider (
        .clk(clk),

        .divisor_s_ready(divisor_ready),
        .divisor_s_valid(divisor_valid),
        .divisor_s_data(current_z),

        .result_m_ready(z_reciprocal_ready),
        .result_m_valid(z_reciprocal_valid),
        .result_m_data(z_reciprocal)
    );

    // State transition logic
    always_comb begin
        next_state = state;

        case (state)
            S_IDLE: begin
                if (triangle_s_valid)
                    next_state = S_LOAD_DIV_V0;
            end

            S_LOAD_DIV_V0: begin
                if (divisor_ready)
                    next_state = S_WAIT_DIV_V0;
            end

            S_WAIT_DIV_V0: begin
                if (z_reciprocal_valid)
                    next_state = S_LOAD_DIV_V1;
            end

            S_LOAD_DIV_V1: begin
                if (divisor_ready)
                    next_state = S_WAIT_DIV_V1;
            end

            S_WAIT_DIV_V1: begin
                if (z_reciprocal_valid)
                    next_state = S_LOAD_DIV_V2;
            end

            S_LOAD_DIV_V2: begin
                if (divisor_ready)
                    next_state = S_WAIT_DIV_V2;
            end

            S_WAIT_DIV_V2: begin
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
            triangle_in <= '0;
            metadata_in <= '0;
        end else if (triangle_s_ready && triangle_s_valid) begin
            triangle_in <= triangle_s_data;
            metadata_in <= triangle_s_metadata;
        end
    end

    // Divider input control
    always_comb begin
        divisor_valid = 1'b0;
        z_reciprocal_ready = 1'b0;
        current_z     = '0;

        case (state)
            S_LOAD_DIV_V0: begin
                divisor_valid = 1'b1;
                current_z = triangle_in.v0.position.z;
            end

            S_WAIT_DIV_V0: begin
                z_reciprocal_ready = 1'b1;
            end

            S_LOAD_DIV_V1: begin
                divisor_valid = 1'b1;
                current_z     = triangle_in.v1.position.z;
            end

            S_WAIT_DIV_V1: begin
                z_reciprocal_ready = 1'b1;
            end

            S_LOAD_DIV_V2: begin
                divisor_valid = 1'b1;
                current_z     = triangle_in.v2.position.z;
            end

            S_WAIT_DIV_V2: begin
                z_reciprocal_ready = 1'b1;
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
        end else begin
            case (state)
                S_WAIT_DIV_V0: if (z_reciprocal_valid) rec_z0 <= z_reciprocal;
                S_WAIT_DIV_V1: if (z_reciprocal_valid) rec_z1 <= z_reciprocal;
                S_WAIT_DIV_V2: if (z_reciprocal_valid) rec_z2 <= z_reciprocal;
                default: begin
                    // Do nothing
                end
            endcase
        end
    end

    // Projection math
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            triangle_projected <= '0;
        end else if (state == S_PROJ) begin
            // Vertex 0
            triangle_projected.v0.position.x <= project(FOCAL_LENGTH_X, triangle_in.v0.position.x, rec_z0);
            triangle_projected.v0.position.y <= project(FOCAL_LENGTH_Y, triangle_in.v0.position.y, rec_z0);
            triangle_projected.v0.position.z <= rec_z0;
            triangle_projected.v0.color      <= triangle_in.v0.color;

            // Vertex 1
            triangle_projected.v1.position.x <= project(FOCAL_LENGTH_X, triangle_in.v1.position.x, rec_z1);
            triangle_projected.v1.position.y <= project(FOCAL_LENGTH_Y, triangle_in.v1.position.y, rec_z1);
            triangle_projected.v1.position.z <= rec_z1;
            triangle_projected.v1.color      <= triangle_in.v1.color;

            // Vertex 2
            triangle_projected.v2.position.x <= project(FOCAL_LENGTH_X, triangle_in.v2.position.x, rec_z2);
            triangle_projected.v2.position.y <= project(FOCAL_LENGTH_Y, triangle_in.v2.position.y, rec_z2);
            triangle_projected.v2.position.z <= rec_z2;
            triangle_projected.v2.color      <= triangle_in.v2.color;
        end
    end

    // Output handshake
    assign projected_triangle_m_valid = state == S_OUT;

    assign projected_triangle_m_data     = triangle_projected;
    assign projected_triangle_m_metadata = metadata_in;

endmodule

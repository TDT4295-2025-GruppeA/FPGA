import types_pkg::*;
import fixed_pkg::*;

module Transform #(
)(
    input  logic        clk,
    input  logic        rstn,

    input  triangle_tf_t   triangle_tf_s_data,
    input  logic            triangle_tf_s_metadata,
    input  logic        triangle_tf_s_valid,
    output logic        triangle_tf_s_ready,

    output triangle_t triangle_m_data,
    output logic        triangle_m_valid,
    output logic         triangle_m_metadata,
    input  logic        triangle_m_ready
);

    triangle_t triangle_reg;
    rotmat_t rotmat_reg;
    position_t pos_reg;
    logic m_reg;

    triangle_t t_transformed;
    logic processing;

    assign triangle_tf_s_ready = !processing || (triangle_m_valid && triangle_m_ready);

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            triangle_reg <= '0;
            rotmat_reg <= '0;
            pos_reg <= '0;
            processing <= 0;
            m_reg <= 0;
        end else if (triangle_tf_s_ready && triangle_tf_s_valid) begin
            triangle_reg <= triangle_tf_s_data.triangle;
            rotmat_reg <= triangle_tf_s_data.transform.rotmat;
            pos_reg <= triangle_tf_s_data.transform.position;
            m_reg <= triangle_tf_s_metadata;
            processing <= 1;
        end else if (triangle_m_valid && triangle_m_ready) begin
            processing <= 0;
        end
    end

    always_comb begin
        t_transformed = '0;

        // === Vertex 0 ===
        t_transformed.v0.position.x = add(add(mul(rotmat_reg.m00, triangle_reg.v0.position.x),
                                     mul(rotmat_reg.m01, triangle_reg.v0.position.y)),
                                 add(mul(rotmat_reg.m02, triangle_reg.v0.position.z),
                                     pos_reg.x));

        t_transformed.v0.position.y = add(add(mul(rotmat_reg.m10, triangle_reg.v0.position.x),
                                     mul(rotmat_reg.m11, triangle_reg.v0.position.y)),
                                 add(mul(rotmat_reg.m12, triangle_reg.v0.position.z),
                                     pos_reg.y));

        t_transformed.v0.position.z = add(add(mul(rotmat_reg.m20, triangle_reg.v0.position.x),
                                     mul(rotmat_reg.m21, triangle_reg.v0.position.y)),
                                 add(mul(rotmat_reg.m22, triangle_reg.v0.position.z),
                                     pos_reg.z));

        // === Vertex 1 ===
        t_transformed.v1.position.x = add(add(mul(rotmat_reg.m00, triangle_reg.v1.position.x),
                                     mul(rotmat_reg.m01, triangle_reg.v1.position.y)),
                                 add(mul(rotmat_reg.m02, triangle_reg.v1.position.z),
                                     pos_reg.x));

        t_transformed.v1.position.y = add(add(mul(rotmat_reg.m10, triangle_reg.v1.position.x),
                                     mul(rotmat_reg.m11, triangle_reg.v1.position.y)),
                                 add(mul(rotmat_reg.m12, triangle_reg.v1.position.z),
                                     pos_reg.y));

        t_transformed.v1.position.z = add(add(mul(rotmat_reg.m20, triangle_reg.v1.position.x),
                                     mul(rotmat_reg.m21, triangle_reg.v1.position.y)),
                                 add(mul(rotmat_reg.m22, triangle_reg.v1.position.z),
                                     pos_reg.z));

        // === Vertex 2 ===
        t_transformed.v2.position.x = add(add(mul(rotmat_reg.m00, triangle_reg.v2.position.x),
                                     mul(rotmat_reg.m01, triangle_reg.v2.position.y)),
                                 add(mul(rotmat_reg.m02, triangle_reg.v2.position.z),
                                     pos_reg.x));

        t_transformed.v2.position.y = add(add(mul(rotmat_reg.m10, triangle_reg.v2.position.x),
                                     mul(rotmat_reg.m11, triangle_reg.v2.position.y)),
                                 add(mul(rotmat_reg.m12, triangle_reg.v2.position.z),
                                     pos_reg.y));

        t_transformed.v2.position.z = add(add(mul(rotmat_reg.m20, triangle_reg.v2.position.x),
                                     mul(rotmat_reg.m21, triangle_reg.v2.position.y)),
                                 add(mul(rotmat_reg.m22, triangle_reg.v2.position.z),
                                     pos_reg.z));

        t_transformed.v0.color = triangle_reg.v0.color;
        t_transformed.v1.color = triangle_reg.v1.color;
        t_transformed.v2.color = triangle_reg.v2.color;
    end

    logic valid_reg;

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            valid_reg <= 0;
        end else if (triangle_tf_s_ready && triangle_tf_s_valid) begin
            valid_reg <= 1;
        end else if (triangle_m_valid && triangle_m_ready) begin
            valid_reg <= 0;
        end
    end

    assign triangle_m_data = t_transformed;
    assign triangle_m_metadata = m_reg;
    assign triangle_m_valid = processing && valid_reg;

endmodule

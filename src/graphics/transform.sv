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

    task automatic transform_vertex(
        input  rotmat_t   rotmat,
        input  vertex_t   vin,
        input  position_t     pos,
        output vertex_t   vout
    );
    begin
        // X coordinate
        vout.position.x = add(
            add(
                mul(rotmat_reg.m00, vin.position.x),
                mul(rotmat_reg.m01, vin.position.y)
            ),
            add(
                mul(rotmat_reg.m02, vin.position.z),
                pos.x
            )
        );

        // Y coordinate
        vout.position.y = add(
            add(
                mul(rotmat_reg.m10, vin.position.x),
                mul(rotmat_reg.m11, vin.position.y)
            ),
            add(
                mul(rotmat_reg.m12, vin.position.z),
                pos.y
            )
        );

        // Z coordinate
        vout.position.z = add(
            add(
                mul(rotmat_reg.m20, vin.position.x),
                mul(rotmat_reg.m21, vin.position.y)
            ),
            add(
                mul(rotmat_reg.m22, vin.position.z),
                pos.z
            )
        );
    end
    endtask

    always_comb begin
        t_transformed = '0;

        transform_vertex(rotmat_reg, triangle_reg.v0, pos_reg, t_transformed.v0);
        transform_vertex(rotmat_reg, triangle_reg.v1, pos_reg, t_transformed.v1);
        transform_vertex(rotmat_reg, triangle_reg.v2, pos_reg, t_transformed.v2);

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

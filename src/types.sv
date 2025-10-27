package types_pkg;
    import fixed_pkg::*;
    
    typedef struct packed {
        logic [3:0] red;
        logic [3:0] green;
        logic [3:0] blue;
        logic [3:0] reserved;
    } color_t;

    typedef struct packed {
        fixed x;
        fixed y;
        fixed z;
    } position_t;

    typedef struct packed {
        position_t position;
        color_t color;
    } vertex_t;

    typedef struct packed {
        vertex_t v0;
        vertex_t v1;
        vertex_t v2;
    } triangle_t;

    typedef struct packed {
        logic last;
    } triangle_metadata_t;

    typedef struct packed {
        fixed m00;
        fixed m01;
        fixed m02;
        fixed m10;
        fixed m11;
        fixed m12;
        fixed m20;
        fixed m21;
        fixed m22;
    } rotmat_t;

    typedef struct packed {
        position_t position;
        rotmat_t rotmat;
    } transform_t;

    typedef struct packed {
        logic [7:0] model_id;
        transform_t transform;
    } modelinstance_t;

    // TODO: Typedef for pixel coordinates based on buffer size.
    typedef struct packed {
        logic [9:0] x;
        logic [9:0] y;
    } pixel_coordinate_t;

    typedef struct packed {
        logic covered;
        fixed depth;
        color_t color;
        pixel_coordinate_t coordinate;
    } pixel_data_t;

    typedef struct packed {
        logic last;
    } pixel_metadata_t;

    typedef struct packed {
        fixed top;
        fixed bottom;
        fixed left;
        fixed right;
    } bounding_box_t;

    typedef struct packed {
        triangle_t triangle;
        fixed area_inv; // Actually 1 / (2 * area)
        logic small_area; // Area less than threshold
        bounding_box_t bounding_box;
    } attributed_triangle_t;

    typedef struct packed {
        triangle_t triangle;
        transform_t transform;
    } triangle_tf_t;

    // To keep the protocol between the MCU and the FPGA stable,
    // we'll always use Q16.16 format for positions and matrices.
    // We'll just convert to/from our internal fixed point format
    // when receiving data. This requires these structs.

    localparam int PROTOCOL_DECIMAL_WIDTH = 16;
    localparam int PROTOCOL_TOTAL_WIDTH = 32;

    typedef logic signed [PROTOCOL_TOTAL_WIDTH-1:0] protocol_fixed;

    typedef struct packed {
        protocol_fixed x;
        protocol_fixed y;
        protocol_fixed z;
    } protocol_position_t;

    typedef struct packed {
        protocol_fixed m00;
        protocol_fixed m01;
        protocol_fixed m02;
        protocol_fixed m10;
        protocol_fixed m11;
        protocol_fixed m12;
        protocol_fixed m20;
        protocol_fixed m21;
        protocol_fixed m22;
    } protocol_rotmat_t;

    typedef struct packed {
        protocol_position_t position;
        protocol_rotmat_t rotmat;
    } protocol_transform_t;

    localparam int DELTA_DECIMAL_WIDTH = PROTOCOL_DECIMAL_WIDTH - DECIMAL_WIDTH;

    function automatic transform_t parse_protocol_transform(protocol_transform_t proto_tf);
        transform_t internal_tf = '{
            position: '{
                x: fixed'(proto_tf.position.x >>> DELTA_DECIMAL_WIDTH),
                y: fixed'(proto_tf.position.y >>> DELTA_DECIMAL_WIDTH),
                z: fixed'(proto_tf.position.z >>> DELTA_DECIMAL_WIDTH)
            },
            rotmat: '{
                m00: fixed'(proto_tf.rotmat.m00 >>> DELTA_DECIMAL_WIDTH),
                m01: fixed'(proto_tf.rotmat.m01 >>> DELTA_DECIMAL_WIDTH),
                m02: fixed'(proto_tf.rotmat.m02 >>> DELTA_DECIMAL_WIDTH),
                m10: fixed'(proto_tf.rotmat.m10 >>> DELTA_DECIMAL_WIDTH),
                m11: fixed'(proto_tf.rotmat.m11 >>> DELTA_DECIMAL_WIDTH),
                m12: fixed'(proto_tf.rotmat.m12 >>> DELTA_DECIMAL_WIDTH),
                m20: fixed'(proto_tf.rotmat.m20 >>> DELTA_DECIMAL_WIDTH),
                m21: fixed'(proto_tf.rotmat.m21 >>> DELTA_DECIMAL_WIDTH),
                m22: fixed'(proto_tf.rotmat.m22 >>> DELTA_DECIMAL_WIDTH)
            }
        };
        return internal_tf;
    endfunction

endpackage
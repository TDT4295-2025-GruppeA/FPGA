package types_pkg;
    import fixed_pkg::*;
    
    typedef struct packed {
        logic [3:0] red;
        logic [3:0] green;
        logic [3:0] blue;
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
        triangle_t triangle;
        fixed area_inv; // Actually 1 / (2 * area)
    } attributed_triangle_t;
    
    typedef struct packed {
        triangle_t triangle;
        transform_t transform;
    } triangle_tf_t;

endpackage
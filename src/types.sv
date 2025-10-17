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
        vertex_t a;
        vertex_t b;
        vertex_t c;
    } triangle_t;

    typedef struct packed {
        fixed xx;
        fixed xy;
        fixed xz;
        fixed yx;
        fixed yy;
        fixed yz;
        fixed zx;
        fixed zy;
        fixed zz;
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
        logic valid;
        fixed depth;
        color_t color;
        pixel_coordinate_t coordinate;
    } pixel_data_t;
endpackage
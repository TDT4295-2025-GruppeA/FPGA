import fixed_pkg::*;

package types_pkg;
    typedef logic[7:0] byte_t;
    typedef logic[15:0] short_t;

    typedef struct packed {
        logic last;
    } model_metadata_t;

    typedef struct packed {
        logic last;
        model_metadata_t model_metadata;
    } triangle_metadata_t;

    typedef struct packed {
        logic [4:0] red;
        logic [5:0] green;
        logic [4:0] blue;
    } color_t;

    typedef struct packed {
        fixed x;
        fixed y;
        fixed z;
    } position_t;

    typedef struct packed {
        color_t color;
        position_t position;
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
        byte_t model_id;
        transform_t transform;
    } modelinstance_t;

    typedef struct packed {
        byte_t model_id;
        triangle_t triangle;
    } modelbuf_data_t;

    typedef struct packed {
        logic last;
    } scenebuf_meta_t;
endpackage
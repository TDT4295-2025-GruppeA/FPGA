import fixed_pkg::*;

package types_pkg;
    // Generic types
    typedef logic[7:0] byte_t;
    typedef logic[15:0] short_t;

    // Core types
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

    // Types used in the pipeline head
    typedef struct packed {
        byte_t model_id;
        triangle_t triangle;
    } modelbuf_write_t; // Write-interface ModelBuffer

    typedef struct packed {
        byte_t model_index;
        short_t triangle_index;
    } modelbuf_read_t; // Read-interface ModelBuffer

    typedef struct packed {
        logic last;
    } triangle_meta_t; // Metadata for a triangle

    typedef struct packed {
        logic last;
    } modelinstance_meta_t; // Metadata for a modelinstance

    // Interface from PipelineHead to rest of pipeline
    typedef struct packed {
        transform_t transform;
        triangle_t triangle;
    } triangle_tf_t; // Triangle transform pair fed into pipeline

    typedef struct packed {
        logic model_last;
        logic triangle_last;
    } triangle_tf_meta_t; // Metadata for a triangle transform pair

    // Main pipeline
endpackage
import fixed_pkg::*;

package types_pkg;
    typedef struct packed {
        logic [3:0] red;
        logic [3:0] green;
        logic [3:0] blue;
    } color_t;

    typedef struct packed {
        fixed x;
        fixed y;
        fixed z;
        color_t color;
    } vertex_t;

    typedef struct packed {
        vertex_t a;
        vertex_t b;
        vertex_t c;
    } triangle_t;
endpackage
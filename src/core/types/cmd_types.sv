    
package cmd_types_pkg;
    import fixed_pkg::*;
    import types_pkg::*;

    typedef struct packed {
        logic [4:0] red;
        logic [5:0] green;
        logic [4:0] blue;
    } cmd_color_t;

    typedef struct packed {
        fixed_q16x16 x;
        fixed_q16x16 y;
        fixed_q16x16 z;
    } cmd_position_t;

    typedef struct packed {
        cmd_color_t color;
        cmd_position_t position;
    } cmd_vertex_t;

    typedef struct packed {
        cmd_vertex_t v0;
        cmd_vertex_t v1;
        cmd_vertex_t v2;
    } cmd_triangle_t;

    typedef struct packed {
        fixed_q16x16 m00;
        fixed_q16x16 m01;
        fixed_q16x16 m02;
        fixed_q16x16 m10;
        fixed_q16x16 m11;
        fixed_q16x16 m12;
        fixed_q16x16 m20;
        fixed_q16x16 m21;
        fixed_q16x16 m22;
    } cmd_rotmat_t;

    typedef struct packed {
        cmd_position_t position;
        cmd_rotmat_t rotmat;
    } cmd_transform_t;

    typedef struct packed {
        byte_t model_id;
        cmd_transform_t transform;
    } cmd_modelinstance_t;

    typedef struct packed {
        logic[6:0] unused;
        logic last;
        cmd_modelinstance_t modelinst;
    } cmd_scene_t;

        function automatic color_t cast_c565_c444(cmd_color_t color);
        color_t color_out;
        color_out.red = 4'(color.red >> 1);
        color_out.green = 4'(color.green >> 2);
        color_out.blue = 4'(color.blue >> 1);
        return color_out;
    endfunction

    function automatic position_t cast_position(cmd_position_t position);
        position_t pos_out;
        pos_out.x = cast_q16x16_q11x14(position.x);
        pos_out.y = cast_q16x16_q11x14(position.y);
        pos_out.z = cast_q16x16_q11x14(position.z);
        return pos_out;
    endfunction

    function automatic vertex_t cast_vertex(cmd_vertex_t vertex);
        vertex_t vertex_out;
        vertex_out.position = cast_position(vertex.position);
        vertex_out.color = cast_c565_c444(vertex.color);
        return vertex_out;
    endfunction

    function automatic triangle_t cast_triangle(cmd_triangle_t triangle);
        triangle_t triangle_out;
        triangle_out.v0 = cast_vertex(triangle.v0);
        triangle_out.v1 = cast_vertex(triangle.v1);
        triangle_out.v2 = cast_vertex(triangle.v2);
        return triangle_out;
    endfunction

    function automatic modelinstance_t cast_modelinstance(cmd_modelinstance_t modelinstance);
        modelinstance_t modelinstance_out;
        modelinstance_out.model_id = modelinstance.model_id;
        modelinstance_out.transform.position = cast_position(modelinstance.transform.position);
        modelinstance_out.transform.rotmat.m00 = cast_q16x16_q11x14(modelinstance.transform.rotmat.m00);
        modelinstance_out.transform.rotmat.m01 = cast_q16x16_q11x14(modelinstance.transform.rotmat.m01);
        modelinstance_out.transform.rotmat.m02 = cast_q16x16_q11x14(modelinstance.transform.rotmat.m02);
        modelinstance_out.transform.rotmat.m10 = cast_q16x16_q11x14(modelinstance.transform.rotmat.m10);
        modelinstance_out.transform.rotmat.m11 = cast_q16x16_q11x14(modelinstance.transform.rotmat.m11);
        modelinstance_out.transform.rotmat.m12 = cast_q16x16_q11x14(modelinstance.transform.rotmat.m12);
        modelinstance_out.transform.rotmat.m20 = cast_q16x16_q11x14(modelinstance.transform.rotmat.m20);
        modelinstance_out.transform.rotmat.m21 = cast_q16x16_q11x14(modelinstance.transform.rotmat.m21);
        modelinstance_out.transform.rotmat.m22 = cast_q16x16_q11x14(modelinstance.transform.rotmat.m22);
        return modelinstance_out;
    endfunction
endpackage
import types_pkg::*;
import fixed_pkg::*;

// Simple read-only memory module for storing model triangles.
module ModelRom #(
    parameter int TRIANGLE_COUNT = 3,
    parameter string FILE_PATH = "static/cube"
) (
    input logic clk,
    input logic [$clog2(TRIANGLE_COUNT)-1:0] address,
    output triangle_t triangle
);

    // Model data is stored in Q16.16 format for positions
    // independently of the internal fixed point format used in 
    // the FPGA. We convert here on read to our internal fixed 
    // point format. To do that we have these helper structs 
    // which represent how the data is stored in the ROM.

    typedef struct packed {
        logic [31:0] x;
        logic [31:0] y;
        logic [31:0] z;
    } aligned_position_t;

    typedef struct packed {
        aligned_position_t position;
        logic [15:0] color;
    } aligned_vertex_t;

    typedef struct packed {
        aligned_vertex_t v0;
        aligned_vertex_t v1;
        aligned_vertex_t v2;
    } aligned_triangle_t;

    // Vivado won't infer block RAMs for word sizes larger than 72 bits,
    // so we split each triangle into 5 separate memories.
    (* rom_style = "block" *) logic [71:0] mem0 [TRIANGLE_COUNT];
    (* rom_style = "block" *) logic [71:0] mem1 [TRIANGLE_COUNT];
    (* rom_style = "block" *) logic [71:0] mem2 [TRIANGLE_COUNT];
    (* rom_style = "block" *) logic [71:0] mem3 [TRIANGLE_COUNT];
    (* rom_style = "block" *) logic [47:0] mem4 [TRIANGLE_COUNT];
    
    initial begin
        $readmemh({FILE_PATH, "0.mem"}, mem0);
        $readmemh({FILE_PATH, "1.mem"}, mem1);
        $readmemh({FILE_PATH, "2.mem"}, mem2);
        $readmemh({FILE_PATH, "3.mem"}, mem3);
        $readmemh({FILE_PATH, "4.mem"}, mem4);
    end

    logic [71:0] tri_data0, tri_data1, tri_data2, tri_data3;
    logic [47:0] tri_data4;

    always_ff @(posedge clk) begin
        tri_data0 <= mem0[address];
        tri_data1 <= mem1[address];
        tri_data2 <= mem2[address];
        tri_data3 <= mem3[address];
        tri_data4 <= mem4[address];
    end

    aligned_triangle_t aligned_triangle;
    assign aligned_triangle = {
        tri_data0,
        tri_data1,
        tri_data2,
        tri_data3,
        tri_data4
    };

    // Compensate for the difference in fixed point formats by rightshifting.p
    assign triangle = '{
        v0: '{
            position: '{
                x: fixed'(aligned_triangle.v0.position.x >>> (16 - DECIMAL_WIDTH)),
                y: fixed'(aligned_triangle.v0.position.y >>> (16 - DECIMAL_WIDTH)),
                z: fixed'(aligned_triangle.v0.position.z >>> (16 - DECIMAL_WIDTH))
            },
            color: aligned_triangle.v0.color
        },
        v1: '{
            position: '{
                x: fixed'(aligned_triangle.v1.position.x >>> (16 - DECIMAL_WIDTH)),
                y: fixed'(aligned_triangle.v1.position.y >>> (16 - DECIMAL_WIDTH)),
                z: fixed'(aligned_triangle.v1.position.z >>> (16 - DECIMAL_WIDTH))
            },
            color: aligned_triangle.v1.color
        },
        v2: '{
            position: '{
                x: fixed'(aligned_triangle.v2.position.x >>> (16 - DECIMAL_WIDTH)),
                y: fixed'(aligned_triangle.v2.position.y >>> (16 - DECIMAL_WIDTH)),
                z: fixed'(aligned_triangle.v2.position.z >>> (16 - DECIMAL_WIDTH))
            },
            color: aligned_triangle.v2.color
        }
    };
endmodule

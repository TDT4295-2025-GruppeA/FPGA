import types_pkg::*;

// Simple read-only memory module for storing model triangles.
module ModelRom #(
    parameter int TRIANGLE_COUNT = 3,
    parameter string FILE_PATH = "static/cube"
) (
    input logic clk,
    input logic [$clog2(TRIANGLE_COUNT)-1:0] address,
    output triangle_t triangle
);
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

    assign triangle = {
        tri_data0,
        tri_data1,
        tri_data2,
        tri_data3,
        tri_data4
    };
endmodule

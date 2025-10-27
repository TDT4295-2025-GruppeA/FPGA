import types_pkg::*;

module SceneBuffer #(
    parameter SCENE_COUNT     = 2,
    parameter TRANSFORM_COUNT = 50
)(
    input logic clk,
    input logic rstn,

    // Write interface
    input logic write_in_valid,
    output logic write_in_ready,
    input modelinstance_t write_in_data,
    input modelinstance_meta_t write_in_metadata,

    // Read interface
    output logic read_out_valid,
    input logic read_out_ready,
    output modelinstance_t read_out_data,
    output modelinstance_meta_t read_out_metadata
);
    typedef logic [$clog2(TRANSFORM_COUNT)-1:0] transform_idx_t;
    typedef logic [$clog2(SCENE_COUNT)-1:0] scene_idx_t;

    localparam scene_idx_t COUNT_SCENE = scene_idx_t'(SCENE_COUNT);
    localparam transform_idx_t COUNT_TRANSFORM = transform_idx_t'(TRANSFORM_COUNT);

    modelinstance_t transforms [SCENE_COUNT][TRANSFORM_COUNT];

    typedef struct {
        transform_idx_t size;  // Total size of scene
        logic ready; // scene completed and ready to read
    } scene_t;

    scene_t scenes[SCENE_COUNT];

    // Active scene and transform indices
    scene_idx_t      scene_idx_write, scene_idx_read;
    transform_idx_t  write_idx, read_idx;

    // Flags
    assign write_in_ready = !(scenes[scene_idx_write].ready ||
                        (write_idx == COUNT_TRANSFORM));

    // Sequential logic
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            scene_idx_write <= 0;
            scene_idx_read <= 0;
            write_idx <= 0;
            read_idx  <= 0;
            for (int i = 0; i < SCENE_COUNT; i++) begin
                scenes[i].size  <= 0;
                scenes[i].ready <= 0;
            end
        end else begin
            // Writing logic
            if (write_in_valid && write_in_ready) begin
                transforms[scene_idx_write][write_idx] <= write_in_data;
                scenes[scene_idx_write].size <= write_idx + 1;
                write_idx <= write_idx + 1;
                if (write_in_metadata.last && !scenes[scene_idx_write].ready) begin
                    scenes[scene_idx_write].ready <= 1;
                    if (scene_idx_write == scene_idx_t'(SCENE_COUNT - 1)) begin
                            scene_idx_write <= 0;
                        end else begin
                            scene_idx_write <= (scene_idx_write + 1);
                        end
                    write_idx <= 0;
                end
            end

            // Reading logic
            if (read_out_ready) begin
                if (read_idx < scenes[scene_idx_read].size) begin
                    read_idx <= read_idx + 1;
                    read_out_valid <= 1;
                    read_out_data <= transforms[scene_idx_read][read_idx];
                    read_out_metadata.last <= (read_idx + 1 == scenes[scene_idx_read].size);
                end else begin
                    // finished scene
                    scenes[scene_idx_read].ready <= 0;
                    if (scene_idx_read == scene_idx_t'(SCENE_COUNT - 1)) begin
                        scene_idx_read <= 0;
                    end else begin
                        scene_idx_read <= (scene_idx_read + 1);
                    end
                    scenes[scene_idx_read].size <= 0;
                    read_idx <= 0;
                    read_out_valid <= 0;
                end
            end
        end
    end

endmodule

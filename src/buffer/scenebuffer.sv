import types_pkg::*;

module SceneBuffer #(
    parameter SCENE_COUNT     = 2,
    parameter TRANSFORM_COUNT = 50
)(
    input logic clk,
    input logic rstn,

    // Write interface
    input logic write_en,
    input modelinstance_t write_transform,
    input logic write_ready, // mark current scene complete
    output logic write_full, // no free scene available

    // Read interface
    input logic read_en,
    output logic read_done, // scene finished
    output modelinstance_t read_transform,
    output logic read_valid
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
    assign write_full = scenes[scene_idx_write].ready ||
                        (write_idx == COUNT_TRANSFORM);

    assign read_transform = transforms[scene_idx_read][read_idx];
    assign read_valid = scenes[scene_idx_read].ready;
    assign read_done = read_valid &&
                       (read_idx == scenes[scene_idx_read].size) &&
                       read_en;

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
            if (write_en && !write_full) begin
                transforms[scene_idx_write][write_idx] <= write_transform;
                scenes[scene_idx_write].size <= write_idx;
                write_idx <= write_idx + 1;
            end
            if (write_ready && !scenes[scene_idx_write].ready) begin
                scenes[scene_idx_write].ready <= 1;
                if (scene_idx_write == scene_idx_t'(SCENE_COUNT - 1)) begin
                        scene_idx_write <= 0;
                    end else begin
                        scene_idx_write <= (scene_idx_write + 1);
                    end
                write_idx <= 0;
            end

            // Reading logic
            if (read_en && read_valid) begin
                if (read_idx < scenes[scene_idx_read].size) begin
                    read_idx <= read_idx + 1;
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
                end
            end
        end
    end

endmodule

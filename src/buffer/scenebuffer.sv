import fixed_pkg::*;
import types_pkg::*;

module SceneBuffer #(
    parameter SCENE_COUNT     = 2,
    parameter TRANSFORM_COUNT = 50
)(
    input logic clk,
    input logic rstn,

    // Write interface
    input logic write_s_valid,
    output logic write_s_ready,
    input modelinstance_t write_s_data,
    input modelinstance_meta_t write_s_metadata,

    // Camera interface
    input logic camera_s_valid,
    output logic camera_s_ready,
    input transform_t camera_s_data,

    // Read interface
    output logic read_m_valid,
    input logic read_m_ready,
    output scenebuf_modelinstance_t read_m_data,
    output last_t read_m_metadata
);
    typedef logic [$clog2(TRANSFORM_COUNT * SCENE_COUNT)-1:0] transform_idx_t;
    typedef logic [$clog2(SCENE_COUNT)-1:0] scene_idx_t;

    localparam scene_idx_t COUNT_SCENE = scene_idx_t'(SCENE_COUNT);
    localparam transform_idx_t COUNT_TRANSFORM = transform_idx_t'(TRANSFORM_COUNT);

    transform_idx_t addr_write;
    transform_idx_t addr_read;

    typedef struct {
        transform_idx_t size;  // Total size of scene
        logic ready; // scene completed and ready to read
        transform_t camera_transform;
    } scene_t;

    scene_t scenes[SCENE_COUNT];

    // Active scene and transform indices
    scene_idx_t      scene_idx_write, scene_idx_read;
    transform_idx_t  write_idx, read_idx;

    // Flags
    assign write_s_ready = !(scenes[scene_idx_write].ready || (write_idx == COUNT_TRANSFORM));

    assign addr_write = transform_idx_t'(scene_idx_write) * COUNT_TRANSFORM + write_idx;
    assign addr_read = transform_idx_t'(scene_idx_read) * COUNT_TRANSFORM + read_idx;

    modelinstance_t bram_read;
    Bram #(
        .ENTRY_COUNT(SCENE_COUNT * TRANSFORM_COUNT),
        .DATA_WIDTH($bits(modelinstance_t))
    ) bram (
        .clk(clk),
        
        .write_enable(write_s_valid && write_s_ready),
        .write_address(addr_write),
        .write_data(write_s_data),

        .read_enable(read_m_ready && (read_idx < scenes[scene_idx_read].size) && scenes[scene_idx_read].ready),
        .read_address(addr_read),
        .read_data(bram_read)
    );
    assign read_m_data.model_transform = bram_read.transform;
    assign read_m_data.model_id = bram_read.model_id;

    // Sequential logic
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            scene_idx_write <= 0;
            scene_idx_read <= 0;
            write_idx <= 0;
            read_idx  <= 0;
            read_m_valid <= 0;
            camera_s_ready <= 1;
            for (int i = 0; i < SCENE_COUNT; i++) begin
                scenes[i].size  <= 0;
                scenes[i].ready <= 0;
                scenes[i].camera_transform.position <= '{x: 0, y: 0, z: 0};
                scenes[i].camera_transform.rotmat <= '{m00: rtof(1), m01: 0, m02: 0, m10: 0, m11: rtof(1), m12: 0, m20: 0, m21: 0, m22: rtof(1)};
            end
        end else begin
            // Writing logic
            if (write_s_valid && write_s_ready) begin
                scenes[scene_idx_write].size <= write_idx + 1;
                write_idx <= write_idx + 1;
                if (write_s_metadata.last && !scenes[scene_idx_write].ready) begin
                    scenes[scene_idx_write].ready <= 1;
                    if (scene_idx_write == scene_idx_t'(SCENE_COUNT - 1)) begin
                            scene_idx_write <= 0;
                        end else begin
                            scene_idx_write <= (scene_idx_write + 1);
                        end
                    write_idx <= 0;
                end
            end

            if (camera_s_valid && camera_s_ready) begin
                scenes[scene_idx_write].camera_transform <= camera_s_data;
            end

            // Reading logic
            if (read_m_ready) begin
                if (read_idx < scenes[scene_idx_read].size && scenes[scene_idx_read].ready) begin
                    read_idx <= read_idx + 1;
                    read_m_valid <= 1;
                    read_m_metadata.last <= (read_idx + 1 == scenes[scene_idx_read].size);
                    read_m_data.camera_transform <= scenes[scene_idx_read].camera_transform;
                end else if (scenes[scene_idx_read].ready) begin
                    // finished scene
                    scenes[scene_idx_read].ready <= 0;
                    if (scene_idx_read == scene_idx_t'(SCENE_COUNT - 1)) begin
                        scene_idx_read <= 0;
                    end else begin
                        scene_idx_read <= (scene_idx_read + 1);
                    end
                    scenes[scene_idx_read].size <= 0;
                    read_idx <= 0;
                    read_m_valid <= 0;
                end else begin
                    // We are waiting for the scene to be populated
                end
            end
        end
    end

endmodule

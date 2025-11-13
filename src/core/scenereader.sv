import types_pkg::*;

// Read scene from scenebuffer, and pair its transforms with tringles
// in the model buffer
module SceneReader #(
    parameter MAX_MODEL_COUNT = 10,
    parameter MAX_TRIANGLE_COUNT = 100
)(
    input clk,
    input rstn,

    input logic scene_s_valid,
    output logic scene_s_ready,
    input scenebuf_modelinstance_t scene_s_data,
    input last_t scene_s_metadata,

    output logic model_m_valid,
    input logic model_m_ready,
    output modelbuf_read_t model_m_data,

    input logic model_s_valid,
    output logic model_s_ready,
    input triangle_t model_s_data,
    input triangle_meta_t model_s_metadata,

    output logic triangle_tf_m_valid,
    input logic triangle_tf_m_ready,
    output pipeline_entry_t triangle_tf_m_data,
    output last_t triangle_tf_m_metadata
);

    typedef enum logic [1:0] {
        IDLE = '0,
        PROCESSING = '1
    } state_t;
    state_t state;

    scenebuf_modelinstance_t current_model;
    last_t current_model_metadata;
    short_t triangle_index;
    logic triangle_index_valid;

    assign triangle_index_valid = state == PROCESSING;
    assign scene_s_ready = state == IDLE;
    
    assign model_m_data.model_index = current_model.model_id;
    assign model_m_data.triangle_index = triangle_index;
    assign model_m_valid = triangle_index_valid;

    assign triangle_tf_m_data.model_transform = current_model.model_transform;
    assign triangle_tf_m_data.camera_transform = current_model.camera_transform;
    assign triangle_tf_m_data.triangle = model_s_data;
    assign triangle_tf_m_metadata.last = model_s_metadata.last && current_model_metadata.last;
    assign triangle_tf_m_valid = model_s_valid;
    assign model_s_ready = triangle_tf_m_ready;


    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            state <= IDLE;
        end else begin
            case (state)
                IDLE: begin
                    if (scene_s_valid && scene_s_ready) begin
                        current_model <= scene_s_data;
                        current_model_metadata <= scene_s_metadata;
                        state <= PROCESSING;
                    end
                end
                PROCESSING: begin
                    if (model_m_ready && model_m_valid) begin
                        triangle_index <= triangle_index + 1;
                    end
                    if (model_s_metadata.last && model_s_valid && model_m_ready && model_s_ready && model_m_valid) begin // TODO: FIX ME
                        state <= IDLE;
                        triangle_index <= 0;
                    end
                end
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule
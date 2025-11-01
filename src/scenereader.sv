import types_pkg::*;

// Read scene from scenebuffer, and pair its transforms with tringles
// in the model buffer
module SceneReader #(
    parameter MAX_MODEL_COUNT = 10,
    parameter MAX_TRIANGLE_COUNT = 100
)(
    input clk,
    input rstn,

    input logic scene_in_valid,
    output logic scene_in_ready,
    input modelinstance_t scene_in_data,
    input modelinstance_meta_t scene_in_metadata,

    output logic model_out_valid,
    input logic model_out_ready,
    output modelbuf_read_t model_out_data,

    input logic model_in_valid,
    output logic model_in_ready,
    input triangle_t model_in_data,
    input triangle_meta_t model_in_metadata,

    output logic triangle_tf_out_valid,
    input logic triangle_tf_out_ready,
    output triangle_tf_t triangle_tf_out_data,
    output triangle_tf_meta_t triangle_tf_out_metadata
);

    typedef enum logic [1:0] {
        IDLE = '0,
        PROCESSING = '1
    } state_t;
    state_t state;

    modelinstance_t current_model;
    modelinstance_meta_t current_model_metadata;
    short_t triangle_index;
    
    assign model_out_data.model_index = current_model.model_id;
    assign model_out_data.triangle_index = triangle_index;

    assign triangle_tf_out_data.transform = current_model.transform;
    assign triangle_tf_out_data.triangle = model_in_data;
    assign triangle_tf_out_metadata.triangle_last = model_in_metadata.last;
    assign triangle_tf_out_metadata.model_last = current_model_metadata;
    assign triangle_tf_out_valid = model_in_valid;
    assign model_in_ready = triangle_tf_out_ready;


    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            scene_in_ready <= 1;
            state <= IDLE;
        end else begin
            case (state)
                IDLE: begin
                    if (scene_in_valid && scene_in_ready) begin
                        scene_in_ready <= 0;
                        current_model <= scene_in_data;
                        current_model_metadata <= scene_in_metadata;
                        state <= PROCESSING;
                        triangle_index <= 0;
                    end
                end
                PROCESSING: begin
                    if (model_out_ready && model_out_valid) begin
                        triangle_index <= triangle_index + 1;
                    end
                    if (model_in_metadata.last && model_in_valid) begin
                        model_out_valid <= 0;
                        state <= IDLE;
                        scene_in_ready <= 1;
                    end else begin
                        model_out_valid <= 1;
                    end
                end
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule
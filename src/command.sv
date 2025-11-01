import types_pkg::*;

module CommandInput(
    input  logic clk,
    input  logic rstn,

    // Command input
    input  logic  cmd_in_valid,
    output logic  cmd_in_ready,
    input  byte_t cmd_in_data,

    // Command response
    output logic  cmd_out_valid,
    input  logic  cmd_out_ready,
    output byte_t cmd_out_data,

    // ModelBuffer comms
    output logic            model_out_valid,
    input  logic            model_out_ready,
    output modelbuf_write_t  model_out_data,

    // SceneBuffer comms
    output logic            scene_out_valid,
    input  logic            scene_out_ready,
    output modelinstance_t  scene_out_data,
    output modelinstance_meta_t  scene_out_metadata
);
    // The states we can be in
    typedef enum logic [1:0] {
        STATE_IDLE               = 2'd0,
        STATE_BEGIN_MODEL_UPLOAD = 2'd1,
        STATE_UPLOAD_TRIANGLE    = 2'd2,
        STATE_ADD_MODELINSTANCE  = 2'd3
    } state_t;

    // Commands we have implemented
    localparam byte_t CMD_BEGIN_MODEL_UPLOAD  = byte_t'(8'hA0);
    localparam byte_t CMD_UPLOAD_TRIANGLE     = byte_t'(8'hA1);
    localparam byte_t CMD_ADD_MODEL_INSTANCE  = byte_t'(8'hB0);

    // Function that returns the length of the command in bytes
    function automatic byte_t command_length_bytes(byte_t cmd);
        case (cmd)
            CMD_BEGIN_MODEL_UPLOAD: return byte_t'(2);
            CMD_UPLOAD_TRIANGLE: return byte_t'(1 + $bits(cmd_triangle_t) / 8);
            CMD_ADD_MODEL_INSTANCE: return byte_t'(1 + $bits(cmd_scene_t) / 8);
            default: return byte_t'(1);
        endcase
    endfunction

    // State machine state
    state_t state;
    byte_t bytes_left;
    byte_t current_cmd;
    wire cmd_in_transaction;
    assign cmd_in_transaction = cmd_in_valid && cmd_in_ready;

    // Serializing for model buffer
    byte_t current_model_idx;

    wire model_serial_in_valid;
    wire model_serial_in_ready;
    wire byte_t model_serial_in_data;
    wire cmd_triangle_t tmp_model_out_data;
    assign model_serial_in_valid = (state == STATE_UPLOAD_TRIANGLE) && cmd_in_transaction;
    assign model_serial_in_data = cmd_in_data;
    assign model_out_data.model_id = current_model_idx;
    assign model_out_data.triangle = cast_triangle(tmp_model_out_data);

    SerialToParallelStream #(
        .INPUT_SIZE($bits(byte_t)),
        .OUTPUT_SIZE($bits(cmd_triangle_t))
    ) triangle_serializer (
        .clk(clk),
        .rstn(rstn),
        .serial_in_ready(model_serial_in_ready),
        .serial_in_valid(model_serial_in_valid),
        .serial_in_data(model_serial_in_data),
        .parallel_out_ready(model_out_ready),
        .parallel_out_valid(model_out_valid),
        .parallel_out_data(tmp_model_out_data)
    );

    // Serializing for scene buffer
    wire scene_serial_in_valid;
    wire scene_serial_in_ready;
    wire byte_t scene_serial_in_data;
    assign scene_serial_in_valid = (state == STATE_ADD_MODELINSTANCE) && cmd_in_transaction;
    assign scene_serial_in_data = cmd_in_data;

    wire cmd_scene_t scene_parallel_out_data;
    assign scene_out_data = cast_modelinstance(scene_parallel_out_data.modelinst);
    assign scene_out_metadata.last = scene_parallel_out_data.last;

    SerialToParallelStream #(
        .INPUT_SIZE($bits(byte_t)),
        .OUTPUT_SIZE($bits(cmd_scene_t))
    ) modelinstance_serializer (
        .clk(clk),
        .rstn(rstn),
        .serial_in_ready(scene_serial_in_ready),
        .serial_in_valid(scene_serial_in_valid),
        .serial_in_data(scene_serial_in_data),
        .parallel_out_ready(scene_out_ready),
        .parallel_out_valid(scene_out_valid),
        .parallel_out_data(scene_parallel_out_data)
    );

    // Currently the cmd_out interface is not used.
    assign cmd_out_valid = 1'b0;
    assign cmd_out_data  = byte_t'(0);

    // We set cmd_in_ready based on the state of the receiving element.
    // Some of them will always ready be ready, while some of them depend
    // on downstream logic.
    always_comb begin
        case (state)
            STATE_IDLE:                cmd_in_ready = 1'b1;
            STATE_BEGIN_MODEL_UPLOAD:  cmd_in_ready = 1'b1; // accept model index byte
            STATE_UPLOAD_TRIANGLE:     cmd_in_ready = model_serial_in_ready; // accept triangle bytes when serializer ready
            STATE_ADD_MODELINSTANCE:   cmd_in_ready = scene_serial_in_ready; // accept modelinstance bytes when serializer ready
            default:                   cmd_in_ready = 1'b0;
        endcase
    end

    // State transitions and bytes_left management
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            state <= STATE_IDLE;
            bytes_left <= 0;
            current_cmd <= 0;
            current_model_idx <= 0;
        end else begin
            if (cmd_in_transaction) begin
                // If we are currently IDLE and see a command byte, init the command transaction
                if (state == STATE_IDLE) begin
                    current_cmd <= cmd_in_data;
                    // Set number of bytes left in command
                    // Subtract one because we have already read one
                    bytes_left <= command_length_bytes(cmd_in_data) - 1;
    
                    // choose next state based on command
                    if (cmd_in_data == CMD_BEGIN_MODEL_UPLOAD) begin
                        state <= STATE_BEGIN_MODEL_UPLOAD;
                    end else if (cmd_in_data == CMD_UPLOAD_TRIANGLE) begin
                        state <= STATE_UPLOAD_TRIANGLE;
                    end else if (cmd_in_data == CMD_ADD_MODEL_INSTANCE) begin
                        state <= STATE_ADD_MODELINSTANCE;
                    end else begin // Ignore. TODO: Send invalid response?
                        state <= STATE_IDLE;
                    end
                end else begin
                    // Decrement bytes left for every byte we receive
                    if (bytes_left > 0) begin
                        bytes_left <= bytes_left - 1;
                    end
                    if (bytes_left - 1 == 0) begin
                        state <= STATE_IDLE;
                    end

                    if (state == STATE_BEGIN_MODEL_UPLOAD) begin
                        current_model_idx <= cmd_in_data;
                    end
                end
            end
        end
    end
endmodule

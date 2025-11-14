import cmd_types_pkg::*;
import types_pkg::*;

// required for byte_t type - verilator does not recognize that it also
// comes through cmd_types_pkg
import types_pkg::*;

module CommandInput(
    input  logic clk,   
    input  logic rstn,

    // Command input
    input  logic  cmd_s_valid,
    output logic  cmd_s_ready,
    input  byte_t cmd_s_data,

    // Command response
    output logic  cmd_m_valid,
    input  logic  cmd_m_ready,
    output byte_t cmd_m_data,

    // ModelBuffer comms
    output logic             model_m_valid,
    input  logic             model_m_ready,
    output modelbuf_write_t  model_m_data,

    // SceneBuffer comms
    output logic                scene_m_valid,
    input  logic                scene_m_ready,
    output modelinstance_t      scene_m_data,
    output modelinstance_meta_t scene_m_metadata,

    // SceneBuffer camera transform comms
    output logic camera_m_valid,
    input  logic camera_m_ready,
    output transform_t camera_m_data,

    // Reset signal for the entire system
    output logic cmd_reset
);
    // The states we can be in
    typedef enum logic [2:0] {
        STATE_IDLE               = 3'd0,
        STATE_RESET              = 3'd1,
        STATE_BEGIN_MODEL_UPLOAD = 3'd2,
        STATE_UPLOAD_TRIANGLE    = 3'd3,
        STATE_ADD_MODELINSTANCE  = 3'd4,
        STATE_SET_CAMERA_TRANSFORM = 3'd5
    } state_t;

    // Commands we have implemented
    localparam byte_t CMD_RESET                = byte_t'(8'h55);
    localparam byte_t CMD_BEGIN_MODEL_UPLOAD   = byte_t'(8'hA0);
    localparam byte_t CMD_UPLOAD_TRIANGLE      = byte_t'(8'hA1);
    localparam byte_t CMD_ADD_MODEL_INSTANCE   = byte_t'(8'hB0);
    localparam byte_t CMD_SET_CAMERA_TRANSFORM = byte_t'(8'hC0);

    // Function that returns the length of the command in bytes
    function automatic byte_t command_length_bytes(byte_t cmd);
        case (cmd)
            CMD_RESET: return byte_t'(2);
            CMD_BEGIN_MODEL_UPLOAD: return byte_t'(2);
            CMD_UPLOAD_TRIANGLE: return byte_t'(1 + $bits(cmd_triangle_t) / 8);
            CMD_ADD_MODEL_INSTANCE: return byte_t'(1 + $bits(cmd_scene_t) / 8);
            CMD_SET_CAMERA_TRANSFORM: return byte_t'(1 + $bits(cmd_transform_t) / 8);
            default: return byte_t'(1);
        endcase
    endfunction

    // State machine state
    state_t state;
    byte_t bytes_left;
    byte_t current_cmd;
    wire cmd_s_transaction;
    assign cmd_s_transaction = cmd_s_valid && cmd_s_ready;

    // Signal to ensure that the parallelizers are
    // always in sync when we start receiving data.
    logic serial_to_parallel_synchronize;
    assign serial_to_parallel_synchronize = state == STATE_IDLE;

    // Serializing for model buffer
    byte_t current_model_idx;

    wire model_serial_s_valid;
    wire model_serial_s_ready;
    wire byte_t model_serial_s_data;
    wire cmd_triangle_t tmp_model_m_data;
    assign model_serial_s_valid = (state == STATE_UPLOAD_TRIANGLE) && cmd_s_transaction;
    assign model_serial_s_data = cmd_s_data;
    assign model_m_data.model_id = current_model_idx;
    assign model_m_data.triangle = cast_triangle(tmp_model_m_data);

    SerialToParallelStream #(
        .INPUT_SIZE($bits(byte_t)),
        .OUTPUT_SIZE($bits(cmd_triangle_t))
    ) triangle_serializer (
        .clk(clk),
        .rstn(rstn),
        .synchronize(serial_to_parallel_synchronize),
        .serial_s_ready(model_serial_s_ready),
        .serial_s_valid(model_serial_s_valid),
        .serial_s_data(model_serial_s_data),
        .parallel_m_ready(1),
        .parallel_m_valid(model_m_valid),
        .parallel_m_data(tmp_model_m_data)
    );

    // Serializing for scene buffer
    wire scene_serial_s_valid;
    wire scene_serial_s_ready;
    wire byte_t scene_serial_s_data;
    assign scene_serial_s_valid = (state == STATE_ADD_MODELINSTANCE) && cmd_s_transaction;
    assign scene_serial_s_data = cmd_s_data;

    wire cmd_scene_t scene_parallel_m_data;
    assign scene_m_data = cast_modelinstance(scene_parallel_m_data.modelinst);
    assign scene_m_metadata.last = scene_parallel_m_data.last;

    SerialToParallelStream #(
        .INPUT_SIZE($bits(byte_t)),
        .OUTPUT_SIZE($bits(cmd_scene_t))
    ) modelinstance_serializer (
        .clk(clk),
        .rstn(rstn),
        .synchronize(serial_to_parallel_synchronize),
        .serial_s_ready(scene_serial_s_ready),
        .serial_s_valid(scene_serial_s_valid),
        .serial_s_data(scene_serial_s_data),
        .parallel_m_ready(1),
        .parallel_m_valid(scene_m_valid),
        .parallel_m_data(scene_parallel_m_data)
    );

    
    // Serializer camera transform
    transform_t current_camera_transform;

    wire camera_serial_s_ready;
    wire camera_serial_s_valid;
    wire byte_t camera_serial_s_data;
    assign camera_serial_s_data = cmd_s_data;
    assign camera_serial_s_valid = (state == STATE_SET_CAMERA_TRANSFORM) && cmd_s_transaction;

    wire cmd_transform_t camera_parallel_m_data;

    assign camera_m_data = cast_transform(camera_parallel_m_data);

    SerialToParallelStream #(
        .INPUT_SIZE($bits(byte_t)),
        .OUTPUT_SIZE($bits(cmd_transform_t))
    ) cameratransform_serializer (
        .clk(clk),
        .rstn(rstn),
        .synchronize(serial_to_parallel_synchronize),
        .serial_s_ready(camera_serial_s_ready),
        .serial_s_valid(camera_serial_s_valid),
        .serial_s_data(camera_serial_s_data),
        .parallel_m_ready(1),
        .parallel_m_valid(camera_m_valid),
        .parallel_m_data(camera_parallel_m_data)
    );

    // For debugging send the received commands.
    assign cmd_m_valid = cmd_s_transaction;
    assign cmd_m_data  = cmd_s_data;

    // We set cmd_s_ready based on the state of the receiving element.
    // Some of them will always ready be ready, while some of them depend
    // on downstream logic.
    always_comb begin
        case (state)
            STATE_IDLE:                 cmd_s_ready = 1'b1;
            STATE_RESET:                cmd_s_ready = 1'b1;
            STATE_BEGIN_MODEL_UPLOAD:   cmd_s_ready = 1'b1; // accept model index byte
            STATE_UPLOAD_TRIANGLE:      cmd_s_ready = model_serial_s_ready; // accept triangle bytes when serializer ready
            STATE_ADD_MODELINSTANCE:    cmd_s_ready = scene_serial_s_ready; // accept modelinstance bytes when serializer ready
            STATE_SET_CAMERA_TRANSFORM: cmd_s_ready = camera_serial_s_ready; // Accept camera transform bytes when serializer ready
            default:                    cmd_s_ready = 1'b0;
        endcase
    end

    // State transitions and bytes_left management
    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            state <= STATE_IDLE;
            bytes_left <= 0;
            current_cmd <= 0;
            current_model_idx <= 0;
            cmd_reset <= 1'b0;
        end else begin
            if (cmd_s_transaction) begin
                // If we are currently IDLE and see a command byte, init the command transaction
                if (state == STATE_IDLE) begin
                    current_cmd <= cmd_s_data;
                    // Set number of bytes left in command
                    // Subtract one because we have already read one
                    bytes_left <= command_length_bytes(cmd_s_data) - 1;

                    // Choose next state based on command
                    case (cmd_s_data)
                        CMD_RESET: begin
                            state <= STATE_RESET;
                        end
                        CMD_BEGIN_MODEL_UPLOAD: begin 
                            state <= STATE_BEGIN_MODEL_UPLOAD;
                        end
                        CMD_UPLOAD_TRIANGLE: begin
                            state <= STATE_UPLOAD_TRIANGLE;
                        end
                        CMD_ADD_MODEL_INSTANCE: begin
                            state <= STATE_ADD_MODELINSTANCE;
                        end
                        CMD_SET_CAMERA_TRANSFORM: begin
                            state <= STATE_SET_CAMERA_TRANSFORM;
                        end
                        default: begin 
                            // Ignore. TODO: Send invalid response?
                        end
                    endcase

                end else begin
                    // Decrement bytes left for every byte we receive
                    if (bytes_left > 0) begin
                        bytes_left <= bytes_left - 1;
                    end

                    if (bytes_left <= 1) begin
                        state <= STATE_IDLE;
                    end

                    // Reset command needs to be repeated for reset to occur.
                    // Set cmd_reset only if second byte is also reset command.
                    if (state == STATE_RESET && cmd_s_data == CMD_RESET) begin
                        // The reset signal
                        cmd_reset <= 1'b1;
                    end

                    if (state == STATE_BEGIN_MODEL_UPLOAD) begin
                        current_model_idx <= cmd_s_data;
                    end
                end
            end
        end
    end
endmodule

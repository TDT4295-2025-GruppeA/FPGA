import types_pkg::*;

module ModelBuffer #(
    parameter MAX_MODEL_COUNT = 10,
    parameter MAX_TRIANGLE_COUNT = 100
)(
    input clk,
    input rstn,

    input logic write_in_valid,
    output logic write_in_ready,
    input modelbuf_write_t write_in_data,

    input logic read_in_valid,
    output logic read_in_ready,
    input modelbuf_read_t read_in_data,

    output logic read_out_valid,
    input logic read_out_ready,
    output triangle_t read_out_data,
    output triangle_meta_t read_out_metadata
);

    typedef enum logic [1:0] {
        STATE_EMPTY = 2'b00,
        STATE_WRITING = 2'b01,
        STATE_WRITTEN = 2'b10
    } state_t;

    typedef logic [$clog2(MAX_TRIANGLE_COUNT) - 1:0] triangle_idx_t;
    typedef logic [$clog2(MAX_MODEL_COUNT) - 1:0] model_idx_t;

    typedef struct packed {
        triangle_idx_t index;    // Index in the model buffer
        triangle_idx_t size;  // Number of triangles in the model
        logic [1:0] state;    // State of the model
    } model_index_t;

    wire model_idx_t write_model_idx;
    wire triangle_t write_triangle;
    wire logic write_en;
    assign write_model_idx = model_idx_t'(write_in_data.model_id);
    assign write_triangle = write_in_data.triangle;
    assign write_en = write_in_valid && write_in_ready;

    wire model_idx_t read_model_index;
    wire triangle_idx_t read_triangle_index;
    assign read_model_index = model_idx_t'(read_in_data.model_index);
    assign read_triangle_index = triangle_idx_t'(read_in_data.triangle_index);

    // Current index we are reading/writing from/to (model start addr + triangle_index)
    triangle_idx_t read_addr;
    triangle_idx_t write_addr;

    triangle_idx_t write_triangle_index;
    triangle_idx_t triangle_index;
    model_idx_t write_prev_model_index; // used to detect model change

    // Highest addr used in the buffer
    triangle_idx_t addr_next = 0;

    // This is a table keeping track of which models exist in the memory,
    // and their start index and size.
    model_index_t registry[MAX_MODEL_COUNT];

    // This is a buffer to store all triangles for all models.
    triangle_t model_buffer[MAX_TRIANGLE_COUNT];


    // Read from the registry
    always_comb begin
        read_addr = registry[read_model_index].index + read_triangle_index;
        write_in_ready = 1;
        read_in_ready = read_out_ready;

        if (write_model_idx != write_prev_model_index) begin
            write_triangle_index = 0;
        end else begin
            write_triangle_index = triangle_index + 1;
        end


        if (registry[write_model_idx].state == STATE_EMPTY) begin
            write_addr = addr_next;
        end else if (registry[write_model_idx].state == STATE_WRITING) begin
            write_addr = registry[write_model_idx].index + write_triangle_index;
        end else begin
            write_addr = 0;
            write_in_ready = 0; // Refuse to write to already written model
        end

        read_out_data = model_buffer[read_addr];
        read_out_valid = read_in_valid && read_in_ready;

        // Mark last triange in model
        if (read_triangle_index + 1 == registry[read_model_index].size) begin
            read_out_metadata.last = 1;
        end else begin
            read_out_metadata.last = 0;
        end
    end

    always_ff @(posedge clk or negedge rstn) begin
        // Mark model as written if we have started writing to another model
        // It is only allowed to write to a model once.
        if (write_en && write_in_ready && (write_model_idx != write_prev_model_index) && rstn) begin
            if (registry[write_prev_model_index].state == STATE_WRITING)
                registry[write_prev_model_index].state <= STATE_WRITTEN;
        end

        if (!rstn) begin // Reset control signals
            addr_next <= 0;
            write_prev_model_index <= -1;
            for (int i = 0; i < MAX_MODEL_COUNT; i++) begin
                registry[i].state = STATE_EMPTY;
                registry[i].size = 0;
                registry[i].index = 0;
            end
        end else if (write_en) begin
            // Write the triangle and update model states
            triangle_index <= write_triangle_index; // Update triangle index
            model_buffer[write_addr] <= write_triangle;
            registry[write_model_idx].size += 1;

            if (write_triangle_index == 0) begin
                registry[write_model_idx].index <= addr_next;
            end
            addr_next <= write_addr + 1;

            // Update state of the model we are writing to
            if (registry[write_model_idx].state == STATE_EMPTY) begin
                registry[write_model_idx].state <= STATE_WRITING;
            end

            write_prev_model_index <= write_model_idx;
        end
    end
endmodule
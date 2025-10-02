import fixed_pkg::*;

typedef struct packed {
    fixed coordinate;
    fixed coordinate2;
    fixed coordinate3;
    logic [11:0] color;
} triangle_t;

module ModelBuffer #(
    parameter MAX_MODEL_COUNT = 10,
    parameter MAX_TRIANGLE_COUNT = 100
)(
    input clk,
    input rstn,

    input logic write_en,
    input triangle_t write_triangle,
    input logic [$clog2(MAX_MODEL_COUNT) - 1:0] write_model_index,
    input logic [$clog2(MAX_TRIANGLE_COUNT) - 1:0] write_triangle_index,

    input logic [$clog2(MAX_MODEL_COUNT) - 1:0] read_model_index,
    input logic [$clog2(MAX_TRIANGLE_COUNT) - 1:0] read_triangle_index,

    output triangle_t read_triangle,
    output logic read_last_index,

    output logic buffer_full
);
    typedef enum logic [1:0] {
        STATE_EMPTY = 2'b00,
        STATE_WRITING = 2'b01,
        STATE_WRITTEN = 2'b10
    } state_t;

    typedef logic [$clog2(MAX_TRIANGLE_COUNT) - 1:0] triangle_idx_t;
    typedef logic [$clog2(MAX_MODEL_COUNT) - 1:0] model_idx_t;

    typedef struct packed {
        model_idx_t index; // Index in the model buffer
        triangle_idx_t size;     // Number of triangles in the model
        logic [1:0] state;
    } model_index_t;


    // Current index we are reading/writing from/to (model start addr + triangle_index)
    triangle_idx_t read_addr;
    triangle_idx_t write_addr;

    logic write_legal;
    triangle_idx_t write_prev_model_index; // used to detect model change

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
        write_legal = 1;


        if (registry[write_model_index].state == STATE_EMPTY) begin
            write_addr = addr_next;
        end else if (registry[write_model_index].state == STATE_WRITING) begin
            write_addr = registry[write_model_index].index + write_triangle_index;
        end else begin
            write_addr = 0;
            write_legal = 0; // Refuse to write to already written model
        end

        read_triangle = model_buffer[read_addr];

        // Mark last triange in model
        if (read_triangle_index + 1 == registry[read_model_index].size) begin
            read_last_index = 1;
        end else begin
            read_last_index = 0;
        end
    end

    always_ff @(posedge clk or negedge rstn) begin
        if (write_en && write_legal && (write_model_index != write_prev_model_index)) begin
            if (registry[write_prev_model_index].state == STATE_WRITING)
                registry[write_prev_model_index].state <= STATE_WRITTEN;
        end

        if (write_en && write_legal) begin
            model_buffer[write_addr] <= write_triangle;
            registry[write_model_index].size += 1;

            if (write_triangle_index == 0) begin
                registry[write_model_index].index <= addr_next;
            end
            addr_next <= write_addr + 1;

            if (registry[write_model_index].state == STATE_EMPTY) begin
                registry[write_model_index].state <= STATE_WRITING;
            end

            write_prev_model_index <= write_model_index;
        end
    end
endmodule
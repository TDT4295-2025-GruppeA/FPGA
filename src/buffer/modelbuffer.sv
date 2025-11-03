import types_pkg::*;

module ModelBuffer #(
    parameter MAX_MODEL_COUNT = 10,
    parameter MAX_TRIANGLE_COUNT = 512
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
    (* ram_style = "block" *) logic[71:0] model_buffer0[MAX_TRIANGLE_COUNT];
    (* ram_style = "block" *) logic[71:0] model_buffer1[MAX_TRIANGLE_COUNT];
    (* ram_style = "block" *) logic[71:0] model_buffer2[MAX_TRIANGLE_COUNT];
    (* ram_style = "block" *) logic[44:0] model_buffer3[MAX_TRIANGLE_COUNT];

    logic[71:0] read0;
    logic[71:0] read1;
    logic[71:0] read2;
    logic[44:0] read3;

    assign read_out_data[260:189] = read0;
    assign read_out_data[188:117] = read1;
    assign read_out_data[116:45] = read2;
    assign read_out_data[44:0] = read3;

    // Read from the registry
    always_comb begin
        read_addr = registry[read_model_index].index + read_triangle_index;
        write_in_ready = 1;
        read_in_ready = ~read_out_valid | read_out_ready;

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

    end

    always_ff @(posedge clk) begin
        if (write_en) begin
            model_buffer0[write_addr] <= write_triangle[260:189];
            model_buffer1[write_addr] <= write_triangle[188:117];
            model_buffer2[write_addr] <= write_triangle[116:45];
            model_buffer3[write_addr] <= write_triangle[44:0];
        end
        if (read_in_ready && read_in_valid) begin
            read0 <= model_buffer0[read_addr];
            read1 <= model_buffer1[read_addr];
            read2 <= model_buffer2[read_addr];
            read3 <= model_buffer3[read_addr];
        end
    end

    always_ff @(posedge clk or negedge rstn) begin
        // Mark model as written if we have started writing to another model
        // It is only allowed to write to a model once.

        if (!rstn) begin // Reset control signals
            addr_next <= 0;
            write_prev_model_index <= -1;
            read_out_valid <= 0;
            for (int i = 0; i < MAX_MODEL_COUNT; i++) begin
                registry[i].state = STATE_EMPTY;
                registry[i].size = 0;
                registry[i].index = 0;
            end
        end else begin
            if (write_en) begin
                if (write_in_ready && (write_model_idx != write_prev_model_index)) begin
                    if (registry[write_prev_model_index].state == STATE_WRITING)
                        registry[write_prev_model_index].state <= STATE_WRITTEN;
                end

                // Write the triangle and update model states
                triangle_index <= write_triangle_index; // Update triangle index
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

            if (read_out_valid && read_out_ready) begin
                read_out_valid <= 0; // Set low if we do not have more triangles
            end

            if (read_in_valid && read_in_ready) begin
                read_out_valid <= 1;
            end


            // Mark last triange in model
            if (read_triangle_index + 1 == registry[read_model_index].size) begin
                read_out_metadata.last <= 1;
            end else if (read_triangle_index >= registry[read_model_index].size) begin
                read_out_valid <= 0;
            end else begin
                read_out_metadata.last <= 0;
            end
        end

    end
endmodule
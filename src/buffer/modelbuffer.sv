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

    // Increment max triangle count by one to distinguish between full and empty.
    typedef logic [$clog2(MAX_TRIANGLE_COUNT + 1) - 1:0] triangle_idx_t;
    typedef logic [$clog2(MAX_MODEL_COUNT) - 1:0] model_idx_t;

    typedef struct packed {
        triangle_idx_t index;    // Index in the model buffer
        triangle_idx_t size;  // Number of triangles in the model
        logic [1:0] state;    // State of the model
    } model_index_t;

    // Write input data
    wire model_idx_t write_model_idx;
    wire triangle_t write_triangle;
    assign write_model_idx = model_idx_t'(write_in_data.model_id);
    assign write_triangle = write_in_data.triangle;

    // Writing happens to bram, so we can always accept data
    assign write_in_ready = 1;

    // Read input data
    wire model_idx_t read_model_index;
    wire triangle_idx_t read_triangle_index;
    assign read_model_index = model_idx_t'(read_in_data.model_index);
    assign read_triangle_index = triangle_idx_t'(read_in_data.triangle_index);

    // Current index we are reading/writing from/to (model start addr + triangle_index)
    triangle_idx_t read_addr;
    triangle_idx_t write_addr;

    triangle_idx_t write_triangle_index;
    triangle_idx_t previous_write_triangle_index;
    model_idx_t write_prev_model_index; // used to detect model change

    // Highest addr used in the buffer
    triangle_idx_t addr_next;

    // This is a table keeping track of which models exist in the memory,
    // and their start index and size.
    model_index_t registry[MAX_MODEL_COUNT];

    logic full;
    assign full = (addr_next == triangle_idx_t'(MAX_TRIANGLE_COUNT));

    logic write_en;

    // Read from the registry
    always_comb begin
        read_addr = registry[read_model_index].index + read_triangle_index;
        write_en = write_in_valid && write_in_ready && ~full;
        read_in_ready = ~read_out_valid | read_out_ready;

        if (write_model_idx != write_prev_model_index) begin
            write_triangle_index = 0;
        end else begin
            write_triangle_index = previous_write_triangle_index + 1;
        end


        if (registry[write_model_idx].state == STATE_EMPTY) begin
            write_addr = addr_next;
        end else if (registry[write_model_idx].state == STATE_WRITING) begin
            write_addr = registry[write_model_idx].index + write_triangle_index;
        end else begin
            write_addr = 0;
            write_en = 0; // Refuse to write to already written model
        end

    end

    Bram #(
        .ENTRY_COUNT(MAX_TRIANGLE_COUNT + 1),
        .DATA_WIDTH($bits(triangle_t))
    ) bram (
        .clk(clk),
        
        .write_enable(write_en),
        .write_address(write_addr),
        .write_data(write_triangle),

        .read_enable(read_in_ready && read_in_valid),
        .read_address(read_addr),
        .read_data(read_out_data)
    );

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
            read_out_metadata.last <= 0;
        end else begin
            if (write_en) begin
                if (write_model_idx != write_prev_model_index) begin
                    if (registry[write_prev_model_index].state == STATE_WRITING)
                        registry[write_prev_model_index].state <= STATE_WRITTEN;
                end

                // Write the triangle and update model states
                previous_write_triangle_index <= write_triangle_index; // Update triangle index
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
                // Only set output valid high if triangle index is within size
                read_out_valid <= read_triangle_index < registry[read_model_index].size;
                // Mark triangle as last
                read_out_metadata.last <= read_triangle_index + 1 >= registry[read_model_index].size;
            end
        end

    end
endmodule
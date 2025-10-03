// SRAM Controller states
// IDLE: Not doing anything
// WRITE: Currently writing to SRAM
// READ: Currently reading from SRAM
typedef enum logic [1:0] {
    IDLE,
    WRITE,
    READ
} sram_state;

module SramController #(
    parameter int ADDRESS_WIDTH = 5,
    parameter int DATA_WIDTH = 8
) (
    input logic clk,
    input logic rstn,

    // SRAM Interface
    inout logic [DATA_WIDTH-1:0] sram_data,
    output logic [ADDRESS_WIDTH-1:0] sram_address,
    output logic sram_write_en_n,

    // User Interface
    input logic write_en,
    input logic read_en,
    input logic [ADDRESS_WIDTH-1:0] address,
    input logic [DATA_WIDTH-1:0] write_data,
    output logic [DATA_WIDTH-1:0] read_data,
    output logic ready
);
    // How many steps a full transaction takes.
    localparam int TRANSACTION_CYCLE_COUNT = 6;

    // For WRITE:
    // When write enable should be actiavted.
    localparam int WRITE_ENABLE_CYCLE = 0;
    // When data should be set up on the bus.
    // IMPORTANT: This must be a at least 20 ns after
    // write enable is activated to avoid short circuiting!
    localparam int DATA_SETUP_CYCLE = 2;
    // When write enable should be deactivated.
    localparam int WRITE_DISABLE_CYCLE = 5;
    // When to release the bus.
    localparam int DATA_RELEASE_CYCLE = 5;

    // For READ:
    localparam int READ_SAMPLE_CYCLE = 3;

    typedef logic [$clog2(TRANSACTION_CYCLE_COUNT)-1:0] transaction_cycle;

    // Which step of the transaction we are currently on.
    transaction_cycle transaction_counter;
    // Which state the controlelr is in.
    sram_state state;
    // Register to hold data.
    logic [DATA_WIDTH-1:0] data_buffer;
    // Register to hold address.
    logic [ADDRESS_WIDTH-1:0] address_buffer;

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            transaction_counter <= 0;
            state <= IDLE;
            data_buffer <= 0;
            address_buffer <= 0;
        end else begin
            // Increment transaction counter.
            if (transaction_counter == transaction_cycle'(TRANSACTION_CYCLE_COUNT - 1)) begin
                transaction_counter <= 0;

                // Select next state based on user input.
                if (read_en) begin
                    state <= READ;
                    address_buffer <= address;
                end else if (write_en) begin
                    state <= WRITE;
                    data_buffer <= write_data;
                    address_buffer <= address;
                end else begin
                    state <= IDLE;
                end
            end else begin
                transaction_counter <= transaction_counter + 1;
            end

            // Sample data from SRAM during READ.
            if (state == READ && transaction_counter == READ_SAMPLE_CYCLE) begin
                data_buffer <= sram_data;
            end
        end
    end

    assign ready = state == IDLE;
    assign read_data = data_buffer;

    assign sram_address = address_buffer;
    assign sram_write_en_n = ~(state == WRITE && transaction_counter >= WRITE_ENABLE_CYCLE && transaction_counter < WRITE_DISABLE_CYCLE);
    assign sram_data = (state == WRITE && !sram_write_en_n && transaction_counter >= DATA_SETUP_CYCLE && transaction_counter < DATA_RELEASE_CYCLE) ? data_buffer : 'bz;
endmodule
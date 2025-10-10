// Async FIFO is a FIFO queue for crossing clock domains.
// `WIDTH` is the data witdth in bits.
// `MIN_LENGTH` is the minimum number of entries the FIFO should have.
// The actual length is the next power of two greater than `MIN_LENGTH`.
module AsyncFifo #(
    parameter int WIDTH = 8,
    parameter int MIN_LENGTH = 8
) (
    input logic rstn,

    input logic write_clk,
    input logic read_clk,
    
    input logic write_en,
    input logic read_en,

    output logic write_ready,
    output logic read_ready,

    output logic full,
    output logic empty,

    input logic [WIDTH-1:0] data_in,
    output logic [WIDTH-1:0] data_out
);
    // Add one to MIN_LENGTH to have one slot free to distinguish full and empty.
    localparam ADDRESS_WIDTH = $clog2(MIN_LENGTH + 1);
    localparam LENGTH = 1 << ADDRESS_WIDTH;

    logic [WIDTH-1:0] fifo [LENGTH];

    logic [ADDRESS_WIDTH-1:0] write_ptr, read_ptr;
    logic [ADDRESS_WIDTH-1:0] write_ptr_synced, read_ptr_synced;

    PointerSynchronizer #(
        .WIDTH(ADDRESS_WIDTH)
    ) write_synchronizer (
        .clk_dest(read_clk),
        .rstn(rstn),
        .data_in(write_ptr),
        .data_out(write_ptr_synced)
    );

    PointerSynchronizer #(
        .WIDTH(ADDRESS_WIDTH)
    ) read_synchronizer (
        .clk_dest(write_clk),
        .rstn(rstn),
        .data_in(read_ptr),
        .data_out(read_ptr_synced)
    );

    // Calculate full and empty flags.
    // Note that we have to use the respective synchronized pointers here.
    // We also add one to the write pointer to differentiate full from empty.
    // This means that the FIFO can never be completely full.
    assign full = (ADDRESS_WIDTH)'(write_ptr + 1) == read_ptr_synced;
    assign empty = read_ptr == write_ptr_synced;

    // Helper signals to indicate if we can write or read.
    assign write_ready = !full;
    assign read_ready = !empty;

    /////////////////
    // Write Logic //
    /////////////////

    always_ff @(posedge write_clk or negedge rstn) begin
        if (!rstn) begin
            write_ptr <= 0;
        end else if (write_en && write_ready) begin
            // Write data to the current write pointer,
            // but only if there is space available.
            fifo[write_ptr] <= data_in;
            // Overflow is intentional.
            write_ptr <= write_ptr + 1;
        end
    end

    ////////////////
    // Read Logic //
    ////////////////

    // Data output is always the current read pointer location.
    assign data_out = fifo[read_ptr];

    always_ff @(posedge read_clk or negedge rstn) begin
        if (!rstn) begin
            read_ptr <= 0;
        end else if (read_en && read_ready) begin
            // Increment when reading, but
            // only when data is available.
            // Overflow is intentional.
            read_ptr <= read_ptr + 1;
        end
    end
endmodule

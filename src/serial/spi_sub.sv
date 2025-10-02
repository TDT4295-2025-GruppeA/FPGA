// We avoid using the terms "Master" and "Slave" to be politically correct.
// Instead, we use "Main" and "Sub".

// This module implements a SPI Sub interface.
// It crosses clock domains between the system clock and main SPI clock
// using asynchronous FIFOs for both transmit and receive data.
module SpiSub #(
    parameter int WORD_SIZE = 8,
    parameter int RX_QUEUE_LENGTH = 8,
    parameter int TX_QUEUE_LENGTH = 8
) (
    // SPI interface
    input logic sclk,
    input logic ssn,
    input logic mosi,
    output logic miso,

    // System interface
    input logic sys_clk,
    input logic sys_rstn,

    // User data interface
    input logic tx_data_en, // Set high when word in tx_data is ready to send.
    input logic rx_data_en, // Set high when ready to read one word, rx_data will have word on next cycle.
    input logic [WORD_SIZE-1:0] tx_data, // Word to send.
    output logic [WORD_SIZE-1:0] rx_data, // Word to receive.
    output logic tx_ready, // High when ready to accept new data to send.
    output logic rx_ready, // High when data has been received and is ready to read.
    output logic active // High as long as a transfer is ongoing.
);
    // Reset should happen when either master is
    // not selecting us or a system reset occurs.
    logic rstn;
    assign rstn = ~ssn && sys_rstn;

    // Transaction is active as long as we are selected.
    assign active = ~ssn;

    // Handy dandy type to avoid repeating $clog2(WORD_SIZE).
    typedef logic [$clog2(WORD_SIZE):0] bit_counter;

    // Registers to keep track of which bit we are on.
    // NOTE: We have one extra bit to indicate no data received yet.
    bit_counter bit_count;

    // Count which bit of the current word we are on.
    always_ff @(posedge sclk or negedge rstn) begin
        if (!rstn) begin
            bit_count <= bit_counter'(WORD_SIZE); // Indicate no data received yet.
        end else if (bit_count == 0) begin
            bit_count <= bit_counter'(WORD_SIZE - 1);
        end else begin
            bit_count <= bit_count - 1;
        end
    end

    //////////////
    // RX Logic //
    //////////////

    // Buffer to hold the data between popping 
    // from FIFO and loading into shift register.
    logic [WORD_SIZE-1:0] rx_buffer;

    // Data is ready when an entire word has been received.
    logic data_ready;
    assign data_ready = bit_count == 0;

    // TODO: Since the shift register adds one clock cycle of delay,
    // we need one extra clock cycle to read the last word. 
    // This should probably be fixed in a cleaner way.

    ShiftRegister #(
        .SIZE(WORD_SIZE)
    ) rx_shift_register (
        .clk(sclk),
        .rstn(rstn),
        .serial_in(mosi),
        .serial_out(), // Ignored. Not Used.
        .parallel_in_en(1'b0), // Never loading in parallel.
        .parallel_in(), // Ignored. Not used.
        .parallel_out(rx_buffer)
    );

    // Wire to invert empty signal from FIFO.
    logic rx_queue_empty;
    assign rx_ready = !rx_queue_empty;

    AsyncFifo #(
        .WIDTH(WORD_SIZE),
        .MIN_LENGTH(RX_QUEUE_LENGTH)
    ) rx_queue (
        // Use system reset to be able to read data after transaction.
        .rstn(sys_rstn),

        .write_clk(sclk),
        .write_en(data_ready),
        .data_in(rx_buffer),

        .read_clk(sys_clk),
        .read_en(rx_data_en),
        .data_out(rx_data),

        .empty(rx_queue_empty),
        .full() // Ignored. User error if ever full. :P
    );

    //////////////
    // TX Logic //
    //////////////

    // Buffer to hold the data between popping 
    // from FIFO and loading into shift register.
    logic [WORD_SIZE-1:0] tx_buffer;

    // We load new TX data a few clocks before we need it.
    logic pop_new_tx, load_new_tx;
    assign pop_new_tx = bit_count == 3;
    assign load_new_tx = bit_count == 2;
    
    ShiftRegister #(
        .SIZE(WORD_SIZE)
    ) tx_shift_register (
        .clk(sclk),
        .rstn(rstn),
        .serial_in(), // Ignored. Not used.
        .parallel_out(), // Ignored. Not used.
        .parallel_in_en(load_new_tx),
        .parallel_in(tx_buffer),
        .serial_out(miso)
    );

    // Wire to invert full signal from FIFO.
    logic tx_queue_full;
    assign tx_ready = !tx_queue_full;

    AsyncFifo #(
        .WIDTH(WORD_SIZE),
        .MIN_LENGTH(TX_QUEUE_LENGTH)
    ) tx_queue (
        .rstn(rstn),

        .read_clk(sclk),
        .read_en(pop_new_tx),
        .data_out(tx_buffer),

        .write_clk(sys_clk),
        .write_en(tx_data_en),
        .data_in(tx_data),

        .empty(), // Ignored. Not necessary.
        .full(tx_queue_full)
    );
endmodule

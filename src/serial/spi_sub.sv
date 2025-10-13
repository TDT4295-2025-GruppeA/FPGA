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
    input logic rx_data_en, // Set high when word in rx_data has been read.
    input logic [WORD_SIZE-1:0] tx_data, // Word to send.
    output logic [WORD_SIZE-1:0] rx_data, // Word to receive.
    output logic tx_ready, // High when ready to accept new data to send.
    output logic rx_ready, // High when data has been received. (rx_data is valid)
    output logic active // High as long as a transaction is ongoing. (SSN is low)
);
    // Reset should happen when either master is
    // not selecting us or a system reset occurs.
    logic rstn;
    assign rstn = ~ssn && sys_rstn;

    // Transaction is active as long as we are selected.
    assign active = ~ssn;

    //////////////
    // RX Logic //
    //////////////

    // Buffer which holds the currently received data.
    logic [WORD_SIZE-1:0] rx_buffer;
    // Flag for when an entire word has been recevied.
    logic rx_buffer_ready;

    // TODO: Since the shift register adds one clock cycle of delay,
    // we need one extra clock cycle to read the last word. 
    // This should probably be fixed in a cleaner way.

    SerialToParallel #(
        .INPUT_SIZE(1),
        .OUTPUT_SIZE(WORD_SIZE)
    ) rx_shift_register (
        .clk(sclk),
        .rstn(rstn),
        .serial(mosi),
        .serial_valid(1),
        .parallel_ready(rx_buffer_ready),
        .parallel(rx_buffer)
    );

    AsyncFifo #(
        .WIDTH(WORD_SIZE),
        .MIN_LENGTH(RX_QUEUE_LENGTH)
    ) rx_queue (
        // Use system reset to be able to read data after transaction.
        .rstn(sys_rstn),

        .write_clk(sclk),
        .write_en(rx_buffer_ready),
        .data_in(rx_buffer),

        .read_clk(sys_clk),
        .read_en(rx_data_en),
        .data_out(rx_data),

        .read_ready(rx_ready),

        // Ignored.
        .empty(),
        .full(), // User error if ever full. :P
        .write_ready()
    );

    //////////////
    // TX Logic //
    //////////////

    // Buffer to hold the data between popping 
    // from FIFO and loading into shift register.
    logic [WORD_SIZE-1:0] tx_buffer;

    ParallelToSerial #(
        .SIZE(WORD_SIZE)
    ) tx_shift_register (
        .clk(~sclk), // We setup data on falling edge of SCLK.
        .rstn(rstn),
        .parallel_ready(rx_buffer_ready),
        .parallel(tx_buffer),
        .serial(miso)
    );

    AsyncFifo #(
        .WIDTH(WORD_SIZE),
        .MIN_LENGTH(TX_QUEUE_LENGTH)
    ) tx_queue (
        .rstn(rstn),

        .read_clk(~sclk), // We setup data on falling edge of SCLK.
        .read_en(rx_buffer_ready),
        .data_out(tx_buffer),

        .write_clk(sys_clk),
        .write_en(tx_data_en),
        .data_in(tx_data),

        .write_ready(tx_ready),

        // Ignored.
        .empty(),
        .full(),
        .read_ready()
    );
endmodule

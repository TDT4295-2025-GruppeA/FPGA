// A shift register which takes in serial data, shifts and stores it internally, and outputs it in parallel.
module SerialToParallel #(
    parameter int SIZE = 8  
) (
    input logic clk,
    input logic rstn,
    
    input logic serial,

    output logic parallel_ready,
    output logic [SIZE-1:0] parallel
);
    // Buffer to hold the data which is being shifted in.
    logic [SIZE-1:0] buffer;

    // Counter type to avoid repeating "$clog2(SIZE)".
    typedef logic [$clog2(SIZE):0] bit_counter;
    // Counter to keep track of how many bits have been shifted in.
    // Needs one extra bit to differentiate between no data received yet and a full buffer.
    bit_counter bit_count;

    // Assign the parallel output to the buffer.
    assign parallel = buffer;
    // Parallel data is ready when we've shifted in SIZE bits.
    assign parallel_ready = (bit_count == bit_counter'(SIZE));

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            buffer <= '0;
            bit_count <= 0;
        end else begin
            // Read in the serial data by shifting left and adding the new bit at LSB.
            buffer <= { buffer[SIZE-2:0], serial };

            if (bit_count == bit_counter'(SIZE)) begin
                // Start new count after full buffer.
                // We start at 1 because we've just read in one bit.
                bit_count <= 1;
            end else begin
                // Increment the bit count.
                bit_count <= bit_count + 1;
            end
        end
    end
endmodule

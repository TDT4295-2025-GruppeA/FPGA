// A shift register which takes in serial data, shifts and stores it internally, and outputs it in parallel.
// OUTPUT_SIZE must be divisible by INPUT_SIZE
module SerialToParallel #(
    parameter int INPUT_SIZE = 1,
    parameter int OUTPUT_SIZE = 8  
) (
    input logic clk,
    input logic rstn,
    
    input logic [INPUT_SIZE-1:0] serial,
    input logic serial_valid,

    output logic parallel_ready,
    output logic [OUTPUT_SIZE-1:0] parallel
);
    if (OUTPUT_SIZE % INPUT_SIZE != 0) begin
        $error("Parameter OUTPUT_SIZE `%0d` must be divisible by INPUT_SIZE `%0d`.", OUTPUT_SIZE, INPUT_SIZE);
    end

    localparam ELEMENT_COUNT = OUTPUT_SIZE / INPUT_SIZE;

    // Buffer to hold the data which is being shifted in.
    logic [OUTPUT_SIZE-1:0] buffer;

    // Counter type to avoid repeating "$clog2(OUTPUT_SIZE)".
    typedef logic [$clog2(ELEMENT_COUNT):0] element_count_t;

    // Counter to keep track of how many elements have been shifted in.
    // Needs one extra bit to differentiate between no data received yet and a full buffer.
    element_count_t element_count;

    // Assign the parallel output to the buffer.
    assign parallel = buffer;
    // Parallel data is ready when we've shifted in OUTPUT_SIZE bits.
    assign parallel_ready = (element_count == element_count_t'(ELEMENT_COUNT));

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            buffer <= '0;
            element_count <= 0;
        end else begin
            if (serial_valid) begin
                // Read in the serial data by shifting left and adding the new bit at LSB.
                buffer <= { buffer[OUTPUT_SIZE - INPUT_SIZE - 1:0], serial };

                if (element_count == element_count_t'(ELEMENT_COUNT)) begin
                    // Start new count after full buffer.
                    // We start at 1 because we've just read in one bit.
                    element_count <= 1;
                end else begin
                    // Increment the element count
                    element_count <= element_count + 1;
                end
            end else begin
                if (element_count == element_count_t'(ELEMENT_COUNT)) begin
                    // Set element count back to 0 so we stop giving out
                    // parallel_ready, and prepare for next data element.
                    element_count <= 0;
                end
            end
        end
    end
endmodule

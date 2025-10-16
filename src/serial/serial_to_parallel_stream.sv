// A shift register which takes in serial data, shifts and stores it internally, and outputs it in parallel.
// OUTPUT_SIZE must be divisible by INPUT_SIZE

// A SerialToParallel module with support for ready-valid handshake.
// In its own module for now we don't break dependencies to spi's use case
module SerialToParallelStream #(
    parameter int INPUT_SIZE  = 1,
    parameter int OUTPUT_SIZE = 8
) (
    input  logic clk,
    input  logic rstn,

    // Serial input stream
    output logic                   serial_in_ready,
    input  logic                   serial_in_valid,
    input  logic [INPUT_SIZE-1:0]  serial_in_data,

    // Parallel output stream
    input  logic                   parallel_out_ready,
    output logic                   parallel_out_valid,
    output logic [OUTPUT_SIZE-1:0] parallel_out_data
);
    // Check parameter relation
    if (OUTPUT_SIZE % INPUT_SIZE != 0) begin
        $error("OUTPUT_SIZE (%0d) must be divisible by INPUT_SIZE (%0d).",
               OUTPUT_SIZE, INPUT_SIZE);
    end

    localparam int ELEMENT_COUNT = OUTPUT_SIZE / INPUT_SIZE;

    typedef logic [$clog2(ELEMENT_COUNT)+1:0] element_count_t;

    logic [OUTPUT_SIZE-1:0] buffer;
    element_count_t element_count;

    assign parallel_out_data = buffer;

    // Parallel output valid when full
    assign parallel_out_valid = (element_count == element_count_t'(ELEMENT_COUNT));

    // Accept new serial data only if not full OR it will become ready next cycle
    assign serial_in_ready = !parallel_out_valid || (parallel_out_valid && parallel_out_ready);

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            buffer        <= '0;
            element_count <= 0;
        end else begin
            // Accept serial data
            if (serial_in_valid && serial_in_ready) begin
                buffer <= {buffer[OUTPUT_SIZE-INPUT_SIZE-1:0], serial_in_data};
                
                if (element_count == element_count_t'(ELEMENT_COUNT) - 1) begin
                    element_count <= element_count_t'(ELEMENT_COUNT);
                end else begin
                    element_count <= element_count + 1;
                end
            end

            // Output ready
            if (parallel_out_valid && parallel_out_ready) begin
                element_count <= 0;
                if (serial_in_valid && serial_in_ready) begin
                    element_count <= 1;
                end
            end
        end
    end
endmodule

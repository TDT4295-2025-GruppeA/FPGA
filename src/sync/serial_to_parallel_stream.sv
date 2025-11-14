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

    // Synchronization signal to reset internal counter
    input logic synchronize,

    // Serial input stream
    output logic                   serial_s_ready,
    input  logic                   serial_s_valid,
    input  logic [INPUT_SIZE-1:0]  serial_s_data,

    // Parallel output stream
    input  logic                   parallel_m_ready,
    output logic                   parallel_m_valid,
    output logic [OUTPUT_SIZE-1:0] parallel_m_data
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

    assign parallel_m_data = buffer;

    // Parallel output valid when full
    assign parallel_m_valid = (element_count == element_count_t'(ELEMENT_COUNT));

    // Accept new serial data only if not full OR it will become ready next cycle
    assign serial_s_ready = !parallel_m_valid || (parallel_m_valid && parallel_m_ready);

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            buffer        <= '0;
            element_count <= 0;
        end else begin
            // Accept serial data
            if (serial_s_valid && serial_s_ready) begin
                buffer <= {buffer[OUTPUT_SIZE-INPUT_SIZE-1:0], serial_s_data};
                // This won't overflow because serial_s_ready
                // is low until element counter is reset.
                element_count <= element_count + 1;
            end

            // Reset element counter on output accept or synchronize signal
            // If parallel output is valid we ignore the synchronize signal
            // as the next serial input will be the first element anyway
            if (parallel_m_valid && parallel_m_ready || synchronize && !parallel_m_valid) begin
                if (serial_s_valid && serial_s_ready) begin
                    // Reset to 1 if we accept new data immediately.
                    element_count <= 1;
                end else begin
                    // Reset to 0 otherwise.
                    element_count <= 0;
                end
            end 
        end
    end
endmodule

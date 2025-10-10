// A shift register which takes in parallel data and shifts it out serially.
module ParallelToSerial #(
    parameter int SIZE = 8  
) (
    input logic clk,
    input logic rstn,
    
    output logic serial,

    input logic parallel_ready,
    input logic [SIZE-1:0] parallel
);
    // Buffer to hold the data which is being shifted out.
    logic [SIZE-1:0] buffer;

    // Assign the serial output to the MSB of the buffer.
    assign serial = buffer[SIZE-1];

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            buffer <= '0;
        end else begin
            if (parallel_ready) begin
                // If parallel input is ready, load the parallel data.
                buffer <= parallel;
            end else begin
                // Otherwise, shift the register to the left.
                buffer <= { buffer[SIZE-2:0], 1'b0 };
            end
        end
    end
endmodule

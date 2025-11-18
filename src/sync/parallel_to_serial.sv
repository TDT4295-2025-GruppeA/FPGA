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
    logic [SIZE-1:0] buffer, buffer_next;
    assign buffer_next = parallel_ready ? parallel : { buffer[SIZE-2:0], 1'b0 };

    // Assign the serial output to the MSB of the buffer.
    assign serial = buffer_next[SIZE-1];

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            buffer <= '0;
        end else begin
            buffer <= buffer_next;
        end
    end
endmodule

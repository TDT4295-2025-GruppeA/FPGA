// A simple bidirectional shift register module.
// It can be used to convert between serial and parallel data.
module ShiftRegister #(
    parameter int SIZE = 8  
) (
    input logic clk,
    input logic rstn,
    
    input logic serial_in,
    output logic serial_out,

    input logic parallel_in_en,
    input logic [SIZE-1:0] parallel_in,
    output logic [SIZE-1:0] parallel_out
);
    logic [SIZE-1:0] buffer, next_buffer;

    assign next_buffer = parallel_in_en ? parallel_in : { buffer[SIZE-2:0], serial_in };

    assign serial_out = buffer[SIZE-1];
    assign parallel_out = buffer;

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            buffer <= '0;
        end else begin
            buffer <= next_buffer;
        end
    end
endmodule

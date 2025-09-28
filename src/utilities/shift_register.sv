module ShiftRegister #(
    parameter int SIZE = 8  
) (
    input logic clk,
    input logic rstn,
    input logic data_in,
    output logic data_out,
    output logic [SIZE-1:0] buffer
);
    assign data_out = buffer[SIZE-1];

    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            buffer <= '0;
        end else begin
            buffer <= {buffer[SIZE-2:0], data_in};
        end
    end
endmodule

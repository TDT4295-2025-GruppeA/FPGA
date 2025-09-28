module PointerSynchronizer #(
    parameter int WIDTH = 8
) (
    input logic clk_dest,
    input logic rstn,
    input logic [WIDTH-1:0] data_in,
    output logic [WIDTH-1:0] data_out
);
    logic [WIDTH-1:0] gray_data;

    BinaryToGray #(
        .WIDTH(WIDTH)
    ) binary_to_gray (
        .binary(data_in),
        .gray(gray_data)
    );

    // Mark registers as crossing clock domains.
    // Docs: https://docs.amd.com/r/en-US/ug912-vivado-properties/ASYNC_REG
    (* ASYNC_REG = "TRUE" *) logic [WIDTH-1:0] sync1, sync2;

    always_ff @(posedge clk_dest or negedge rstn) begin
        if (!rstn) begin
            sync1 <= '0;
            sync2 <= '0;
        end else begin
            sync1 <= gray_data;
            sync2 <= sync1;
        end
    end

    GrayToBinary #(
        .WIDTH(WIDTH)
    ) gray_to_binary (
        .gray(sync2),
        .binary(data_out)
    );
endmodule

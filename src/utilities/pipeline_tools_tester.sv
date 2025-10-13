// Module to help test the PipelineToolsTester testing tool
// Just simulates a ready-valid handshake, and forwards the input to
// the output.
module PipelineToolsTester #(
    parameter int WIDTH = 8,
    parameter int METADATA_WIDTH = 4
)(
    input  logic clk,
    input  logic rstn,

    // Input interface
    input  logic                       stage_in_valid,
    output logic                       stage_in_ready,
    input  logic [WIDTH-1:0]           stage_in_data,
    input  logic [METADATA_WIDTH-1:0]  stage_in_metadata,

    // Output interface
    output logic                       stage_out_valid,
    input  logic                       stage_out_ready,
    output logic [WIDTH-1:0]           stage_out_data,
    output logic [METADATA_WIDTH-1:0]  stage_out_metadata
);

    // Latch input when valid & ready
    logic [WIDTH-1:0] data;
    logic [METADATA_WIDTH-1:0] metadata;
    logic valid;

    assign stage_in_ready = ~valid | stage_out_ready;
    assign stage_out_valid = valid;
    assign stage_out_data = data;
    assign stage_out_metadata = metadata;


    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            data <= '0;
            metadata <= '0;
            valid <= 0;
        end else begin
            if (stage_in_valid && stage_in_ready) begin
                data <= stage_in_data;
                metadata <= stage_in_metadata;
                valid <= 1;
            end

            if (stage_out_valid && stage_out_ready) begin
                valid <= 0;
            end
        end
    end

endmodule

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
    input  logic                       stage_s_valid,
    output logic                       stage_s_ready,
    input  logic [WIDTH-1:0]           stage_s_data,
    input  logic [METADATA_WIDTH-1:0]  stage_s_metadata,

    // Output interface
    output logic                       stage_m_valid,
    input  logic                       stage_m_ready,
    output logic [WIDTH-1:0]           stage_m_data,
    output logic [METADATA_WIDTH-1:0]  stage_m_metadata
);

    // Latch input when valid & ready
    logic [WIDTH-1:0] data;
    logic [METADATA_WIDTH-1:0] metadata;
    logic valid;

    assign stage_s_ready = ~valid | stage_m_ready;
    assign stage_m_valid = valid;
    assign stage_m_data = data;
    assign stage_m_metadata = metadata;


    always_ff @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            data <= '0;
            metadata <= '0;
            valid <= 0;
        end else begin
            if (stage_m_valid && stage_m_ready) begin
                valid <= 0; // data is no longer valid
            end

            if (stage_s_valid && stage_s_ready) begin
                data <= stage_s_data;
                metadata <= stage_s_metadata;
                valid <= 1;
            end
        end
    end

endmodule

// Inspired by https://docs.amd.com/r/en-US/ug906-vivado-design-analysis/Single-Bit-Synchronizer
module SingleBitSync (
        input  logic clk_dst,
        input  logic rst_dst_n,
        input  logic data_in_src,
        output logic data_out_dst
    );

        (* ASYNC_REG = "TRUE" *) logic sync_ff1, sync_ff2; 

        always_ff @(posedge clk_dst or negedge rst_dst_n) begin
            if (!rst_dst_n) begin
                sync_ff1 <= 1'b0;
                sync_ff2 <= 1'b0;
            end else begin
                sync_ff1 <= data_in_src;
                sync_ff2 <= sync_ff1;
            end
        end

        assign data_out_dst = sync_ff2;

    endmodule
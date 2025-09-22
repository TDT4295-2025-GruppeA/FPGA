module PulseSync (
    input  logic clk_src,
    input  logic rst_src_n,
    input  logic pulse_in_src,
    
    input  logic clk_dst,
    input  logic rst_dst_n,
    output logic pulse_out_dst
);

    logic level_src;
    always_ff @(posedge clk_src or negedge rst_src_n) begin
        if (!rst_src_n) begin
            level_src <= 1'b0;
        end else begin
            if (pulse_in_src) begin
                level_src <= ~level_src;
            end
        end
    end

    logic level_dst;
    SingleBitSync level_sync_inst (
        .clk_dst(clk_dst),
        .rst_dst_n(rst_dst_n),
        .data_in_src(level_src),
        .data_out_dst(level_dst)
    );
    
    logic level_dst_d;
    always_ff @(posedge clk_dst or negedge rst_dst_n) begin
        if (!rst_dst_n) begin
            level_dst_d <= 1'b0;
        end else begin
            level_dst_d <= level_dst;
        end
    end
    
    assign pulse_out_dst = level_dst ^ level_dst_d;

endmodule
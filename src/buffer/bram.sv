module Bram #(
    parameter int ENTRY_COUNT = 1024,
    parameter int DATA_WIDTH  = 32,
    parameter int BLOCK_WIDTH = -1
) (
    // System ports
    input logic clk,

    // TODO: Use handshake for read and write.

    // Write ports
    input logic write_enable,
    input logic [$clog2(ENTRY_COUNT)-1:0] write_address,
    input logic [DATA_WIDTH-1:0] write_data,

    // Read ports
    input logic read_enable,
    input logic [$clog2(ENTRY_COUNT)-1:0] read_address,
    output logic [DATA_WIDTH-1:0] read_data
);
    // Use the data width as the block width if no block width is specified.
    localparam int MAX_DATA_WIDTH = (BLOCK_WIDTH > 0) ? BLOCK_WIDTH : DATA_WIDTH;

    // Calculate how many blocks we'll need.
    localparam int BLOCK_COUNT = (DATA_WIDTH + MAX_DATA_WIDTH - 1) / MAX_DATA_WIDTH;
    localparam int LAST_WIDTH = DATA_WIDTH - (BLOCK_COUNT - 1) * MAX_DATA_WIDTH;

    // Generate one BRAM per block.

    // First N-1 full blocks.
    genvar i;
    generate
        for (i = 0; i < BLOCK_COUNT-1; i=i+1) begin
            (* ram_style = "block" *) logic [MAX_DATA_WIDTH-1:0] mem [0:ENTRY_COUNT-1];
            logic [MAX_DATA_WIDTH-1:0] data_reg;

            always_ff @(posedge clk) begin
                if (write_enable)
                    mem[write_address] <= write_data[(DATA_WIDTH-1)-(i*MAX_DATA_WIDTH) -: MAX_DATA_WIDTH];
                if (read_enable)
                    data_reg <= mem[read_address];
            end

            assign read_data[(DATA_WIDTH-1)-(i*MAX_DATA_WIDTH) -: MAX_DATA_WIDTH] = data_reg;
        end
    endgenerate

    // Last possibly smaller block. 
    (* ram_style = "block" *) logic [LAST_WIDTH-1:0] mem_last [0:ENTRY_COUNT-1];
    logic [LAST_WIDTH-1:0] data_reg_last;

    always_ff @(posedge clk) begin
        if (write_enable)
            mem_last[write_address] <= write_data[LAST_WIDTH-1:0];
        if (read_enable)
            data_reg_last <= mem_last[read_address];
    end

    assign read_data[LAST_WIDTH-1:0] = data_reg_last;

endmodule



module Top {
    input clk,
    input btn[4],
    output led[4],
};
    assign led[0] = btn[0];

endmodule;




// These modules are not present outside of vivado, so we have a very basic
// mock so verilator does not freak out.
`ifdef SIMULATION
module MMCME2_BASE #(
    parameter real CLKFBOUT_MULT_F = 1.0,
    parameter int DIVCLK_DIVIDE = 1,
    parameter real CLKIN1_PERIOD = 1.0,
    parameter real CLKOUT0_DIVIDE_F = 1.0
) (
    input logic CLKIN1,
    input logic RST,
    input logic CLKFBIN,

    output logic CLKOUT0,
    output logic LOCKED,
    output logic CLKFBOUT
);

    assign CLKOUT0 = CLKIN1;
    assign LOCKED = 1'b1;

endmodule

module BUFG (
    input logic I,

    output logic O
);
    assign O = I;
endmodule
`endif
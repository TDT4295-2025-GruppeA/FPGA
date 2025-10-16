`ifdef SIMULATION

import fixed_pkg::*;

// Sadly, verilator only supports (System) Verilog so we have to
// mock the Xilinx Divider IP Core as its source code is in VHDL.
module Divider #(
    parameter int DELAY = 5
) (
    input logic aclk,
    input logic s_axis_divisor_tvalid,
    output logic s_axis_divisor_tready,
    input logic [31:0] s_axis_divisor_tdata,
    input logic s_axis_dividend_tvalid,
    output logic s_axis_dividend_tready,
    input logic [47:0] s_axis_dividend_tdata,
    output logic m_axis_dout_tvalid,
    output logic [47:0] m_axis_dout_tdata
);
    // This is by far not how the actual divider IP core works,
    // but it will work for our simple use case.

    typedef logic [$clog2(DELAY)-1:0] count;

    logic busy = 0;
    count counter;

    assign s_axis_divisor_tready = ~busy;
    assign s_axis_dividend_tready = ~busy;

    logic valid = 0;
    logic [47:0] result;

    assign m_axis_dout_tvalid = valid;

    always_ff @(posedge aclk) begin
        if (!busy) begin
            if (s_axis_divisor_tvalid & s_axis_dividend_tvalid) begin
                busy <= 1;
                result <= signed'(s_axis_dividend_tdata) / 48'(signed'(s_axis_divisor_tdata));
            end

            if (valid) begin
                valid <= 0;
            end
        end else begin
            if (counter == count'(DELAY)) begin
                counter <= 0;
                busy <= 0;
                valid <= 1;
                m_axis_dout_tdata <= result;
            end else begin
                counter <= counter + 1;
            end
        end
    end

endmodule

`endif // SIMULATION

`ifdef SIMULATION

import fixed_pkg::*;
import reciprocal_divider_params::*;

// Sadly, verilator only supports (System) Verilog so we have to
// mock the Xilinx Divider IP Core as its source code is in VHDL.
module ReciprocalDivider #(
    parameter int DELAY = DIVIDER_LATENCY
) (
    input logic aclk,
    input logic aresetn,

    output logic s_axis_dividend_tready,
    input logic s_axis_dividend_tvalid,
    input logic [DIVIDEND_AND_QUOTIENT_WIDTH-1:0] s_axis_dividend_tdata,
    
    output logic s_axis_divisor_tready,
    input logic s_axis_divisor_tvalid,
    input logic [DIVISOR_WIDTH-1:0] s_axis_divisor_tdata,

    input logic m_axis_dout_tready,
    output logic m_axis_dout_tvalid,
    output logic [DIVIDEND_AND_QUOTIENT_WIDTH-1:0] m_axis_dout_tdata
);
    // This is by far not how the actual divider IP core works,
    // but it will work for our simple use case.

    // TODO: Add fifo buffer to input to reflect 
    // how the actual IP core works.

    typedef logic [$clog2(DELAY)-1:0] count;

    logic busy;
    count counter;

    assign s_axis_divisor_tready = ~busy;
    assign s_axis_dividend_tready = 1'b1;

    logic valid = 0;
    logic signed [DIVIDEND_AND_QUOTIENT_WIDTH-1:0] result;

    assign m_axis_dout_tvalid = valid;

    always_ff @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            busy    <= 0;
            counter <= 0;
            valid   <= 0;
            m_axis_dout_tdata <= '0;
        end 

        if (!busy) begin
            if (s_axis_divisor_tvalid & s_axis_dividend_tvalid) begin
                // Start "computation" once both inputs are valid.
                busy <= 1;

                // Store result of "computation" in internal register.
                // It will be output once "computation" is done.
                result <= signed'(s_axis_dividend_tdata) / DIVIDEND_AND_QUOTIENT_WIDTH'(signed'(s_axis_divisor_tdata));
            end
        end else begin
            if (counter == count'(DELAY)) begin
                // Put data on output once "computation" is done.
                valid <= 1;
                m_axis_dout_tdata <= DIVIDEND_AND_QUOTIENT_WIDTH'(result);
            end else begin
                // Continue "computation" until done.
                counter <= counter + 1;
            end

            if (m_axis_dout_tready & valid) begin
                // Reset state once output has been accepted.
                counter <= 0;
                busy <= 0;
                valid <= 0;
            end
        end
    end

endmodule

`endif // SIMULATION

import cocotb
from cocotb.triggers import RisingEdge, Timer, ClockCycles
from cocotb.clock import Clock

VERILOG_MODULE = "SingleBitSync"

@cocotb.test()
async def test_single_bit_sync(dut):
    """Test single-bit synchronizer for correct level signal transfer."""

    dut.rst_dst_n.value = 0 # Assert reset
    dut.data_in_src.value = 0 

    cocotb.start_soon(Clock(dut.clk_dst, 13, units="ns").start())

    # Wait for a few clock cycles with reset asserted
    await ClockCycles(dut.clk_dst, 5)

    dut.rst_dst_n.value = 1 # De-assert reset
    await RisingEdge(dut.clk_dst)

    dut._log.info("Testing 0 -> 1 transition")
    
    dut.data_in_src.value = 1
    
    await RisingEdge(dut.clk_dst)

    await RisingEdge(dut.clk_dst)

    await Timer(1, units="ns") # Small delay to ensure value is stable

    assert int(dut.data_out_dst.value) == 1, f"Failed to sync 1 after 2nd attempt. Got {int(dut.data_out_dst.value)}"

    dut._log.info("Testing 1 -> 0 transition")
    
    dut.data_in_src.value = 0
    await RisingEdge(dut.clk_dst)

    await RisingEdge(dut.clk_dst)

    await Timer(1, units="ns") # Small delay to ensure value is stable

    assert int(dut.data_out_dst.value) == 0, f"Failed to sync 0 after 2nd attempt. Got {int(dut.data_out_dst.value)}"
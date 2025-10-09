import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock

VERILOG_MODULE = "PointerSynchronizer"
VERILOG_PARAMETERS = {
    "WIDTH": 8,
}

CLOCK_PERIOD = 4

# IMPORTANT: This test only checks logic!
# We have no way to test that the module handles metastability correctly.


@cocotb.test()
async def test_pointer_synchronizer(dut):
    clock = Clock(dut.clk_dest, CLOCK_PERIOD)
    cocotb.start_soon(clock.start())

    # Reset device
    dut.rstn.value = 0
    await Timer(CLOCK_PERIOD)
    dut.rstn.value = 1
    await Timer(CLOCK_PERIOD)

    # Assert initial state
    assert (
        dut.data_out.value == 0
    ), f"Initial data_out should be zero. Actual: {dut.data_out.value}"
    assert (
        dut.sync1.value == 0
    ), f"Initial sync1 should be zero. Actual: {dut.sync1.value}"
    assert (
        dut.sync2.value == 0
    ), f"Initial sync2 should be zero. Actual: {dut.sync2.value}"

    for i in range(256):
        dut.data_in.value = i
        await Timer(2 * CLOCK_PERIOD)
        assert (
            dut.data_out.value == i
        ), f"Output mismatched with input. Actual: {dut.data_out.value}, Expected: {i}"

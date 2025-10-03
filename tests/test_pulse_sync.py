import cocotb
from cocotb.triggers import (
    RisingEdge,
    Timer,
    ClockCycles,
    with_timeout,
    SimTimeoutError,
)
from cocotb.clock import Clock

VERILOG_MODULE = "PulseSync"


@cocotb.test()
async def test_pulse_sync(dut):
    """Test the PulseSync module for reliable pulse transfer."""

    dut.rst_src_n.value = 0
    dut.rst_dst_n.value = 0
    dut.pulse_in_src.value = 0

    src_clock_period = 10  # 100 MHz
    dst_clock_period = 13  # ~77 MHz
    cocotb.start_soon(Clock(dut.clk_src, src_clock_period, units="ns").start())
    cocotb.start_soon(Clock(dut.clk_dst, dst_clock_period, units="ns").start())

    await ClockCycles(dut.clk_src, 5)
    await ClockCycles(dut.clk_dst, 5)

    dut.rst_src_n.value = 1
    dut.rst_dst_n.value = 1
    await RisingEdge(dut.clk_src)
    await RisingEdge(dut.clk_dst)

    dut._log.info("Test 1: Sending a single pulse")

    dut.pulse_in_src.value = 1
    await RisingEdge(dut.clk_src)
    dut.pulse_in_src.value = 0

    try:
        await with_timeout(RisingEdge(dut.pulse_out_dst), 100, timeout_unit="ns")
        assert dut.pulse_out_dst.value == 1, "Pulse was not received correctly"
    except SimTimeoutError:
        dut._log.error("Timeout: Pulse was not received.")
        assert False, "Timeout: Pulse was not received."

    await RisingEdge(dut.clk_dst)

    await Timer(1, units="ns")  # Small delay to ensure value is stable

    assert dut.pulse_out_dst.value == 0, "Pulse was not a single cycle."

    dut._log.info("Test 2: Sending a second pulse")

    dut.pulse_in_src.value = 1
    await RisingEdge(dut.clk_src)
    dut.pulse_in_src.value = 0

    try:
        await with_timeout(RisingEdge(dut.pulse_out_dst), 100, timeout_unit="ns")
        assert dut.pulse_out_dst.value == 1, "Second pulse was not received correctly"
    except SimTimeoutError:
        dut._log.error("Timeout: Second pulse was not received.")
        assert False, "Timeout: Second pulse was not received."

    await RisingEdge(dut.clk_dst)

    await Timer(1, units="ns")  # Small delay to ensure value is stable

    assert dut.pulse_out_dst.value == 0, "Second pulse was not a single cycle."

import cocotb
from stubs.fixedreciprocaldivider import Fixedreciprocaldivider
from cocotb.triggers import RisingEdge, ReadOnly
from cocotb.clock import Clock

from tools.utils import (
    MAX_VALUE,
    MIN_VALUE,
    quantize,
    to_fixed,
    to_float,
    within_tolerance,
)
from tools.cases import TEST_VALUES

VERILOG_MODULE = "FixedReciprocalDivider"


@cocotb.test(timeout_time=1, timeout_unit="ms")
async def test_fixed_reciprocal_divider(dut: Fixedreciprocaldivider):
    clock = Clock(dut.clk, 4, "ns")
    cocotb.start_soon(clock.start())

    dut.rstn.value = 1

    await clock.cycles(2)

    # We are always ready to accept data.
    dut.result_m_ready.value = 1

    for b in TEST_VALUES:
        dut._log.info(f"Testing dividend={1.0:.5f}, divider={b:.5f}")

        expected_result = 1 / quantize(b) if to_fixed(b) != 0 else 0.0

        if expected_result > MAX_VALUE or expected_result < MIN_VALUE:
            dut._log.info(
                f"Skipping test as result is out of bounds: {expected_result:.6f}"
            )
            continue

        dut.divisor_s_data.value = to_fixed(b)
        dut.divisor_s_valid.value = 1

        # Wait until ready
        await ReadOnly()
        if not dut.divisor_s_ready.value:
            await RisingEdge(dut.divisor_s_ready)

        # Wait until sample
        await RisingEdge(dut.clk)

        # Clear valid signal
        dut.divisor_s_valid.value = 0

        # Wait for result
        await ReadOnly()
        if not dut.result_m_valid.value:
            await RisingEdge(dut.result_m_valid)

        result = to_float(dut.result_m_data.value.to_signed())

        dut._log.info(f"{1.0:.6f} / {b:.6f} = {result:.6f}")

        assert within_tolerance(
            result, expected_result
        ), f"Expected {expected_result}, got {result}."

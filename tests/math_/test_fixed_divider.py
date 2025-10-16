import cocotb
import numpy as np
from stubs.fixeddivider import Fixeddivider
from cocotb.triggers import RisingEdge, Timer, ReadOnly
from cocotb.clock import Clock

from utils import quantize, to_fixed, to_float, within_tolerance

VERILOG_MODULE = "FixedDivider"

TEST_VALUES = set(np.linspace(-1, 1, 101) + np.linspace(-10, 10, 101))


@cocotb.test()
async def test_fixed_divider(dut: Fixeddivider):
    clock = Clock(dut.clk, 4, "ns")
    cocotb.start_soon(clock.start())

    await clock.cycles(2)

    for a in TEST_VALUES:
        for b in TEST_VALUES:
            dut._log.info(f"Testing dividend={a:.5f}, divider={b:.5f}")

            dut.dividend.value = to_fixed(a)
            dut.divisor.value = to_fixed(b)
            dut.operands_valid.value = 1

            # Wait until ready
            await ReadOnly()
            if not dut.ready.value:
                await RisingEdge(dut.ready)

            # Wait until sample
            await RisingEdge(dut.clk)

            # Clear valid signal
            dut.operands_valid.value = 0

            # Wait for result
            await ReadOnly()
            if not dut.result_valid.value:
                await RisingEdge(dut.result_valid)

            result = to_float(dut.result.get().to_signed())
            expected_result = quantize(a) / quantize(b) if to_fixed(b) != 0 else 0.0

            dut._log.info(f"{a:.6f} / {b:.6f} = {result:.6f}")

            assert within_tolerance(
                result, expected_result
            ), f"Expected {expected_result}, got {result}."

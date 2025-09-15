import cocotb
import numpy as np
from stubs.fixedtb import Fixedtb
from cocotb.triggers import Timer

from utils import within_tolerance

VERILOG_MODULE = "FixedTB"

TOLERANCE = 0.001

TEST_VALUES = set(np.linspace(-1, 1, 101) + np.linspace(-10, 10, 101))

@cocotb.test()
async def test_fixed_arithmetic(dut: Fixedtb):
    for a in TEST_VALUES:
        for b in TEST_VALUES:
            dut._log.info(f"Testing a={a:.5f}, b={b:.5f}")

            dut.a.value = a
            dut.b.value = b

            await Timer(10, units="ns")

            assert within_tolerance(dut.sum.value, a + b), f"Addition failed: {a:.5f} + {b:.5f} = {dut.sum.value:.5f} != {a + b:.5f}"
            assert within_tolerance(dut.sub.value, a - b), f"Subtraction failed: {a:.5f} - {b:.5f} = {dut.diff.value:.5f} != {a - b:.5f}"
            assert within_tolerance(dut.mul.value, a * b), f"Multiplication failed: {a:.5f} * {b:.5f} = {dut.prod.value:.5f} != {a * b:.5f}"
            if b != 0:
                assert within_tolerance(dut.div.value, a / b), f"Division failed: {a:.5f} / {b:.5f} = {dut.div.value:.5f} != {a / b:.5f}"
    
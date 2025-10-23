import cocotb
import numpy as np
from stubs.fixedtb import Fixedtb
from cocotb.triggers import Timer

from utils import MAX_VALUE, MIN_VALUE, quantize, to_fixed, within_tolerance
from cases import TEST_VALUES

VERILOG_MODULE = "FixedTB"


@cocotb.test()
async def test_fixed_arithmetic(dut: Fixedtb):
    for a in TEST_VALUES:
        for b in TEST_VALUES:
            dut._log.info(f"Testing a={a:.5f}, b={b:.5f}")

            dut.a.value = a
            dut.b.value = b

            await Timer(1)

            # Check that the fixed point conversion is as expected.
            assert dut.a_fixed.value.to_signed() == to_fixed(
                a
            ), f"Fixed point conversion failed for a. Expected={to_fixed(a)}, got={dut.a_fixed.value.to_signed()}."
            assert dut.b_fixed.value.to_signed() == to_fixed(
                b
            ), f"Fixed point conversion failed for b. Expected={to_fixed(b)}, got={dut.b_fixed.value.to_signed()}."

            # Quantize a and b to fixed point representation to
            # calculate realistic expected results.
            a = quantize(a)
            b = quantize(b)

            expected_value = [
                (dut.sum.value, a + b, f"Addition failed: {a:.5f} + {b:.5f} = {dut.sum.value:.5f} != {a + b:.5f}"),
                (dut.diff.value, a - b, f"Subtraction failed: {a:.5f} - {b:.5f} = {dut.diff.value:.5f} != {a - b:.5f}"),
                (dut.prod.value, a * b, f"Multiplication failed: {a:.5f} * {b:.5f} = {dut.prod.value:.5f} != {a * b:.5f}"),
            ]

            if b != 0:
                expected_value.append(
                    (dut.quot.value, a / b, f"Division failed: {a:.5f} / {b:.5f} = {dut.quot.value:.5f} != {a / b:.5f}")
                )

            for actual, expected, error_msg in expected_value:
                if expected > MAX_VALUE or expected < MIN_VALUE:
                    dut._log.info(f"Skipping test as result is out of bounds: {expected:.5f}")
                    continue

                assert within_tolerance(actual, expected), error_msg
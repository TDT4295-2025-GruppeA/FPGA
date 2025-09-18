import cocotb
from cocotb.triggers import Timer
import numpy as np
from stubs.veccross import Veccross

from utils import numpy_to_cocotb, cocotb_to_numpy, within_tolerance
from cases import TEST_VECTORS

VERILOG_MODULE = "VecCross"

@cocotb.test()
async def test_cross(dut: Veccross):
    for lhs in TEST_VECTORS:
        for rhs in TEST_VECTORS:
            expected_out = np.cross(lhs, rhs)

            dut._log.info(f"Testing: {lhs} x {rhs} = {expected_out}")

            dut.lhs.set(numpy_to_cocotb(lhs))
            dut.rhs.set(numpy_to_cocotb(rhs))

            await Timer(1)

            actual_out = cocotb_to_numpy(dut.out.get())

            assert within_tolerance(actual_out, expected_out), f"Cross product failed: {l} x {r} = {actual_out} != {expected_out}"

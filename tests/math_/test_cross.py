import cocotb
from cocotb.triggers import Timer
import numpy as np
from stubs.cross import Cross

from utils import numpy_to_cocotb, cocotb_to_numpy, within_tolerance
from cases import TEST_VECTORS

VERILOG_MODULE = "Cross"

@cocotb.test()
async def test_cross(dut: Cross):
    for l in TEST_VECTORS:
        for r in TEST_VECTORS:
            expected_o = np.cross(l, r)

            dut._log.info(f"Testing: {l} x {r} = {expected_o}")

            dut.l.set(numpy_to_cocotb(l))
            dut.r.set(numpy_to_cocotb(r))

            await Timer(1)

            actual_o = cocotb_to_numpy(dut.o.get())

            assert within_tolerance(actual_o, expected_o), f"Cross product failed: {l} x {r} = {actual_o} != {expected_o}"

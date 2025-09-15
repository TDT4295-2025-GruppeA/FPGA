import cocotb
from cocotb.triggers import Timer
import numpy as np
from stubs.cross import Cross

from utils import numpy_to_cocotb, cocotb_to_numpy, within_tolerance

VERILOG_MODULE = "Cross"

TEST_CASES = [
    np.array([    1,    0,     0]),
    np.array([    0,    2,     0]),
    np.array([    0,    0,     3]),
    np.array([    1,   -1,     1]),
    np.array([   -1,    0,     0]),
    np.array([ 0.25, 0.50,  0.75]),
    np.array([-0.10, 0.20, -0.50]),
]

@cocotb.test()
async def test_cross(dut: Cross):
    for l in TEST_CASES:
        for r in TEST_CASES:
            expected_o = np.cross(l, r)

            dut._log.info(f"Testing: {l} x {r} = {expected_o}")

            dut.l.set(numpy_to_cocotb(l))
            dut.r.set(numpy_to_cocotb(r))

            await Timer(1)

            actual_o = cocotb_to_numpy(dut.o.get())

            assert within_tolerance(actual_o, expected_o), f"Cross product failed: {l} x {r} = {actual_o} != {expected_o}"

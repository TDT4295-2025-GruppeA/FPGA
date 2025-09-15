import cocotb
from cocotb.triggers import Timer
import numpy as np
from stubs.dot import Dot

from utils import numpy_to_cocotb, cocotb_to_numpy, within_tolerance

VERILOG_MODULE = "Dot"
VERILOG_PARAMETERS = {
    "N": 3,
}

TEST_VECTORS = [
    np.array([1, 0, 0]),
    np.array([0, 1, 0]),
    np.array([0, 0, 1]),
    np.array([1, 2, 3]),
    np.array([4, 5, 6]),
    np.array([0.1, 0.2, 0.3]),
    np.array([0.4, 0.5, 0.6]),
    np.array([-1, -2, -3]),
    np.array([-4, -5, -6]),
    np.array([0.5, -0.5, 0.5]),
    np.array([-0.5, 0.5, -0.5]),
]

@cocotb.test()
async def test_dot(dut: Dot):
    for l in TEST_VECTORS:
        for r in TEST_VECTORS:
            expected_o = np.dot(l, r)

            dut._log.info(f"Testing: {l} · {r} = {expected_o}")

            dut.l.set(numpy_to_cocotb(l))
            dut.r.set(numpy_to_cocotb(r))

            await Timer(1)

            actual_o = cocotb_to_numpy(dut.o.get())

            assert within_tolerance(actual_o, expected_o), f"Dot product failed: {l} · {r} = {actual_o} != {expected_o}"

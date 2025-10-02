import cocotb
from cocotb.triggers import Timer
import numpy as np
from stubs.vecdot import Vecdot

from utils import numpy_to_cocotb, cocotb_to_numpy, within_tolerance
from cases import TEST_VECTORS

VERILOG_MODULE = "VecDot"
VERILOG_PARAMETERS = {
    "N": 3,
}


@cocotb.test()
async def test_dot(dut: Vecdot):
    for lhs in TEST_VECTORS:
        for rhs in TEST_VECTORS:
            expected_out = np.dot(lhs, rhs)

            dut._log.info(f"Testing: {lhs} · {rhs} = {expected_out}")

            dut.lhs.set(numpy_to_cocotb(lhs))
            dut.rhs.set(numpy_to_cocotb(rhs))

            await Timer(1)

            actual_out = cocotb_to_numpy(dut.out.get())

            assert within_tolerance(
                actual_out, expected_out
            ), f"Dot product failed: {lhs} · {rhs} = {actual_out} != {expected_out}"

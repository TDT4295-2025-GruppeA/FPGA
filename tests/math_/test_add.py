import cocotb
from cocotb.triggers import Timer
import numpy as np
# from stubs.sub import Sub

from utils import numpy_to_cocotb, cocotb_to_numpy, within_tolerance
from cases import TEST_VECTORS

VERILOG_MODULE = "Add"
VERILOG_PARAMETERS = {
    "N": 3,
}

@cocotb.test()
async def test_dot(dut):
    for l in TEST_VECTORS:
        for r in TEST_VECTORS:
            expected_o = l + r

            dut._log.info(f"Testing: {l} + {r} = {expected_o}")

            dut.l.set(numpy_to_cocotb(l))
            dut.r.set(numpy_to_cocotb(r))

            await Timer(1)

            actual_o = cocotb_to_numpy(dut.o.get())

            assert within_tolerance(actual_o, expected_o), f"Addition failed: {l} + {r} = {actual_o} != {expected_o}"

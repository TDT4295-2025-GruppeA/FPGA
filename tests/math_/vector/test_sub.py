import cocotb
from cocotb.triggers import Timer
import numpy as np
from stubs.vecsub import Vecsub

from utils import numpy_to_cocotb, cocotb_to_numpy, within_tolerance, quantize
from cases import TEST_VECTORS

VERILOG_MODULE = "VecSub"
VERILOG_PARAMETERS = {
    "N": 3,
}


@cocotb.test()
async def test_dot(dut: Vecsub):
    for lhs in TEST_VECTORS:
        for rhs in TEST_VECTORS:
            dut._log.info(f"Testing: {lhs} - {rhs}")

            dut.lhs.set(numpy_to_cocotb(lhs))
            dut.rhs.set(numpy_to_cocotb(rhs))

            await Timer(1)

            actual_out = cocotb_to_numpy(dut.out.get())
        
            lhs = quantize(lhs)
            rhs = quantize(rhs)
            expected_out = lhs - rhs

            assert within_tolerance(actual_out, expected_out), (
                f"Subtraction failed: {lhs} - {rhs} = {actual_out} != {expected_out}"
            )

import numpy as np
import cocotb
from cocotb.triggers import Timer
from stubs.matmul import Matmul

from utils import within_tolerance, quantize, numpy_to_cocotb, cocotb_to_numpy

VERILOG_MODULE = "MatMul"
VERILOG_PARAMETERS = {
    "M": 2,
    "K": 2,
    "N": 2,
}

TEST_MATRICIES = [
    np.array(
        [
            [1, 0],
            [0, 1],
        ]
    ),
    np.array(
        [
            [0, 1],
            [1, 0],
        ]
    ),
    np.array(
        [
            [0, 1],
            [-1, 0],
        ]
    ),
    np.array(
        [
            [1, 2],
            [3, 4],
        ]
    ),
    np.array(
        [
            [0.5, 0.25],
            [0.75, 0.1],
        ]
    ),
]


@cocotb.test()
async def test_matmul(dut: Matmul):
    for a in TEST_MATRICIES:
        for b in TEST_MATRICIES:
            dut._log.info(f"Testing:\n{a} @ \n{b}")

            dut.lhs.set(numpy_to_cocotb(a))
            dut.rhs.set(numpy_to_cocotb(b))

            await Timer(1)

            actual_c = cocotb_to_numpy(dut.out.get())
            
            a = quantize(a)
            b = quantize(b)
            expected_c = a @ b

            assert within_tolerance(actual_c, expected_c, tolerance_lsb=1), (
                f"Matrix multiplication failed: \n{a} @ \n{b} = \n{actual_c} != \n{expected_c}"
            )


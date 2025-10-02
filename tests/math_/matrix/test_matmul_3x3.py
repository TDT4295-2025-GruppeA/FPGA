import numpy as np
import cocotb
from cocotb.triggers import Timer
from stubs.matmul import Matmul

from utils import within_tolerance, numpy_to_cocotb, cocotb_to_numpy

VERILOG_MODULE = "MatMul"
VERILOG_PARAMETERS = {
    "M": 3,
    "K": 3,
    "N": 3,
}

TEST_MATRICIES = [
    np.array(
        [
            [1, 0, 0],
            [0, 1, 0],
            [0, 0, 1],
        ]
    ),
    np.array(
        [
            [0, 1, 0],
            [1, 0, 0],
            [0, 0, 1],
        ]
    ),
    np.array(
        [
            [0, 1, 0],
            [-1, 0, 0],
            [0, 0, 1],
        ]
    ),
    np.array(
        [
            [1, 2, 3],
            [4, 5, 6],
            [7, 8, 9],
        ]
    ),
    np.array(
        [
            [9, 8, 7],
            [6, 5, 4],
            [3, 2, 1],
        ]
    ),
    np.array(
        [
            [0.5, 0.25, 0.1],
            [0.75, 0.1, 0.05],
            [0.2, 0.4, 0.6],
        ]
    ),
]


@cocotb.test()
async def test_matmul(dut: Matmul):
    for a in TEST_MATRICIES:
        for b in TEST_MATRICIES:
            expected_c = a @ b

            dut._log.info(f"Testing:\n{a} @ \n{b} = \n{expected_c}")

            dut.lhs.set(numpy_to_cocotb(a))
            dut.rhs.set(numpy_to_cocotb(b))

            await Timer(1)

            actual_c = cocotb_to_numpy(dut.out.get())

            assert within_tolerance(
                actual_c, expected_c
            ), f"Matrix multiplication failed: \n{a} @ \n{b} = \n{actual_c} != \n{expected_c}"

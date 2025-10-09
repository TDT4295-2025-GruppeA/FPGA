import cocotb
from cocotb.triggers import Timer
from stubs.binarytogray import Binarytogray

from utils import differ_by_one_bit

WIDTH = 8
NUM_VALUES = 2**WIDTH

VERILOG_MODULE = "BinaryToGray"
VERILOG_PARAMETERS = {
    "WIDTH": WIDTH,
}


@cocotb.test()
async def test_binary_to_gray(dut: Binarytogray):
    results: list[int] = []

    # Go over all possible input values
    for i in range(NUM_VALUES):
        dut.binary.value = i
        await Timer(1)
        results.append(dut.gray.value.to_unsigned())

    # Check that all outputs were unique
    assert len(set(results)) == NUM_VALUES, "Not all output values were unique."

    # Check that the output values differ by one bit
    for i in range(NUM_VALUES - 1, -1, -1):
        assert differ_by_one_bit(results[i], results[i - 1]), (
            f"Encoding of {i}: {results[i]} and "
            f"encoding of {(i - 1) % NUM_VALUES}: {results[i - 1]} "
            "do not differ by exactly one bit."
        )

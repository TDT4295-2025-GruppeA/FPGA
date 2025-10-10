import cocotb
from cocotb.triggers import Timer
from stubs.graytobinary import Graytobinary

from utils import differ_by_one_bit

WIDTH = 8
NUM_VALUES = 2**WIDTH

VERILOG_MODULE = "GrayToBinary"
VERILOG_PARAMETERS = {
    "WIDTH": WIDTH,
}


@cocotb.test()
async def test_gray_to_binary(dut: Graytobinary):
    results: dict[int, int] = {}

    # Go over all possible input values
    for i in range(NUM_VALUES):
        dut.gray.value = i
        await Timer(1)
        results[i] = dut.binary.value.to_unsigned()

    # Check that all outputs were unique
    assert (
        len(set(results.values())) == NUM_VALUES
    ), "Not all output values were unique."

    # Sort the outputs by their binary value
    sorted_results = [
        item[0] for item in sorted(results.items(), key=lambda item: item[1])
    ]

    # Check that the output values differ by one bit
    for i in range(NUM_VALUES - 1, -1, -1):
        assert differ_by_one_bit(sorted_results[i], sorted_results[i - 1]), (
            f"Encoding of {i}: {sorted_results[i]} and "
            f"encoding of {(i - 1) % NUM_VALUES}: {sorted_results[i - 1]} "
            "do not differ by exactly one bit."
        )

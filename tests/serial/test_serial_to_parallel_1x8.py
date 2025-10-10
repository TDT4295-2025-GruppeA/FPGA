import cocotb
from cocotb.triggers import FallingEdge
from cocotb.clock import Clock

from stubs.serialtoparallel import Serialtoparallel
from serial.serial_to_parallel_tester import tester_serial_to_parallel

# OUTPUT_SIZE must be divisible by INPUT_SIZE
INPUT_SIZE = 1
OUTPUT_SIZE = 8

VERILOG_MODULE = "SerialToParallel"
VERILOG_PARAMETERS = {
    "INPUT_SIZE": INPUT_SIZE,
    "OUTPUT_SIZE": OUTPUT_SIZE,
}

CLOCK_PERIOD = 4

TEST_DATA = [0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0xFF, 0x42]


@cocotb.test()
async def test_serial_to_parallel(dut: Serialtoparallel):
    await tester_serial_to_parallel(
        dut, TEST_DATA, INPUT_SIZE, OUTPUT_SIZE, CLOCK_PERIOD
    )

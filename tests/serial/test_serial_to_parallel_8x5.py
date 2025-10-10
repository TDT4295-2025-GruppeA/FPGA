import cocotb
from cocotb.triggers import FallingEdge
from cocotb.clock import Clock

from stubs.serialtoparallel import Serialtoparallel

# OUTPUT_SIZE must be divisible by INPUT_SIZE
INPUT_SIZE = 8
OUTPUT_SIZE = 8*5
OUTPUT_WIDTH = OUTPUT_SIZE // 4
INPUT_WIDTH = INPUT_SIZE // 4

ELEMENT_COUNT = OUTPUT_SIZE // INPUT_SIZE

VERILOG_MODULE = "SerialToParallel"
VERILOG_PARAMETERS = {
    "INPUT_SIZE": INPUT_SIZE,
    "OUTPUT_SIZE": OUTPUT_SIZE,
}

CLOCK_PERIOD = 4

TEST_DATA = [
    0xDEABCDEF88,
    0xADCFB229FE,
    0xBE648833BF,
    0xEFFFFFFFFF,
    0xFFFFFFFFFE,
    0x0000000000,
    0xFFFFFFFFFF,
    0x427751BD99,
]


@cocotb.test()
async def test_serial_to_parallel(dut: Serialtoparallel):
    clock = Clock(dut.clk, CLOCK_PERIOD)
    cocotb.start_soon(clock.start())

    # Reset device.
    dut.rstn.value = 0
    # Wait until between sample edges (rising) to avoid sampling early.
    await FallingEdge(dut.clk)
    dut.rstn.value = 1

    # Assert initial state
    assert (
        dut.parallel_ready.value == 0
    ), f"Initial parallel_ready should be zero. Actual: 0x{dut.serial.value:02x}"
    assert (
        dut.parallel.value == 0
    ), f"Initial parallel should be zero. Actual: 0x{dut.parallel.value:02x}"

    previous_byte = 0

    # Send bytes and check buffer
    for serial_in in TEST_DATA:
        for i in range(ELEMENT_COUNT):
            serial_element = (serial_in >> (OUTPUT_SIZE - INPUT_SIZE - i * INPUT_SIZE)) & ((1 << INPUT_SIZE) -1)
            dut._log.info(
                f"Sending element {i+1} of test 0x{serial_in:0{OUTPUT_WIDTH}x}: 0b{serial_element:0{INPUT_SIZE}b} (0x{serial_element:0{INPUT_WIDTH}x})\n"
                f"Current parallel_ready: {dut.parallel_ready.value}\n"
                f"Current parallel: {dut.parallel.value.to_unsigned():0{OUTPUT_WIDTH}x}\n"
                f"Current serial: {dut.serial.value}\n"
                f"Previous byte: 0x{previous_byte:02x}\n"
                f"Element count: {dut.element_count.value.to_unsigned()}"
            )

            dut.serial.value = serial_element
            # Set next element on falling edges as SPI module samples on rising edge.
            await FallingEdge(dut.clk)

        dut._log.info(
            f"Asserting parallel output...\n"
            f"Current parallel_ready: {dut.parallel_ready.value}\n"
            f"Current parallel: 0x{dut.parallel.value.to_unsigned():0{OUTPUT_WIDTH}x}\n"
            f"Current serial: {dut.serial.value}\n"
            f"Previous byte: 0x{previous_byte:02x}"
        )

        assert (
            dut.parallel_ready.value == 1
        ), f"parallel_ready should be high after {ELEMENT_COUNT} elements have been sent."
        assert (
            dut.parallel.value.to_unsigned() == serial_in
        ), f"parallel should match input byte. Actual: 0x{dut.parallel.value.to_unsigned():02x}, Expected: 0x{serial_in:02x}"

        previous_byte = serial_in

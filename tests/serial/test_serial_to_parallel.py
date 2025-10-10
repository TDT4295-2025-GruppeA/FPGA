import cocotb
from cocotb.triggers import FallingEdge
from cocotb.clock import Clock

from stubs.serialtoparallel import Serialtoparallel

VERILOG_MODULE = "SerialToParallel"
VERILOG_PARAMETERS = {
    "SIZE": 8,
}

CLOCK_PERIOD = 4

TEST_DATA = [0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0xFF, 0x42]


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
    for byte in TEST_DATA:
        for i in range(8):
            dut._log.info(
                f"Sending bit {i+1} of byte {byte:02x}: {(byte >> (7 - i)) & 1}\n"
                f"Current parallel_ready: {dut.parallel_ready.value}\n"
                f"Current parallel: {dut.parallel.value.to_unsigned():02x}\n"
                f"Current serial: {dut.serial.value}\n"
                f"Previous byte: 0x{previous_byte:02x}"
            )

            dut.serial.value = (byte >> (7 - i)) & 1
            # Set next bit on falling edges as SPI module samples on rising edge.
            await FallingEdge(dut.clk)

        dut._log.info(
            f"Asserting parallel output...\n"
            f"Current parallel_ready: {dut.parallel_ready.value}\n"
            f"Current parallel: {dut.parallel.value.to_unsigned():02x}\n"
            f"Current serial: {dut.serial.value}\n"
            f"Previous byte: 0x{previous_byte:02x}"
        )

        assert (
            dut.parallel_ready.value == 1
        ), "parallel_ready should be high after 8 bits have been sent."
        assert (
            dut.parallel.value.to_unsigned() == byte
        ), f"parallel should match input byte. Actual: 0x{dut.parallel.value.to_unsigned():02x}, Expected: 0x{byte:02x}"

        previous_byte = byte

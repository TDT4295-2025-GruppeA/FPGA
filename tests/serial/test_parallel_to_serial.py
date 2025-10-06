import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock

from stubs.paralleltoserial import Paralleltoserial

VERILOG_MODULE = "ParallelToSerial"
VERILOG_PARAMETERS = {
    "SIZE": 8,
}

CLOCK_PERIOD = 4

TEST_DATA = [0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0xFF, 0x42]

@cocotb.test()
async def test_parallel_to_serial(dut: Paralleltoserial):
    clock = Clock(dut.clk, CLOCK_PERIOD)
    cocotb.start_soon(clock.start())

    # Reset device
    dut.rstn.value = 0
    await Timer(CLOCK_PERIOD)
    dut.rstn.value = 1
    await Timer(CLOCK_PERIOD)

    # Assert initial state
    assert dut.serial.value == 0, f"Initial serial should be zero. Actual: 0x{dut.serial.value:02x}"

    # Send bytes and check buffer
    for byte in TEST_DATA:
        dut._log.info(f"Sending byte {byte:02x}.\n")

        dut.parallel_ready.value = 1
        dut.parallel.value = byte

        await Timer(CLOCK_PERIOD)

        dut.parallel_ready.value = 0
        dut.parallel.value = 0

        # Read bits out serially
        for i in range(8):
            dut._log.info(
                f"Reading bit {i+1}/8 of byte {byte:02x}\n"
                f"Current parallel: {dut.parallel.value.to_unsigned():02x}\n"
                f"Current serial: {dut.serial.value}"
            )

            expected_serial = (byte >> (7 - i)) & 1
            assert dut.serial.value == expected_serial, f"serial mismatch at bit {i+1}. Actual: {dut.serial.value}, Expected: {expected_serial}"

            # If this is the last bit, skip the wait to avoid extra clock cycle.
            if i == 7:
                break

            await Timer(CLOCK_PERIOD)

        # Assert that parallel is (almost) empty after shifting out all bits.
        assert dut.parallel.value.to_unsigned() & 0x7F == 0, f"parallel (except first bit) should be zero after shifting out all bits. Actual: 0x{dut.parallel.value.to_unsigned():02x}"
    
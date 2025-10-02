import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock

from stubs.shiftregister import Shiftregister

VERILOG_MODULE = "ShiftRegister"
VERILOG_PARAMETERS = {
    "SIZE": 8,
}

CLOCK_PERIOD = 4

TEST_DATA = [0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0xFF, 0x42]

@cocotb.test()
async def test_shift_register_serial_to_parallel(dut: Shiftregister):
    clock = Clock(dut.clk, CLOCK_PERIOD)
    cocotb.start_soon(clock.start())

    # Reset device
    dut.rstn.value = 0
    await Timer(CLOCK_PERIOD)
    dut.rstn.value = 1
    await Timer(CLOCK_PERIOD)

    # Assert initial state
    assert dut.serial_out.value == 0, f"Initial serial_out should be zero. Actual: 0x{dut.serial_out.value:02x}"
    assert dut.parallel_out.value == 0, f"Initial parallel_out should be zero. Actual: 0x{dut.parallel_out.value:02x}"
    assert dut.buffer.value == 0, f"Initial buffer should be zero. Actual: 0x{dut.buffer.value:02x}"

    previous_byte = 0

    # Send bytes and check buffer
    for byte in TEST_DATA:
        for i in range(8):
            dut._log.info(
                f"Sending bit {(byte >> (7 - i)) & 1} ({i+1}/8) of byte {byte:02x}\n"
                f"Current parallel_out: {dut.parallel_out.value.to_unsigned():02x}\n"
                f"Current serial_out: {dut.serial_out.value}\n"
                f"Previous byte: 0x{previous_byte:02x}"
            )

            expected_serial_out = (previous_byte >> (7 - i)) & 1
            assert dut.serial_out.value == expected_serial_out, f"serial_out mismatch. Actual: {dut.serial_out.value}, Expected: {expected_serial_out}"

            dut.serial_in.value = (byte >> (7 - i)) & 1
            await Timer(CLOCK_PERIOD)

        assert dut.parallel_out.value.to_unsigned() == byte, f"parallel_out should match input byte. Actual: 0x{dut.parallel_out.value.to_unsigned():02x}, Expected: 0x{byte:02x}"

        previous_byte = byte

@cocotb.test()
async def test_shift_register_parallel_to_serial(dut: Shiftregister):
    clock = Clock(dut.clk, CLOCK_PERIOD)
    cocotb.start_soon(clock.start())

    # Reset device
    dut.rstn.value = 0
    await Timer(CLOCK_PERIOD)
    dut.rstn.value = 1
    await Timer(CLOCK_PERIOD)

    # Assert initial state
    assert dut.serial_out.value == 0, f"Initial serial_out should be zero. Actual: 0x{dut.serial_out.value:02x}"
    assert dut.parallel_out.value == 0, f"Initial parallel_out should be zero. Actual: 0x{dut.parallel_out.value:02x}"
    assert dut.buffer.value == 0, f"Initial buffer should be zero. Actual: 0x{dut.buffer.value:02x}"

    # Send bytes and check buffer
    for byte in TEST_DATA:
        dut._log.info(f"Sending byte {byte:02x}.\n")

        dut.parallel_in_en.value = 1
        dut.parallel_in.value = byte

        await Timer(CLOCK_PERIOD)

        dut.parallel_in_en.value = 0
        dut.parallel_in.value = 0

        # Read bits out serially
        for i in range(8):
            dut._log.info(
                f"Reading bit {i+1}/8 of byte {byte:02x}\n"
                f"Current parallel_out: {dut.parallel_out.value.to_unsigned():02x}\n"
                f"Current serial_out: {dut.serial_out.value}"
            )

            expected_serial_out = (byte >> (7 - i)) & 1
            assert dut.serial_out.value == expected_serial_out, f"serial_out mismatch at bit {i+1}. Actual: {dut.serial_out.value}, Expected: {expected_serial_out}"

            # If this is the last bit, skip the wait to avoid extra clock cycle.
            if i == 7:
                break

            await Timer(CLOCK_PERIOD)

        # Assert that parallel_out is (almost) empty after shifting out all bits.
        assert dut.parallel_out.value.to_unsigned() & 0x7F == 0, f"parallel_out (except first bit) should be zero after shifting out all bits. Actual: 0x{dut.parallel_out.value.to_unsigned():02x}"
    
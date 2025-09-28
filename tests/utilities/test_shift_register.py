import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock

VERILOG_MODULE = "ShiftRegister"
VERILOG_PARAMETERS = {
    "SIZE": 8,
}

CLOCK_PERIOD = 4

TEST_DATA = [0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0xFF, 0x42]

@cocotb.test()
async def test_shift_register(dut):
    clock = Clock(dut.clk, CLOCK_PERIOD)
    cocotb.start_soon(clock.start())

    # Reset device
    dut.rstn.value = 0
    await Timer(CLOCK_PERIOD)
    dut.rstn.value = 1
    await Timer(CLOCK_PERIOD)

    # Assert initial state
    assert dut.data_out.value == 0, f"Initial data_out should be zero. Actual: 0x{dut.data_out.value:02x}"
    assert dut.buffer.value == 0, f"Initial buffer should be zero. Actual: 0x{dut.buffer.value:02x}"

    previous_byte = 0

    # Send bytes and check buffer
    for byte in TEST_DATA:
        for i in range(8):
            dut._log.info(
                f"Sending bit {(byte >> (7 - i)) & 1} ({i+1}/8) of byte {byte:02x}\n"
                f"Current buffer: {dut.buffer.value.to_unsigned():02x}\n"
                f"Current data_out: {dut.data_out.value}\n"
                f"Previous byte: 0x{previous_byte:02x}"
            )

            expected_data_out = (previous_byte >> (7 - i)) & 1
            assert dut.data_out.value == expected_data_out, f"data_out mismatch. Actual: {dut.data_out.value}, Expected: {expected_data_out}"

            dut.data_in.value = (byte >> (7 - i)) & 1
            await Timer(CLOCK_PERIOD)

        assert dut.buffer.value.to_unsigned() == byte, f"Buffer should match input byte. Actual: 0x{dut.buffer.value.to_unsigned():02x}, Expected: 0x{byte:02x}"

        previous_byte = byte
    
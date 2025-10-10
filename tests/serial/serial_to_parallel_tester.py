import cocotb
from cocotb.triggers import FallingEdge
from cocotb.clock import Clock

from stubs.serialtoparallel import Serialtoparallel


async def tester_serial_to_parallel(
    dut: Serialtoparallel,
    test_data: list[int],
    input_size: int,
    output_size: int,
    clock_period: int = 4,
):
    if output_size % input_size != 0:
        raise ValueError("`output_width`must be divisible by `input_width`")

    input_width = input_size // 4
    output_width = output_size // 4
    element_count = output_size // input_size

    clock = Clock(dut.clk, clock_period)
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
    for serial_in in test_data:
        for i in range(element_count):
            serial_element = (
                serial_in >> (output_size - input_size - i * input_size)
            ) & ((1 << input_size) - 1)
            dut._log.info(
                f"Sending element {i+1} of test 0x{serial_in:0{output_width}x}: 0b{serial_element:0{input_size}b} (0x{serial_element:0{input_width}x})\n"
                f"Current parallel_ready: {dut.parallel_ready.value}\n"
                f"Current parallel: {dut.parallel.value.to_unsigned():0{output_width}x}\n"
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
            f"Current parallel: 0x{dut.parallel.value.to_unsigned():0{output_width}x}\n"
            f"Current serial: {dut.serial.value}\n"
            f"Previous byte: 0x{previous_byte:02x}"
        )

        assert (
            dut.parallel_ready.value == 1
        ), f"parallel_ready should be high after {element_count} elements have been sent."
        assert (
            dut.parallel.value.to_unsigned() == serial_in
        ), f"parallel should match input byte. Actual: 0x{dut.parallel.value.to_unsigned():02x}, Expected: 0x{serial_in:02x}"

        previous_byte = serial_in

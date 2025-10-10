import cocotb
from cocotb.triggers import Timer, Combine
from cocotb.clock import Clock

from stubs.asyncfifo import Asyncfifo

VERILOG_MODULE = "AsyncFifo"
VERILOG_PARAMETERS = {
    "WIDTH": 8,
    "MIN_LENGTH": 8,
}


async def setup_fifo(dut: Asyncfifo, read_clock_period: int, write_clock_period: int):
    read_clock = Clock(dut.read_clk, read_clock_period)
    write_clock = Clock(dut.write_clk, write_clock_period)

    cocotb.start_soon(read_clock.start())
    cocotb.start_soon(write_clock.start())

    slowest_clock_period = max(read_clock_period, write_clock_period)

    # Reset device
    dut.rstn.value = 0
    await Timer(4 * slowest_clock_period)
    dut.rstn.value = 1
    await Timer(4 * slowest_clock_period)


@cocotb.test()
async def test_async_fifo_reset(dut: Asyncfifo):
    # Set internal signals to random values
    dut.rstn.value = 0

    dut.read_ptr.value = 10
    dut.write_ptr.value = 11
    dut.read_ptr_synced.value = 12
    dut.write_ptr_synced.value = 13

    await Timer(1)

    # Call the setup function which resets the fifo
    clock_period = 4
    await setup_fifo(dut, clock_period, clock_period)

    # Assert initial output
    assert dut.empty.value == 1, f"Initial empty should be 1. Actual: {dut.empty.value}"
    assert dut.full.value == 0, f"Initial full should be 0. Actual: {dut.full.value}"
    assert (
        dut.data_out.value == 0
    ), f"Initial data_out should be 0. Actual: {dut.data_out.value}"

    # Assert initial internal state
    assert (
        dut.read_ptr.value == 0
    ), f"Initial read_ptr should be 0. Actual: {dut.read_ptr.value}"
    assert (
        dut.write_ptr.value == 0
    ), f"Initial write_ptr should be 0. Actual: {dut.write_ptr.value}"
    assert (
        dut.read_ptr_synced.value == 0
    ), f"Initial read_ptr_synced should be 0. Actual: {dut.read_ptr_synced.value}"
    assert (
        dut.write_ptr_synced.value == 0
    ), f"Initial write_ptr_synced should be 0. Actual: {dut.write_ptr_synced.value}"


@cocotb.test()
async def test_async_fifo_write_to_full_and_read_to_empty(dut: Asyncfifo):
    clock_period = 4

    await setup_fifo(dut, clock_period, clock_period)

    # Write until full is high or we have written 2*MIN_LENGTH times
    dut.write_en.value = 1

    dut._log.info(
        f"Initial state:\n"
        f" write_ptr: {dut.write_ptr.value}, write_ptr_synced: {dut.write_ptr_synced.value}, full: {dut.full.value}\n"
        f" read_ptr: {dut.read_ptr.value}, read_ptr_synced: {dut.read_ptr_synced.value}, empty: {dut.empty.value}"
    )

    write_count = 0
    while dut.full.value == 0 and write_count < 2 * VERILOG_PARAMETERS["MIN_LENGTH"]:
        dut.data_in.value = write_count & 0xFF
        await Timer(clock_period)
        dut._log.info(
            f"Wrote {write_count}.\n"
            f" write_ptr: {dut.write_ptr.value}, write_ptr_synced: {dut.write_ptr_synced.value}, full: {dut.full.value}\n"
            f" read_ptr: {dut.read_ptr.value}, read_ptr_synced: {dut.read_ptr_synced.value}, empty: {dut.empty.value}"
        )
        write_count += 1

    dut.write_en.value = 0

    await Timer(clock_period)

    assert (
        dut.full.value == 1
    ), f"Full should be 1 after writing {write_count} times. Actual: {dut.full.value}"

    # Read back all data
    dut.read_en.value = 1

    dut._log.info(
        f"Before reading back:\n"
        f" write_ptr: {dut.write_ptr.value}, write_ptr_synced: {dut.write_ptr_synced.value}, full: {dut.full.value}\n"
        f" read_ptr: {dut.read_ptr.value}, read_ptr_synced: {dut.read_ptr_synced.value}, empty: {dut.empty.value}"
    )

    read_count = 0
    while dut.empty.value == 0 and read_count < write_count:
        expected_value = read_count & 0xFF
        dut._log.info(
            f"Read {read_count}.\n"
            f" write_ptr: {dut.write_ptr.value}, write_ptr_synced: {dut.write_ptr_synced.value}, full: {dut.full.value}\n"
            f" read_ptr: {dut.read_ptr.value}, read_ptr_synced: {dut.read_ptr_synced.value}, empty: {dut.empty.value}"
        )
        actual_value = dut.data_out.value.to_unsigned()
        assert (
            actual_value == expected_value
        ), f"Data mismatch at read {read_count}. Actual: {actual_value}, Expected: {expected_value}"
        read_count += 1
        await Timer(clock_period)

    dut.read_en.value = 0

    await Timer(clock_period)

    assert (
        dut.write_ptr.value == dut.read_ptr.value
    ), f"write_ptr and read_ptr should be equal after reading all data. write_ptr: {dut.write_ptr.value}, read_ptr: {dut.read_ptr.value}"
    assert (
        dut.empty.value == 1
    ), f"Empty should be 1 after reading all data. Actual: {dut.empty.value}"


@cocotb.test()
@cocotb.parametrize(
    read_clock_period=[4, 6, 8],
    write_clock_period=[4, 6, 8],
)
async def test_async_fifo_write_read_different_clock(
    dut: Asyncfifo, read_clock_period: int, write_clock_period: int
):
    dut._log.info(
        f"read_clock_period={read_clock_period}, write_clock_period={write_clock_period}"
    )

    await setup_fifo(dut, read_clock_period, write_clock_period)

    # Prepare some pseudo random data to write (and compare against when reading)
    data = [i**2 % 0xFF for i in range(dut.LENGTH.value.to_unsigned())]

    async def write_data():
        for value in data:
            # Spin until we can write
            while dut.full.value == 1:
                await Timer(write_clock_period)
                dut._log.info(
                    "Write spinning...\n"
                    f" write_ptr: {dut.write_ptr.value}, write_ptr_synced: {dut.write_ptr_synced.value}, full: {dut.full.value}\n"
                    f" read_ptr: {dut.read_ptr.value}, read_ptr_synced: {dut.read_ptr_synced.value}, empty: {dut.empty.value}"
                )

            # Write the data
            dut.write_en.value = 1
            dut.data_in.value = value
            await Timer(write_clock_period)
            dut.write_en.value = 0

            dut._log.info(
                f"Wrote {value}.\n"
                f" write_ptr: {dut.write_ptr.value}, write_ptr_synced: {dut.write_ptr_synced.value}, full: {dut.full.value}\n"
                f" read_ptr: {dut.read_ptr.value}, read_ptr_synced: {dut.read_ptr_synced.value}, empty: {dut.empty.value}"
            )

        await Timer(write_clock_period)

    async def read_data():
        for i, expected_value in enumerate(data):
            # Spin until we can read
            while dut.empty.value == 1:
                await Timer(read_clock_period)
                dut._log.info(
                    "Read spinning...\n"
                    f" write_ptr: {dut.write_ptr.value}, write_ptr_synced: {dut.write_ptr_synced.value}, full: {dut.full.value}\n"
                    f" read_ptr: {dut.read_ptr.value}, read_ptr_synced: {dut.read_ptr_synced.value}, empty: {dut.empty.value}"
                )

            dut.read_en.value = 1
            actual_value = dut.data_out.value.to_unsigned()
            await Timer(read_clock_period)
            dut.read_en.value = 0

            dut._log.info(
                f"Read {actual_value}\n"
                f" write_ptr: {dut.write_ptr.value}, write_ptr_synced: {dut.full.value}\n"
                f" read_ptr: {dut.read_ptr.value}, read_ptr_synced: {dut.empty.value}"
            )

            assert (
                actual_value == expected_value
            ), f"Data mismatch at read {i}. Actual: {actual_value}, Expected: {expected_value}"

        await Timer(read_clock_period)

    await Combine(
        cocotb.start_soon(write_data()),
        cocotb.start_soon(read_data()),
    )

from curses.ascii import SP
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge

from stubs.spisub import Spisub

from typing import Callable

VERILOG_MODULE = "SpiSub"
VERILOG_PARAMETERS = {
    "WORD_SIZE": 8,
    "RX_QUEUE_LENGTH": 8,
    "TX_QUEUE_LENGTH": 8,
}

SYS_CLOCK_PERIOD = 10
SPI_CLOCK_PERIOD = 20


async def setup_sys_clock(dut: Spisub):
    sys_clock = Clock(dut.sys_clk, SYS_CLOCK_PERIOD)
    cocotb.start_soon(sys_clock.start())


async def reset_spi(dut: Spisub):
    dut.ssn.value = 1
    dut.sys_rstn.value = 0
    await Timer(SYS_CLOCK_PERIOD * 2)
    dut.sys_rstn.value = 1


async def setup_spi(dut: Spisub):
    await setup_sys_clock(dut)
    await reset_spi(dut)


async def main_transaction(
    dut: Spisub,
    tx_data: list[int],
    rx_start: int = 0,
    rx_length: int = 0,
) -> list[int]:
    """Simulates a main device performing a transaction."""
    # Calculate padding to receive full response.
    tx_padding = [0x00] * max(rx_start + rx_length - len(tx_data), 0)

    # Select SPI module.
    dut.ssn.value = 0
    await Timer(10)

    master_clock = Clock(dut.sclk, SPI_CLOCK_PERIOD)
    started = False

    rx_data = []

    for tx_byte in tx_data + tx_padding:
        dut._log.info(f"Main transmitting byte: {tx_byte:02X}")
        rx_byte = 0

        for i in range(8):
            dut._log.info(f"{i+1}/8")
            # Await falling edge to set data.
            if started:
                await FallingEdge(dut.sclk)

            tx_bit = (tx_byte >> (7 - i)) & 1
            dut.mosi.value = tx_bit
            dut._log.info(f"MOSI: {dut.mosi.value}")

            # If the clock has not been started yet, start it now.
            if not started:
                await Timer(SPI_CLOCK_PERIOD // 2)
                cocotb.start_soon(master_clock.start())
                started = True

            await RisingEdge(dut.sclk)
            rx_bit = int(dut.miso.value)
            rx_byte = (rx_byte << 1) | rx_bit
            dut._log.info(f"MISO: {dut.miso.value}")

        dut._log.info(f"Main received byte: {rx_byte:02X}")
        rx_data.append(rx_byte)

    # Stop master clock.
    master_clock.stop()
    await Timer(10)

    # Deselect SPI module.
    dut.ssn.value = 1
    await Timer(10)

    return rx_data[rx_start : rx_start + rx_length]


async def sub_transaction(dut: Spisub, receive_callback: Callable[[int], int]) -> None:
    """Simulates a sub device responding to a transaction."""

    # Wait until activated by main device.
    await RisingEdge(dut.active)

    tx_byte = None

    while dut.active.value:
        # Receive and process data if available.
        if dut.rx_m_valid.value:
            rx_byte = dut.rx_m_data.value.to_unsigned()
            dut._log.info(f"Sub received byte: {rx_byte:02X}")

            tx_byte = receive_callback(rx_byte) & 0xFF

            dut.rx_m_ready.value = 1
            await Timer(SYS_CLOCK_PERIOD)
            dut.rx_m_ready.value = 0

        # Send data if available.
        if tx_byte is not None:
            dut._log.info(f"Sub transmitting byte: {tx_byte:02X}")
            dut.tx_s_data.value = tx_byte

            dut.tx_s_valid.value = 1
            await Timer(SYS_CLOCK_PERIOD)
            dut.tx_s_valid.value = 0

            tx_byte = None

        await Timer(SYS_CLOCK_PERIOD)


@cocotb.test(timeout_time=2000, timeout_unit="us")
async def test_spi_transaction(dut: Spisub):
    await setup_spi(dut)

    def echo_pluss_one(byte: int) -> int:
        return byte + 1

    cocotb.start_soon(sub_transaction(dut, echo_pluss_one))

    command = [0xF0, 0x0F, 0x00, 0xFF, 0xAB, 0xCD]
    response = await main_transaction(dut, command, 2, len(command))

    # Skip first two bytes which are fill.
    expected_response = [echo_pluss_one(byte) & 0xFF for byte in command]

    assert (
        response == expected_response
    ), f"Received data does not match expectation. Received: {response}, Expected: {expected_response}"

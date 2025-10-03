import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, First
from stubs.top import Top

VERILOG_MODULE = "Top"


@cocotb.test()
async def test_startup_signals(dut: Top):
    # 100 MHz clock on clk_ext
    cocotb.start_soon(Clock(dut.clk_ext, 10, units="ns").start())

    # Assert reset
    dut.reset.value = 1
    for _ in range(5):
        await RisingEdge(dut.clk_ext)  # hold reset for 5 cycles

    # Release reset
    dut.reset.value = 0

    await RisingEdge(dut.draw_start)
    cocotb.log.info(" draw_start pulsed after reset release")

    assert dut.draw_start.value == 1, "draw_start was not pulsed"

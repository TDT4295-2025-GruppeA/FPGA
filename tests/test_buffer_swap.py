import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, with_timeout, Timer
from stubs.top import Top


VERILOG_MODULE = "Top"


@cocotb.test()
async def test_buffer_swap(dut: Top):
    cocotb.start_soon(Clock(dut.clk_ext, 10, unit="ns").start())

    dut.reset.value = 1
    for _ in range(5):
        await RisingEdge(dut.clk_ext)
    dut.reset.value = 0

    await with_timeout(FallingEdge(dut.vga_vsync), 100, "ms")
    await with_timeout(RisingEdge(dut.draw_start), 100, "ms")
    await with_timeout(RisingEdge(dut.dm_frame_done), 100, "ms")
    await with_timeout(RisingEdge(dut.swap_req), 100, "ms")
    await with_timeout(RisingEdge(dut.draw_ack), 100, "ms")

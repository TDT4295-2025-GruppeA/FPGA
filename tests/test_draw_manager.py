import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge
from stubs.drawingmanager import Drawingmanager


VERILOG_MODULE = "DrawingManager"


@cocotb.test(timeout_time=1, timeout_unit="ms")
async def test_drawing_manager_states(dut: Drawingmanager):
    """Step through each DrawingManager state transition"""

    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    dut.rstn.value = 0
    dut.draw_start.value = 0
    dut.bg_draw_done.value = 0
    dut.draw_ack.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    dut.rstn.value = 1
    cocotb.log.info("Reset released, expecting IDLE")

    # --- Step 1: IDLE → DRAWING_BACKGROUND ---
    dut.draw_start.value = 1
    await RisingEdge(dut.clk)
    dut.draw_start.value = 0
    await RisingEdge(dut.clk)
    cocotb.log.info("FSM should be in DRAWING_BACKGROUND (bg_draw_start asserted)")

    assert dut.bg_draw_start.value == 1, "FSM did not enter DRAWING_BACKGROUND"

    # --- Step 2: DRAWING_BACKGROUND → FRAME_DONE ---
    dut.bg_draw_done.value = 1
    await RisingEdge(dut.clk)
    dut.bg_draw_done.value = 0

    await RisingEdge(dut.frame_done)
    cocotb.log.info("FSM entered FRAME_DONE")

    assert dut.frame_done.value == 1, "FSM did not enter FRAME_DONE"

    # For waveform visualization
    for i in range(100):
        await RisingEdge(dut.clk)

    # --- Step 3: FRAME_DONE → DRAWING ---
    dut.draw_ack.value = 1
    await RisingEdge(dut.clk)
    dut.draw_ack.value = 0

    await FallingEdge(dut.frame_done)
    cocotb.log.info("FSM should be back in DRAWING")

    assert dut.frame_done.value == 0
    assert dut.bg_draw_start.value == 1
    cocotb.log.info("FSM returned to BACKGROUND successfully")

    # For waveform visualization
    for i in range(100):
        await RisingEdge(dut.clk)

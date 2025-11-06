import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge
from stubs.drawingmanager import Drawingmanager
from types_ import RGB, PixelCoordinate, PixelData, PixelDataMetadata, Position


VERILOG_MODULE = "DrawingManager"
VERILOG_PARAMETERS = {
    # # We have to specify the filepath here again
    # # as the working directory is different when running
    # # tests than when synthesizing for some reason...
    # "FILE_PATH": '"../static/models/cube"',
    # "TRIANGLE_COUNT": 12,
    "BUFFER_WIDTH": 64,
    "BUFFER_HEIGHT": 64,
}


async def send_pixel(dut: Drawingmanager, pixel: PixelData, last: bool = False):
    # Send a single pixel
    while not dut.pixel_s_ready.value:
        await RisingEdge(dut.clk)

    dut.pixel_s_valid.value = 1
    dut.pixel_s_data.value = pixel.to_logicarray()
    dut.pixel_s_metadata.value = PixelDataMetadata(int(last)).to_logicarray()

    await RisingEdge(dut.clk)

    dut.pixel_s_valid.value = 0
    dut.pixel_s_data.value = 0


@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_drawing_manager_states(dut: Drawingmanager):
    """Step through each DrawingManager state transition"""

    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())

    dut.rstn.value = 0
    dut.bg_draw_done.value = 0
    dut.draw_ack.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    dut.rstn.value = 1
    cocotb.log.info("Reset released, expecting BACKGROUND state")

    assert dut.bg_draw_start.value == 1, "FSM did not enter DRAWING_BACKGROUND"

    # --- Step 1.5: DRAWING_BACKGROUND -> GRAPHICS ---
    cocotb.log.info("Sending pixel data")
    await send_pixel(
        dut,
        PixelData(
            covered=1, depth=10, color=RGB(3, 7, 15), coordinate=PixelCoordinate(31, 31)
        ),
    )
    await send_pixel(
        dut,
        PixelData(
            covered=1, depth=10, color=RGB(7, 3, 15), coordinate=PixelCoordinate(32, 31)
        ),
    )
    await send_pixel(
        dut,
        PixelData(
            covered=1, depth=10, color=RGB(15, 3, 7), coordinate=PixelCoordinate(31, 32)
        ),
    )
    await send_pixel(
        dut,
        PixelData(
            covered=1, depth=10, color=RGB(15, 7, 3), coordinate=PixelCoordinate(32, 32)
        ),
        last=True,
    )

    # --- Step 2: GRAPHICS → FRAME_DONE ---
    dut.bg_draw_done.value = 1
    await RisingEdge(dut.clk)
    dut.bg_draw_done.value = 0

    await RisingEdge(dut.frame_done)
    cocotb.log.info("FSM entered FRAME_DONE")

    assert dut.frame_done.value == 1, "FSM did not enter FRAME_DONE"

    # --- Step 3: FRAME_DONE → DRAWING ---
    dut.draw_ack.value = 1
    await RisingEdge(dut.clk)
    dut.draw_ack.value = 0

    await FallingEdge(dut.frame_done)
    cocotb.log.info("FSM should be back in DRAWING")

    assert dut.frame_done.value == 0
    assert dut.bg_draw_start.value == 1
    cocotb.log.info("FSM returned to BACKGROUND successfully")

"""
This test can generate an image from the pipeline output, and
could be useful for testing
"""
import cocotb
from cocotb.clock import Clock
from stubs.pipeline import Pipeline
import numpy as np
from PIL import Image
from tools.pipeline import Producer
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge
import numpy as np
import os

from core.types.types_ import (
    Byte,
)

BUFFER_WIDTH = 160
BUFFER_HEIGHT = 120

VERILOG_MODULE = "Pipeline"
VERILOG_PARAMETERS = {
    "IGNORE_DRAW_ACK": 1,
}

CMD_BEGIN_UPLOAD = 0xA0
CMD_UPLOAD_TRIANGLE = 0xA1
CMD_ADD_MODEL_INSTANCE = 0xB0

async def make_system_clock(dut: Pipeline):
    clock = Clock(dut.clk_system, 10, "ns")
    clock.start()

    dut.rstn_system.value = 0
    await clock.cycles(2)
    dut.rstn_system.value = 1
    await clock.cycles(2)

# async def make_display_clock(dut: Pipeline):
#     clock = Clock(dut.clk_display, 1, "ns")
#     clock.start()

#     dut.rstn_display.value = 0
#     await clock.cycles(2)
#     dut.rstn_display.value = 1
#     await clock.cycles(1)

async def feed_commands(producer: Producer, inputs: list[int]):
    await producer.run()
    for cmd in inputs:
        await producer.produce(Byte(cmd))

@cocotb.test(timeout_time=5, timeout_unit="ms")
async def test_graphics_pipeline(dut: Pipeline):
    with open("../cmds.data", "rb") as f:
        INPUTS = list(f.read())

    os.makedirs("pipeline_output/", exist_ok=True)
    
    dut.rstn_display.value = 1
    await make_system_clock(dut)
    
    producer = Producer(dut, "cmd", clock_name="clk_system", processing_time=20)
    cocotb.start_soon(feed_commands(producer, INPUTS))

    write_en = dut.pipeline_tail.drawing_manager_inst.write_en
    write_addr = dut.pipeline_tail.drawing_manager_inst.write_addr
    write_data = dut.pipeline_tail.drawing_manager_inst.write_data
    frame_done = dut.pipeline_tail.drawing_manager_inst.frame_done

    # The loaded commands file has many frames, but we only read 5 of them to save time.
    for i in range(5):
        frame_buffer = np.zeros((BUFFER_HEIGHT, BUFFER_WIDTH, 3), dtype=np.uint8)

        while not frame_done.value:
            data = write_data.value.to_unsigned()
            addr = write_addr.value.to_unsigned()

            r = (data >> 8) & 0xF
            g = (data >> 4) & 0xF
            b = (data >> 0) & 0xF
            if write_en.value:
                x = addr % BUFFER_WIDTH
                y = addr // BUFFER_WIDTH
                frame_buffer[y, x, 0] = (r << 4) | r
                frame_buffer[y, x, 1] = (g << 4) | g
                frame_buffer[y, x, 2] = (b << 4) | b
            await ClockCycles(dut.clk_system, 1)
        
        img = Image.fromarray(frame_buffer, "RGB")
        img.save(f"pipeline_output/frame_{i}.png")

        # Wait for frame done to be assserted
        await FallingEdge(dut.pipeline_tail.drawing_manager_inst.frame_done)


import cocotb
from cocotb.clock import Clock
from stubs.pipelinemath import Pipelinemath
import numpy as np
from PIL import Image

from types_ import Position, RotationMatrix, Transform

BUFFER_WIDTH = 64
BUFFER_HEIGHT = 64

VERILOG_MODULE = "PipelineMath"
VERILOG_PARAMETERS = {
    # We have to specify the filepath here again
    # as the working directory is different when running
    # tests than when synthesizing for some reason...
    "BUFFER_WIDTH": BUFFER_WIDTH,
    "BUFFER_HEIGHT": BUFFER_HEIGHT,
    # "FILE_PATH": '"../static/models/teapot-low-poly"',
    # "TRIANGLE_COUNT": 160,
}

@cocotb.test(timeout_time=100, timeout_unit="ms")
async def test_pipeline_math(dut: Pipelinemath):
    clock = Clock(dut.clk, 1, "ns")
    cocotb.start_soon(clock.start())

    dut.rstn.value = 1
    dut.draw_start.value = 1
    dut.transform_d.value = Transform(
        Position(0, 0, 1.5),
        RotationMatrix(
            1,
            0,
            0,
            0,
            -1,
            0,
            0,
            0,
            1,
        ),
    ).to_logicarray()
    dut.sw_r.value = 0b0010

    await clock.cycles(1)

    cocotb.log.info(dut.draw_start.value)

    frame_buffer = np.zeros((BUFFER_HEIGHT, BUFFER_WIDTH, 3), dtype=np.uint8)

    while not dut.frame_done.value:
        data = dut.write_data.value.to_unsigned()
        addr = dut.write_addr.value.to_unsigned()

        r = (data >> 8) & 0xF
        g = (data >> 4) & 0xF
        b = (data >> 0) & 0xF

        if dut.write_en.value:
            x = addr % BUFFER_WIDTH
            y = addr // BUFFER_WIDTH
            frame_buffer[y, x, 0] = (r << 4) | r
            frame_buffer[y, x, 1] = (g << 4) | g
            frame_buffer[y, x, 2] = (b << 4) | b

            triangle_index = dut.triangle_index.value.to_unsigned()
            cocotb.log.info(
                f"Triangle {triangle_index} writing pixel at ({x}, {y}): R={r}, G={g}, B={b}"
            )

        await clock.cycles(1)

    # TODO: Have better assertions here. For example checking with a prerendered image.
    assert frame_buffer.sum() > 0, "Frame buffer should have been written to."

    image = Image.fromarray(frame_buffer, "RGB")
    image.save("graphics_pipeline_output.png")

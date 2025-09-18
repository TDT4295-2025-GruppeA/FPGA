import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock
from stubs.rasterizer import Rasterizer
import numpy as np
import os.path

from utils import numpy_to_cocotb, cocotb_to_numpy

CURRENT_DIRECTORY = os.path.dirname(__file__)

WIDTH = 32
HEIGHT = 32

CLOCK_PERIOD = 4 # steps

INTERNAL_PIXEL = "█"
EXTERNAL_PIXEL = "▒"

VERILOG_MODULE = "Rasterizer"
VERILOG_PARAMETERS = {
    "HEIGHT": f"13'd{HEIGHT}",
    "WIDTH": f"13'd{WIDTH}",
}

@cocotb.test()
async def test_rasterizer(dut: Rasterizer):
    # Setup clock which will be used to drive the simulation
    clock = Clock(dut.clk, CLOCK_PERIOD)
    clock.start()

    # Enable module
    dut.rstn.value = 1

    # Setup input
    dut.vertex0.set(numpy_to_cocotb(np.array([WIDTH//4,   0,           0])))
    dut.vertex1.set(numpy_to_cocotb(np.array([WIDTH//2-1, HEIGHT-1,    0])))
    dut.vertex2.set(numpy_to_cocotb(np.array([WIDTH-1,    HEIGHT//2,   0])))
    dut.offset_x.value = 0
    dut.offset_y.value = 0

    # Start rasterization
    dut.start.value = 1

    # Wait a bit before releasing start
    # (if its not released the rasterizer will restart)
    await Timer(CLOCK_PERIOD)
    dut.start.value = 0

    for _ in range(WIDTH * HEIGHT + 1):
        c1 = cocotb_to_numpy(dut.c1.get())
        c2 = cocotb_to_numpy(dut.c2.get())
        c3 = cocotb_to_numpy(dut.c3.get())

        dut._log.info(f"X: {dut.x.value.to_signed()}, Y: {dut.y.value.to_signed()}, State: {dut.state.value}\nC1: {c1[2]}, C2: {c2[2]}, C3: {c3[2]}")

        v1 = cocotb_to_numpy(dut.v1.get())
        v2 = cocotb_to_numpy(dut.v2.get())
        v3 = cocotb_to_numpy(dut.v3.get())

        dut._log.info(f"V1: {v1}, V2: {v2}, V3: {v3}")

        p1 = cocotb_to_numpy(dut.p1.get())
        p2 = cocotb_to_numpy(dut.p2.get())
        p3 = cocotb_to_numpy(dut.p3.get())

        dut._log.info(f"P1: {p1}, P2: {p2}, P3: {p3}")

        await Timer(CLOCK_PERIOD)

    # Create a ASCII representation of the buffer
    output = ""
    for y in range(HEIGHT):
        for x in range(WIDTH):
            index = y*WIDTH + x
            pixel_value = dut.buffer.value[index]
            symbol = INTERNAL_PIXEL if pixel_value else EXTERNAL_PIXEL
            output += symbol * 2

        if y != HEIGHT - 1:
            output += "\n"

    dut._log.info(f"Rasterizer output:\n{output}")

    assert dut.state.value == 0, "Rasterizer should be in IDLE state."
    assert INTERNAL_PIXEL in output, "Something should have been drawn."
    assert EXTERNAL_PIXEL in output, "There should be non covered pixels."

    with open(CURRENT_DIRECTORY + "/rasterizer_output.txt", "w") as f:
        f.write(output)

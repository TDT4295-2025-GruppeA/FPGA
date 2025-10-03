import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock
from stubs.rasterizer import Rasterizer
import numpy as np
import os.path

from utils import numpy_to_cocotb, cocotb_to_numpy

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

    # Create a ASCII representation of the buffer
    output = [list(EXTERNAL_PIXEL * 2 * WIDTH) for _ in range(HEIGHT)]

    # Run for enough cycles to cover the whole screen
    for _ in range(WIDTH * HEIGHT + 2):
        c1 = cocotb_to_numpy(dut.c1.get())
        c2 = cocotb_to_numpy(dut.c2.get())
        c3 = cocotb_to_numpy(dut.c3.get())

        v1 = cocotb_to_numpy(dut.v1.get())
        v2 = cocotb_to_numpy(dut.v2.get())
        v3 = cocotb_to_numpy(dut.v3.get())

        p1 = cocotb_to_numpy(dut.p1.get())
        p2 = cocotb_to_numpy(dut.p2.get())
        p3 = cocotb_to_numpy(dut.p3.get())
        
        x = dut.pixel_x.value.to_unsigned()
        y = dut.pixel_y.value.to_unsigned()

        dut._log.info(
            f"X: {x}, Y: {y}, State: {dut.state.value}\n"
            f"C1: {c1[2]}, C2: {c2[2]}, C3: {c3[2]}\n"
            f"V1: {v1}, V2: {v2}, V3: {v3}\n"
            f"P1: {p1}, P2: {p2}, P3: {p3}\n"
            f"Covered: {dut.pixel_covered.value}, Ready: {dut.ready.value}"
        )

        if dut.pixel_covered.value:
            output[y][x*2] = INTERNAL_PIXEL
            output[y][x*2+1] = INTERNAL_PIXEL

        await Timer(CLOCK_PERIOD)

    output = "\n".join("".join(row) for row in output)
    dut._log.info(f"Rasterizer output:\n{output}")

    assert dut.state.value == 0, "Rasterizer should be in IDLE state."
    assert dut.ready.value == 1, "Rasterizer should be ready after it has finnished."
    assert dut.pixel_x.value == 0, "Pixel x should be 0 after rasterization."
    assert dut.pixel_y.value == 0, "Pixel y should be 0 after rasterization."
    assert dut.pixel_covered.value == 0, "Pixel covered should be 0 after rasterization."

    assert INTERNAL_PIXEL in output, "Something should have been drawn."
    assert EXTERNAL_PIXEL in output, "There should be non covered pixels."

    # This is written to the build folder so it can be viewed after the test
    with open("rasterizer_output.txt", "w") as f:
        f.write(output)
    
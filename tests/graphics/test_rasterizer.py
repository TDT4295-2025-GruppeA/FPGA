import cocotb
from cocotb.triggers import ReadOnly
from cocotb.clock import Clock
from stubs.rasterizer import Rasterizer

from types_ import RGB, PixelData, Position, Triangle, Vertex
from utils import to_fixed

WIDTH = 120
HEIGHT = 120

CLOCK_PERIOD = 4 # steps

UNINITIALIZED_PIXEL = "?"
INTERNAL_PIXEL = "█"
EXTERNAL_PIXEL = "▒"

VERILOG_MODULE = "Rasterizer"
VERILOG_PARAMETERS = {
    "HEIGHT": HEIGHT,
    "WIDTH": WIDTH,
}

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_rasterizer(dut: Rasterizer):
    # Setup clock which will be used to drive the simulation
    clock = Clock(dut.clk, CLOCK_PERIOD)
    clock.start()

    # Enable module
    dut.rstn.value = 1

    # Wait a bit for the design to initalzie
    await clock.cycles(2)

    # Setup input
    assert dut.triangle_s_ready.value == 1, "Triangle input should be ready at start."
    dut.triangle_s_valid.value = 1
    dut.triangle_s_data.value = Triangle(
        Vertex(Position( to_fixed(0), to_fixed(0),  to_fixed(0.5)), RGB(15, 0, 0)),
        Vertex(Position( to_fixed(0), to_fixed(1),  to_fixed(0.0)), RGB(15, 0, 0)),
        Vertex(Position( to_fixed(1), to_fixed(0),  to_fixed(1.0)), RGB(15, 0, 0)),
    ).to_logicarray()


    await clock.cycles(1)
    dut.triangle_s_valid.value = 0

    # Create a ASCII representation of the buffer
    output = [list(UNINITIALIZED_PIXEL * WIDTH) for _ in range(HEIGHT)]

    # We are always ready to accept pixels
    dut.pixel_data_m_ready.value = 1

    # Run until the rasterizer is done
    await ReadOnly()
    while dut.triangle_s_ready.value == 0:
        if dut.pixel_data_m_valid.value != 1:
            await clock.cycles(1)
            continue

        pixel = PixelData.from_logicarray(dut.pixel_data_m_data.value)

        dut._log.info(f"Got pixel sample: {pixel}")

        assert 0 <= pixel.coordinate.x < WIDTH, f"Pixel x coordinate out of bounds: {pixel.coordinate.x}"
        assert 0 <= pixel.coordinate.y < HEIGHT, f"Pixel y coordinate out of bounds: {pixel.coordinate.y}"

        assert output[pixel.coordinate.y][pixel.coordinate.x] == UNINITIALIZED_PIXEL, f"Pixel ({pixel.coordinate.x}, {pixel.coordinate.y}) written to multiple times."

        output[pixel.coordinate.y][pixel.coordinate.x] = INTERNAL_PIXEL if pixel.valid else EXTERNAL_PIXEL

        await clock.cycles(1)

    # Duplicate every element to make it more visible in the output
    output = [[pixel*2 for pixel in row] for row in output]

    output = "\n".join("".join(row) for row in output)
    dut._log.info(f"Rasterizer output:\n{output}")

    # This is written to the build folder so it can be viewed after the test
    with open("rasterizer_output.txt", "w") as f:
        f.write(output)

    assert UNINITIALIZED_PIXEL not in output, "All pixels should have been written to."
    assert INTERNAL_PIXEL in output, "Something should have been drawn."
    assert EXTERNAL_PIXEL in output, "There should be non covered pixels."

    
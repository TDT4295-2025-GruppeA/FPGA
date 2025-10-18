import cocotb
from cocotb.clock import Clock
from stubs.rasterizer import Rasterizer

from types_ import RGB, PixelData, PixelDataMetadata, Position, Triangle, Vertex

VIEWPORT_WIDTH = 120
VIEWPORT_HEIGHT = 120

CLOCK_PERIOD = 2 # ns

UNINITIALIZED_PIXEL = "?"
SHADE_PIXELS = ["█", "▓", "▒", "░"]
EMPTY_PIXEL = " "
OVERFLOW_PIXEL = "+"
UNDERFLOW_PIXEL = "-"

VERILOG_MODULE = "Rasterizer"
VERILOG_PARAMETERS = {
    "VIEWPORT_WIDTH": VIEWPORT_WIDTH,
    "VIEWPORT_HEIGHT": VIEWPORT_HEIGHT,
}


@cocotb.test(timeout_time=100, timeout_unit="us")
async def test_rasterizer(dut: Rasterizer):
    # Setup clock which will be used to drive the simulation
    clock = Clock(dut.clk, CLOCK_PERIOD, unit="ns")
    clock.start()

    # Enable module
    dut.rstn.value = 1

    await clock.cycles(2)

    # We are always ready to accept pixels
    dut.pixel_data_m_ready.value = 1

    # Wait a bit for the design to initialize
    await clock.cycles(2)

    # Setup input
    assert dut.triangle_s_ready.value == 1, "Triangle input should be ready at start."
    dut.triangle_s_valid.value = 1
    dut.triangle_s_data.value = Triangle(
        # Vertex(Position(0.10, 0.05, 0.00), RGB(15, 0, 0)),
        # Vertex(Position(0.85, 0.10, 0.50), RGB(15, 0, 0)),
        # Vertex(Position(0.50, 0.95, 1.00), RGB(15, 0, 0)),
        Vertex(Position(0.0, 0.0, 0.0), RGB(15, 0, 0)),
        Vertex(Position(1.0, 0.0, 0.0), RGB(15, 0, 0)),
        Vertex(Position(1.0, 1.0, 1.0), RGB(15, 0, 0)),
    ).to_logicarray()

    await clock.cycles(1)
    dut.triangle_s_valid.value = 0

    # Create a ASCII representation of the buffer
    covered_output = [
        list(UNINITIALIZED_PIXEL * VIEWPORT_WIDTH) for _ in range(VIEWPORT_HEIGHT)
    ]
    depth_output = [[0.0] * VIEWPORT_WIDTH for _ in range(VIEWPORT_HEIGHT)]

    # Run until the rasterizer is done
    last = False
    while not last:
        if dut.pixel_data_m_valid.value != 1:
            await clock.cycles(1)
            continue

        metadata = PixelDataMetadata.from_logicarray(dut.pixel_data_m_metadata.value)
        last = metadata.last == 1

        pixel = PixelData.from_logicarray(dut.pixel_data_m_data.value)

        if pixel.covered == 1:
            dut._log.info(f"Got pixel sample: {pixel}")

        assert (
            0 <= pixel.coordinate.x < VIEWPORT_WIDTH
        ), f"Pixel x coordinate out of bounds: {pixel.coordinate.x}"
        assert (
            0 <= pixel.coordinate.y < VIEWPORT_HEIGHT
        ), f"Pixel y coordinate out of bounds: {pixel.coordinate.y}"

        assert (
            covered_output[pixel.coordinate.y][pixel.coordinate.x]
            == UNINITIALIZED_PIXEL
        ), f"Pixel ({pixel.coordinate.x}, {pixel.coordinate.y}) written to multiple times."

        shade_index = int(round((1.0 - pixel.depth) * (len(SHADE_PIXELS) - 1)))

        pixel_character = EMPTY_PIXEL

        if pixel.covered == 1:
            if shade_index < 0:
                pixel_character = UNDERFLOW_PIXEL
            elif shade_index >= len(SHADE_PIXELS):
                pixel_character = OVERFLOW_PIXEL
            else:
                pixel_character = SHADE_PIXELS[shade_index]

        covered_output[pixel.coordinate.y][pixel.coordinate.x] = pixel_character
        depth_output[pixel.coordinate.y][pixel.coordinate.x] = pixel.depth

        await clock.cycles(1)

    # Add a border
    covered_output = (
        ["#" * (VIEWPORT_WIDTH + 2)] +
        ["#" + "".join(row) + "#" for row in covered_output] +
        ["#" * (VIEWPORT_WIDTH + 2)]
    )

    # Duplicate every element to make it more visible in the output
    covered_output = [[pixel * 2 for pixel in row] for row in covered_output]

    covered_output = "\n".join("".join(row) for row in covered_output)
    dut._log.info(f"Rasterizer output:\n{covered_output}")

    # This is written to the build folder so it can be viewed after the test
    with open("rasterizer_output.txt", "w") as f:
        f.write(covered_output)

    assert (
        UNINITIALIZED_PIXEL not in covered_output
    ), "All pixels should have been written to."
    assert all(
        shade_pixel in covered_output for shade_pixel in SHADE_PIXELS
    ), "Something should have been drawn."
    assert EMPTY_PIXEL in covered_output, "There should be non covered pixels."

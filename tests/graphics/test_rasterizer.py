import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ReadOnly
from stubs.rasterizer import Rasterizer

from types_ import RGB, PixelData, PixelDataMetadata, Position, Triangle, TriangleMetadata, Vertex

VIEWPORT_WIDTH = 65
VIEWPORT_HEIGHT = 65

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

TEST_TRIANGLES = [
    Triangle(
        Vertex(Position(-0.80, -0.90, 0.00), RGB(15, 0, 0)),
        Vertex(Position(0.50, -0.70, 0.00), RGB(15, 0, 0)),
        Vertex(Position(0.00, 0.50, 1.00), RGB(15, 0, 0)),
    ),
    Triangle(
        Vertex(Position(-0.20, 0.00, 0.00), RGB(15, 0, 0)),
        Vertex(Position(1.00, -0.20, 1.00), RGB(15, 0, 0)),
        Vertex(Position(1.00, 0.80, 0.00), RGB(15, 0, 0)),
    ),
    Triangle(
        Vertex(Position(-1.00, 0.50, 0.50), RGB(15, 0, 0)),
        Vertex(Position(-0.50, 1.00, 0.50), RGB(15, 0, 0)),
        Vertex(Position(-1.00, 1.00, 0.50), RGB(15, 0, 0)),
    ),
    Triangle(
        Vertex(Position(-1.00, 0.50, 1.00), RGB(15, 0, 0)),
        Vertex(Position(-0.50, 0.50, 1.00), RGB(15, 0, 0)),
        Vertex(Position(-0.50, 1.00, 1.00), RGB(15, 0, 0)),
    ),
    Triangle(
        Vertex(Position(-1.00, 0.50, 0.00), RGB(15, 0, 0)),
        Vertex(Position(-0.50, 0.00, 0.00), RGB(15, 0, 0)),
        Vertex(Position(-0.50, 0.50, 0.00), RGB(15, 0, 0)),
    ),
    Triangle(
        Vertex(Position(-1.00, -1.00, 0.75), RGB(15, 0, 0)),
        Vertex(Position(-0.40, -1.00, 0.00), RGB(15, 0, 0)),
        Vertex(Position(-1.00, -0.40, 1.00), RGB(15, 0, 0)),
    ),
    Triangle(
        Vertex(Position(1.00, -1.00, 1.00), RGB(15, 0, 0)),
        Vertex(Position(1.00, -0.40, 1.00), RGB(15, 0, 0)),
        Vertex(Position(0.40, -0.40, 1.00), RGB(15, 0, 0)),
    ),
    Triangle(
        Vertex(Position(1.00, -1.00, 0.00), RGB(15, 0, 0)),
        Vertex(Position(0.40, -0.40, 0.00), RGB(15, 0, 0)),
        Vertex(Position(0.40, -1.00, 0.00), RGB(15, 0, 0)),
    ),
]

async def feed_triangles(clock: Clock, dut: Rasterizer):
    for i, triangle in enumerate(TEST_TRIANGLES):
        last = i == len(TEST_TRIANGLES) - 1

        cocotb.log.info(f"Feeding triangle {i}: {triangle}")

        # Set triangle data on input.
        dut.triangle_s_valid.value = 1
        dut.triangle_s_data.value = triangle.to_logicarray()
        dut.triangle_s_metadata.value = TriangleMetadata(last).to_logicarray()

        # Hold data until ready is high.
        await ReadOnly()
        while not dut.triangle_s_ready.value:
            await clock.cycles(1)
            await ReadOnly()
        
        # Wait one cycle for transaction to complete.
        await clock.cycles(1)
        dut.triangle_s_valid.value = 0

@cocotb.test(timeout_time=100, timeout_unit="us")
async def test_rasterizer(dut: Rasterizer):
    # Setup clock which will be used to drive the simulation
    clock = Clock(dut.clk, CLOCK_PERIOD, unit="ns")
    clock.start()

    # Enable module
    dut.rstn.value = 1

    # Wait a bit for the design to initialize
    await clock.cycles(2)

    # Feed triangles
    cocotb.start_soon(feed_triangles(clock, dut))

    # Create a ASCII representation of the buffer
    covered_output = [
        list(UNINITIALIZED_PIXEL * VIEWPORT_WIDTH) for _ in range(VIEWPORT_HEIGHT)
    ]
    depth_output = [[0.0] * VIEWPORT_WIDTH for _ in range(VIEWPORT_HEIGHT)]

    # We are always ready to receive data
    dut.pixel_data_m_ready.value = 1

    # Run until the rasterizer is done
    last = False
    while not last:
        if dut.pixel_data_m_valid.value != 1:
            await clock.cycles(1)
            continue

        metadata = PixelDataMetadata.from_logicarray(dut.pixel_data_m_metadata.value)
        if metadata.last == 1:
            last = True

        pixel = PixelData.from_logicarray(dut.pixel_data_m_data.value)

        if pixel.covered == 1:
            dut._log.info(f"Got pixel sample: {pixel}")

        assert (
            0 <= pixel.coordinate.x < VIEWPORT_WIDTH
        ), f"Pixel x coordinate out of bounds: {pixel.coordinate.x}"
        assert (
            0 <= pixel.coordinate.y < VIEWPORT_HEIGHT
        ), f"Pixel y coordinate out of bounds: {pixel.coordinate.y}"

        # Skip non covered pixels.
        if not pixel.covered:
            # If nothing has been drawn at that location yet, set it to an empty pixel.
            if covered_output[pixel.coordinate.y][pixel.coordinate.x] == UNINITIALIZED_PIXEL:
                covered_output[pixel.coordinate.y][pixel.coordinate.x] = EMPTY_PIXEL
            await clock.cycles(1)
            continue

        # If the output is further away than what has already been drawn, skip it.
        if depth_output[pixel.coordinate.y][pixel.coordinate.x] > pixel.depth:
            await clock.cycles(1)
            continue

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

    # Add a border to the output
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
    ), "All shades should have been drawn."
    assert EMPTY_PIXEL in covered_output, "There should be non covered pixels."

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ReadOnly
from stubs.rasterizer import Rasterizer
import numpy as np
from PIL import Image

from core.types.types_ import (
    RGB,
    PixelData,
    PixelDataMetadata,
    ProjectedPosition,
    ProjectedVertex,
    ProjectedTriangle,
    TriangleMetadata,
)

VIEWPORT_WIDTH = 64
VIEWPORT_HEIGHT = 64

CLOCK_PERIOD = 2  # ns

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
    ProjectedTriangle(
        ProjectedVertex(ProjectedPosition( 0,  0, 0.00), RGB(15, 0, 0)),
        ProjectedVertex(ProjectedPosition(15,  0, 0.00), RGB(0, 15, 0)),
        ProjectedVertex(ProjectedPosition(15, 15, 1.00), RGB(0, 0, 15)),
    ),
    ProjectedTriangle(
        ProjectedVertex(ProjectedPosition(49, 49, 1.00), RGB(15, 0, 0)),
        ProjectedVertex(ProjectedPosition(63, 49, 0.00), RGB(0, 15, 0)),
        ProjectedVertex(ProjectedPosition(63, 63, 0.00), RGB(0, 0, 15)),
    ),
    ProjectedTriangle(
        ProjectedVertex(ProjectedPosition( 0,  0, 0.50), RGB(15, 0, 0)),
        ProjectedVertex(ProjectedPosition(63, 63, 1.00), RGB(0, 0, 15)),
        ProjectedVertex(ProjectedPosition( 0, 63, 0.00), RGB(0, 15, 0)),
    ),
    # Triangle(
    #     ProjectedVertex(Position(-0.80, -0.90, 0.00), RGB(15, 0, 0)),
    #     ProjectedVertex(Position(0.50, -0.70, 0.00), RGB(0, 15, 0)),
    #     ProjectedVertex(Position(0.00, 0.50, 1.00), RGB(0, 0, 15)),
    # ),
    # Triangle(
    #     ProjectedVertex(Position(-0.20, 0.00, 0.00), RGB(15, 0, 0)),
    #     ProjectedVertex(Position(1.00, -0.20, 1.00), RGB(15, 15, 0)),
    #     ProjectedVertex(Position(1.00, 0.80, 0.00), RGB(15, 15, 15)),
    # ),
    # Triangle(
    #     ProjectedVertex(Position(-1.00, 0.50, 0.50), RGB(15, 15, 15)),
    #     ProjectedVertex(Position(-0.50, 1.00, 0.50), RGB(15, 15, 0)),
    #     ProjectedVertex(Position(-1.00, 1.00, 0.50), RGB(15, 0, 0)),
    # ),
    # Triangle(
    #     ProjectedVertex(Position(-1.00, 0.50, 1.00), RGB(15, 0, 15)),
    #     ProjectedVertex(Position(-0.50, 0.50, 1.00), RGB(15, 0, 15)),
    #     ProjectedVertex(Position(-0.50, 1.00, 1.00), RGB(15, 0, 15)),
    # ),
    # Triangle(
    #     ProjectedVertex(Position(-1.00, 0.50, 0.00), RGB(15, 0, 15)),
    #     ProjectedVertex(Position(-0.50, 0.00, 0.00), RGB(15, 15, 15)),
    #     ProjectedVertex(Position(-0.50, 0.50, 0.00), RGB(15, 0, 15)),
    # ),
    # Triangle(
    #     ProjectedVertex(Position(-1.00, -1.00, 0.75), RGB(15, 0, 0)),
    #     ProjectedVertex(Position(-0.40, -1.00, 0.00), RGB(0, 0, 15)),
    #     ProjectedVertex(Position(-1.00, -0.40, 1.00), RGB(0, 15, 0)),
    # ),
    # Triangle(
    #     ProjectedVertex(Position(1.00, -1.00, 1.00), RGB(15, 0, 0)),
    #     ProjectedVertex(Position(1.00, -0.40, 1.00), RGB(7, 7, 0)),
    #     ProjectedVertex(Position(0.40, -0.40, 1.00), RGB(3, 3, 3)),
    # ),
    # Triangle(
    #     ProjectedVertex(Position(1.00, -1.00, 0.00), RGB(15, 0, 0)),
    #     ProjectedVertex(Position(0.40, -0.40, 0.00), RGB(0, 10, 10)),
    #     ProjectedVertex(Position(0.40, -1.00, 0.00), RGB(5, 5, 5)),
    # ),
    # Triangle(
    #     ProjectedVertex(Position(0.0022135764, 0.7012346, 1.00), RGB(15, 10, 15)),
    #     ProjectedVertex(Position(0.0445375153, 0.7032100, 1.00), RGB(15, 15, 10)),
    #     ProjectedVertex(Position(0.0412342314, 0.7554272, 1.00), RGB(10, 15, 15)),
    # ),
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


@cocotb.test(timeout_time=1, timeout_unit="ms")
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

    # Buffers to hold the output data
    color_buffer = np.zeros((VIEWPORT_HEIGHT, VIEWPORT_WIDTH, 3), dtype=np.uint8)
    depth_buffer = np.zeros((VIEWPORT_HEIGHT, VIEWPORT_WIDTH), dtype=np.float32)

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
            await clock.cycles(1)
            continue

        # If the output is further away than what has already been drawn, skip it.
        if depth_buffer[pixel.coordinate.y, pixel.coordinate.x] > pixel.depth:
            await clock.cycles(1)
            continue

        color_buffer[pixel.coordinate.y, pixel.coordinate.x] = (
            (pixel.color.r << 4) | pixel.color.r,
            (pixel.color.g << 4) | pixel.color.g,
            (pixel.color.b << 4) | pixel.color.b,
        )
        depth_buffer[pixel.coordinate.y, pixel.coordinate.x] = pixel.depth

        await clock.cycles(1)

    img = Image.fromarray(color_buffer, "RGB")
    img.save("rasterizer_color_output.png")

    img = Image.fromarray((depth_buffer * 255).astype(np.uint8), "L")
    img.save("rasterizer_depth_output.png")

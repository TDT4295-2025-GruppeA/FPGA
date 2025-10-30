import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ReadOnly
import numpy as np

from types_ import PixelData, PixelCoordinate, RGB

CLOCK_PERIOD = 2  # ns
BUFFER_WIDTH = 16
BUFFER_HEIGHT = 12
NEAR_PLANE = 1.0
FAR_PLANE = 10.0

VERILOG_MODULE = "DepthBuffer"
VERILOG_PARAMETERS = {
    "BUFFER_WIDTH": BUFFER_WIDTH,
    "BUFFER_HEIGHT": BUFFER_HEIGHT,
    "NEAR_PLANE": NEAR_PLANE,
    "FAR_PLANE": FAR_PLANE,
}


def make_pixel(x, y, depth, color=(15, 15, 15)):
    """Helper to create a PixelData object."""
    return PixelData(
        coordinate=PixelCoordinate(x, y),
        color=RGB(*color),
        depth=depth,
        covered=1,
    )


async def write_pixel(clk, dut, addr, pixel):
    """Feed a single write transaction to the depth buffer."""
    dut.write_en_in.value = 1
    dut.write_addr_in.value = addr
    dut.write_pixel_in.value = pixel.to_logicarray()

    await RisingEdge(dut.clk)
    dut.write_en_in.value = 0


async def clear_buffer(clk, dut):
    """Clear the entire z-buffer by asserting clear_req sequentially."""
    dut.clear_req.value = 1
    for addr in range(BUFFER_WIDTH * BUFFER_HEIGHT):
        dut.clear_addr.value = addr
        await RisingEdge(dut.clk)
    dut.clear_req.value = 0
    await RisingEdge(dut.clk)


async def await_pipeline_latency(dut, cycles=3):
    """Wait a few cycles for pipeline data to propagate through s1 -> s2 -> output."""
    for _ in range(cycles):
        await RisingEdge(dut.clk)


@cocotb.test(timeout_time=1, timeout_unit="ms")
async def test_depth_buffer_basic(dut):
    """Basic sanity test: ensure near/far clipping and depth comparison work."""

    # Clock setup
    clock = Clock(dut.clk, CLOCK_PERIOD, unit="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rstn.value = 0
    dut.write_en_in.value = 0
    dut.clear_req.value = 0
    await RisingEdge(dut.clk)
    dut.rstn.value = 1
    await RisingEdge(dut.clk)

    # Clear the depth buffer
    await clear_buffer(dut.clk, dut)

    # Write three pixels to the same address (simulate overdraw)
    addr = 10

    pixel_far = make_pixel(1, 1, depth=1 / 8.0)  # 8m -> 0.125 reciprocal depth
    pixel_near = make_pixel(1, 1, depth=1 / 2.0)  # 2m -> 0.5 reciprocal depth
    pixel_too_far = make_pixel(1, 1, depth=1 / 11.0)  # 11m -> 0.0909 (too far)
    pixel_too_near = make_pixel(1, 1, depth=1 / 0.5)  # 0.5m -> 2.0 (too near)

    # Step 1: Write a valid far pixel
    await write_pixel(dut.clk, dut, addr, pixel_far)
    await await_pipeline_latency(dut)

    # Step 2: Attempt to write a pixel behind near plane (ignored)
    await write_pixel(dut.clk, dut, addr, pixel_too_near)
    await await_pipeline_latency(dut)

    # Step 3: Attempt to write one beyond far plane (ignored)
    await write_pixel(dut.clk, dut, addr, pixel_too_far)
    await await_pipeline_latency(dut)

    # Step 4: Attempt to write a closer pixel (should replace)
    await write_pixel(dut.clk, dut, addr, pixel_near)
    await await_pipeline_latency(dut)

    # Check that last written pixel depth matches the near pixel (the closest)
    written_pixel = PixelData.from_logicarray(dut.write_pixel_out.value)
    assert np.isclose(
        written_pixel.depth, pixel_near.depth, atol=1e-6
    ), f"Expected nearest pixel depth {pixel_near.depth}, got {written_pixel.depth}"


@cocotb.test(timeout_time=1, timeout_unit="ms")
async def test_depth_buffer_clipping(dut):
    """Ensure near/far clipping is correctly applied."""

    clock = Clock(dut.clk, CLOCK_PERIOD, unit="ns")
    cocotb.start_soon(clock.start())

    dut.rstn.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rstn.value = 1
    await RisingEdge(dut.clk)

    await clear_buffer(dut.clk, dut)

    addr = 5

    # Pixel inside frustum
    pixel_valid = make_pixel(1, 1, depth=1 / 5.0)  # 5m -> 0.2 (inside range [0.1, 1.0])
    # Pixel too far and too near
    pixel_near = make_pixel(1, 1, depth=1 / 0.5)  # 0.5m -> 2.0 (> 1.0, too near)
    pixel_far = make_pixel(1, 1, depth=1 / 12.0)  # 12m -> 0.083 (< 0.1, too far)

    # Feed each and check write enable
    for pixel, expected in [
        (pixel_valid, True),
        (pixel_near, False),
        (pixel_far, False),
    ]:
        await cocotb.triggers.Timer(1, "ns")
        await write_pixel(dut.clk, dut, addr, pixel)

        # Wait for pipeline to settle
        await await_pipeline_latency(dut, cycles=1)

        await ReadOnly()

        assert dut.write_en_out.value == int(
            expected
        ), f"Depth {pixel.depth} -> write_en_out={dut.write_en_out.value}, expected {expected}"

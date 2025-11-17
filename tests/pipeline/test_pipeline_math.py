import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import numpy as np
from PIL import Image

from core.types.types_ import (
    PixelData,
    PixelDataMetadata,
    Position,
    Vertex,
    Triangle,
    RotationMatrix,
    Transform,
    TriangleTransform,
    PipelineEntry,
    Last,
    TriangleTransformMeta,
    RGB,
)
from stubs.pipelinemath import Pipelinemath

BUFFER_WIDTH = 160
BUFFER_HEIGHT = 120

VERILOG_MODULE = "PipelineMath"
VERILOG_PARAMETERS = {
    "BUFFER_WIDTH": BUFFER_WIDTH,
    "BUFFER_HEIGHT": BUFFER_HEIGHT
}

async def reset(dut):
    dut.rstn.value = 0
    await Timer(20, "ns")
    dut.rstn.value = 1
    await RisingEdge(dut.clk)


@cocotb.test(timeout_time=1, timeout_unit="ms")
async def test_pipeline_math(dut: Pipelinemath):
    """Test that PipelineMath passes through data unchanged with identity transform."""
    # Set up a 10ns clock
    cocotb.start_soon(Clock(dut.clk, 10, "ns").start())
    await reset(dut)

    # Create identity transform
    identity_rot = RotationMatrix(
        m00=1.0, m01=0.0, m02=0.0, m10=0.0, m11=1.0, m12=0.0, m20=0.0, m21=0.0, m22=1.0
    )
    identity_pos = Position(0.0, 0.0, 0.0)
    identity_transform = Transform(position=identity_pos, rotation=identity_rot)

    # Create a test triangle
    tri_in = Triangle(
        Vertex(position=Position(-1000.0,    0.0, 1000.0), color=RGB(15,  0,  0)),
        Vertex(position=Position( 1000.0,    0.0, 1000.0), color=RGB(15, 15, 15)),
        Vertex(position=Position( 1000.0, 1000.0, 1000.0), color=RGB(15, 15,  0)),
    )

    tri_tf_in = PipelineEntry(
        triangle=tri_in,
        model_transform=identity_transform,
        camera_transform=identity_transform,
    )
    tri_tf_meta_in = Last(last=1)

    # Drive input
    dut.triangle_tf_s_valid.value = 1
    dut.triangle_tf_s_data.value = tri_tf_in.to_logicarray()
    dut.triangle_tf_s_metadata.value = tri_tf_meta_in.to_logicarray()

    # Drive output ready so rasterizer outputs
    dut.pixel_data_m_ready.value = 1

    # Wait until pipeline accepts input
    while not dut.triangle_tf_s_ready.value:
        await RisingEdge(dut.clk)

    await RisingEdge(dut.clk)

    dut.triangle_tf_s_valid.value = 0  # Deassert valid after input is accepted

    # Wait for transform to finish processing
    while not dut.transform_camera_valid.value:
        await RisingEdge(dut.clk)
    cocotb.log.info("Projection produced output")

    # Wait for backface_culler to finish processing
    while not dut.backface_culler_projection_valid.value:
        await RisingEdge(dut.clk)
    cocotb.log.info("Projection produced output")

    # Wait for projection to finish processing
    while not dut.projection_rasterizer_valid.value:
        await RisingEdge(dut.clk)
    cocotb.log.info("Rasterizer received projected triangle")

    # Wait for rasterizer to finish processing
    while not dut.pixel_data_m_valid.value:
        await RisingEdge(dut.clk)
    cocotb.log.info("Pipeline produced pixel data output")

    frame_buffer = np.zeros((BUFFER_HEIGHT, BUFFER_WIDTH, 3), dtype=np.uint8)

    last = False
    while not last:
        if not dut.pixel_data_m_valid.value:
            await RisingEdge(dut.clk)
            continue

        pixel = PixelData.from_logicarray(dut.pixel_data_m_data.value)
        metadata = PixelDataMetadata.from_logicarray(dut.pixel_data_m_metadata.value)

        cocotb.log.info(f"Received pixel at ({pixel.coordinate.x}, {pixel.coordinate.y}) with color ({pixel.color.r}, {pixel.color.g}, {pixel.color.b})")

        if metadata.last:
            last = True

        if not pixel.covered:
            await RisingEdge(dut.clk)
            continue

        x = int(pixel.coordinate.x)
        y = int(pixel.coordinate.y)

        frame_buffer[y, x, :] = (
            pixel.color.r << 4, 
            pixel.color.g << 4,
            pixel.color.b << 4
        )

        await RisingEdge(dut.clk)

    image = Image.fromarray(frame_buffer, "RGB")
    image.save("pipeline_math_output.png")

    assert np.any(frame_buffer), "Frame buffer is empty, expected drawn triangle."

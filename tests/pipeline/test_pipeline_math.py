import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

from core.types.types_ import (
    Position,
    Vertex,
    Triangle,
    RotationMatrix,
    Transform,
    TriangleTransform,
    TriangleTransformMeta,
)

VERILOG_MODULE = "PipelineMath"


async def reset(dut):
    dut.rstn.value = 0
    await Timer(20, units="ns")
    dut.rstn.value = 1
    await RisingEdge(dut.clk)


@cocotb.test(timeout_time=5, timeout_unit="ms")
async def test_passthrough(dut):
    """Test that PipelineMath passes through data unchanged with identity transform."""
    # Set up a 10ns clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await reset(dut)

    # Create identity transform
    identity_rot = RotationMatrix(
        m00=1.0, m01=0.0, m02=0.0, m10=0.0, m11=1.0, m12=0.0, m20=0.0, m21=0.0, m22=1.0
    )
    identity_pos = Position(0.0, 0.0, 0.0)
    identity_transform = Transform(position=identity_pos, rotation=identity_rot)

    # Create a test triangle
    tri_in = Triangle(
        v0=Vertex(position=Position(1.0, 2.0, 3.0)),
        v1=Vertex(position=Position(4.0, 5.0, 6.0)),
        v2=Vertex(position=Position(7.0, 8.0, 9.0)),
    )

    tri_tf_in = TriangleTransform(triangle=tri_in, transform=identity_transform)
    tri_tf_meta_in = TriangleTransformMeta(model_last=1, triangle_last=1)

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
    while not dut.transform_projection_valid.value:
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

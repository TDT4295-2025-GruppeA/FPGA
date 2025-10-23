import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
import math

from tools.pipeline import Producer, Consumer
from logic_object import LogicObject, LogicField, UInt
from types_ import Triangle, Vertex, Position, RGB

VERILOG_MODULE = "Projection"
FOCAL_LENGTH = 0.10

# ---------------------------------------------------------------------
# Helper LogicObject for 1-bit metadata
# ---------------------------------------------------------------------
class Bit(LogicObject):
    bit: int = LogicField(UInt(1))  # type: ignore


# ---------------------------------------------------------------------
# Clock / Reset helper
# ---------------------------------------------------------------------
async def make_clock(dut):
    cocotb.start_soon(Clock(dut.clk, 10, "ns").start())
    dut.rstn.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rstn.value = 1
    await RisingEdge(dut.clk)


# ---------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------

@cocotb.test()
async def test_single_projection(dut):
    """Test projection of one triangle."""
    await make_clock(dut)

    producer = Producer(dut, "triangle", has_metadata=False, signal_style="ms")
    consumer = Consumer(dut, "projected_triangle", Triangle, None, signal_style="ms")
    await producer.run()
    await consumer.run()

    # Input triangle in camera space
    tri_in = Triangle(
        Vertex(Position(1, 2, 4), RGB(1, 2, 3)),
        Vertex(Position(2, 1, 2), RGB(4, 5, 6)),
        Vertex(Position(3, 4, 1), RGB(7, 8, 9)),
    )

    await producer.produce(tri_in, None)
    await RisingEdge(dut.projected_triangle_m_valid)
    tri_out, _ = await consumer.consume()

    # Check reciprocal depth and projection math
    for v_in, v_out in zip((tri_in.v0, tri_in.v1, tri_in.v2),
                       (tri_out.v0, tri_out.v1, tri_out.v2)):
        z = float(v_in.position.z)
        w_expected = 1 / z
        x_expected =  FOCAL_LENGTH * (v_in.position.x * w_expected)
        y_expected =  FOCAL_LENGTH * (v_in.position.y * w_expected)

        assert math.isclose(float(v_out.position.x), x_expected, abs_tol=1e-2)
        assert math.isclose(float(v_out.position.y), y_expected, abs_tol=1e-2)
        assert math.isclose(float(v_out.position.z), w_expected, abs_tol=1e-2)

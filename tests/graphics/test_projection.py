import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

from tools.utils import TOTAL_WIDTH, to_fixed, within_tolerance
from tools.pipeline import Producer, Consumer
from tools.logic_object import LogicObject, LogicField, UInt
from core.types.types_ import Triangle, Vertex, Position, RGB

FOCAL_LENGTH = 0.10

VERILOG_MODULE = "Projection"
VERILOG_PARAMETERS = {
    "FOCAL_LENGTH": f"{FOCAL_LENGTH}",
}


async def make_clock(dut):
    cocotb.start_soon(Clock(dut.clk, 10, "ns").start())
    dut.rstn.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rstn.value = 1
    await RisingEdge(dut.clk)


TEST_TRIANGLES = [
    Triangle(
        Vertex(Position(1, 2, 4), RGB(1, 2, 3)),
        Vertex(Position(2, 1, 2), RGB(4, 5, 6)),
        Vertex(Position(3, 4, 1), RGB(7, 8, 9)),
    ),
    Triangle(
        Vertex(Position(-1, -2, 5), RGB(5, 10, 15)),
        Vertex(Position(-2, -1, 10), RGB(15, 10, 5)),
        Vertex(Position(-3, -4, 2), RGB(10, 10, 10)),
    ),
    Triangle(
        Vertex(Position(0, 0, 1), RGB(0xF, 0xF, 0xF)),
        Vertex(Position(1, 1, 1), RGB(0x8, 0x8, 0x8)),
        Vertex(Position(-1, -1, 1), RGB(0, 0, 0)),
    ),
]


async def feed_triangles(producer: Producer, triangles):
    for triangle in triangles:
        await producer.produce(triangle)


@cocotb.test(timeout_time=1, timeout_unit="us")
async def test_projection(dut):
    """Test projection of multiple triangles."""
    await make_clock(dut)

    producer = Producer(dut, "triangle", has_metadata=False, signal_style="ms")
    consumer = Consumer(dut, "projected_triangle", Triangle, None, signal_style="ms")

    await producer.run()
    await consumer.run()

    await feed_triangles(producer, TEST_TRIANGLES)

    for triangle_in in TEST_TRIANGLES:
        triangle_out, _ = await consumer.consume()

        cocotb.log.info(f"Input Triangle: {triangle_in}")
        cocotb.log.info(f"Projected Triangle: {triangle_out}")

        # Check reciprocal depth and projection math
        for v_in, v_out in zip(
            (triangle_in.v0, triangle_in.v1, triangle_in.v2),
            (triangle_out.v0, triangle_out.v1, triangle_out.v2),
        ):
            z = v_in.position.z
            w_expected = 1 / z
            x_expected = FOCAL_LENGTH * (v_in.position.x * w_expected)
            y_expected = FOCAL_LENGTH * (v_in.position.y * w_expected)

            assert within_tolerance(v_out.position.x, x_expected, 2)
            assert within_tolerance(v_out.position.y, y_expected, 2)
            assert within_tolerance(v_out.position.z, w_expected, 2)

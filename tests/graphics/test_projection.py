import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

from tools.utils import within_tolerance
from tools.pipeline import Producer, Consumer
from core.types.types_ import ProjectedTriangle, Triangle, Vertex, Position, RGB

FOCAL_LENGTH = 0.5
VIEWPORT_WIDTH = 160
VIEWPORT_HEIGHT = 120
ASPECT_RATIO = VIEWPORT_WIDTH / VIEWPORT_HEIGHT

VERILOG_MODULE = "Projection"
VERILOG_PARAMETERS = {
    "FOCAL_LENGTH": f"{FOCAL_LENGTH}",
    "VIEWPORT_WIDTH": VIEWPORT_WIDTH,
    "VIEWPORT_HEIGHT": VIEWPORT_HEIGHT,
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
        cocotb.log.info(f"Feeding Triangle: {triangle}")
        await producer.produce(triangle)


@cocotb.test(timeout_time=10, timeout_unit="us")
async def test_projection(dut):
    """Test projection of multiple triangles."""
    await make_clock(dut)

    producer = Producer(dut, "triangle")
    consumer = Consumer(dut, "projected_triangle", ProjectedTriangle, None)

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
            x_expected = FOCAL_LENGTH * VIEWPORT_WIDTH * (v_in.position.x * w_expected) + VIEWPORT_WIDTH / 2
            y_expected = FOCAL_LENGTH * VIEWPORT_HEIGHT * ASPECT_RATIO * (v_in.position.y * w_expected) + VIEWPORT_HEIGHT / 2

            cocotb.log.info(f"{v_in.position.x}, {v_in.position.y}, {v_in.position.z}")
            cocotb.log.info(f"{x_expected}, {y_expected}, {w_expected}")

            assert within_tolerance(v_out.position.x, x_expected, 2)
            assert within_tolerance(v_out.position.y, y_expected, 2)
            assert within_tolerance(v_out.position.z, w_expected, 2)

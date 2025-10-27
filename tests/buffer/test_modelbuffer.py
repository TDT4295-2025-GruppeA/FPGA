import cocotb
from cocotb.triggers import ClockCycles

from stubs.modelbuffer import Modelbuffer
from types_ import (
    Triangle,
    ModelBufferWrite,
    ModelBufferRead,
    TriangleMeta,
)
from tools.pipeline import Producer, Consumer
from utilities.constructors import make_triangle, make_clock

VERILOG_MODULE = "ModelBuffer"

VERILOG_PARAMETERS = {
    "MAX_TRIANGLE_COUNT": 100,
    "MAX_MODEL_COUNT": 10,
}


INPUTS = [
    ModelBufferWrite(0, make_triangle(1)),
    ModelBufferWrite(0, make_triangle(2)),
    ModelBufferWrite(0, make_triangle(3)),
    ModelBufferWrite(1, make_triangle(4)),
    ModelBufferWrite(1, make_triangle(5)),
    ModelBufferWrite(1, make_triangle(6)),
    ModelBufferWrite(1, make_triangle(7)),
    ModelBufferWrite(1, make_triangle(8)),
    ModelBufferWrite(2, make_triangle(9)),
    ModelBufferWrite(3, make_triangle(10)),
    ModelBufferWrite(3, make_triangle(11)),
    ModelBufferWrite(3, make_triangle(12)),
]

READ_INPUTS = [
    ModelBufferRead(0, 0),
    ModelBufferRead(0, 1),
    ModelBufferRead(0, 2),
    ModelBufferRead(1, 0),
    ModelBufferRead(1, 1),
    ModelBufferRead(1, 2),
    ModelBufferRead(1, 3),
    ModelBufferRead(1, 4),
    ModelBufferRead(2, 0),
    ModelBufferRead(3, 0),
    ModelBufferRead(3, 1),
    ModelBufferRead(3, 2),
]

READ_OUTPUTS = [
    (make_triangle(1), TriangleMeta(0)),
    (make_triangle(2), TriangleMeta(0)),
    (make_triangle(3), TriangleMeta(1)),
    (make_triangle(4), TriangleMeta(0)),
    (make_triangle(5), TriangleMeta(0)),
    (make_triangle(6), TriangleMeta(0)),
    (make_triangle(7), TriangleMeta(0)),
    (make_triangle(8), TriangleMeta(1)),
    (make_triangle(9), TriangleMeta(1)),
    (make_triangle(10), TriangleMeta(0)),
    (make_triangle(11), TriangleMeta(0)),
    (make_triangle(12), TriangleMeta(1)),
]


@cocotb.test()
async def test_write_model(dut: Modelbuffer):
    await make_clock(dut)

    write = Producer(dut, "write")
    read_producer = Producer(dut, "read")
    read_consumer = Consumer(dut, "read", Triangle, TriangleMeta)
    await write.run()
    await read_producer.run()
    await read_consumer.run()

    for data in INPUTS:
        await write.produce(data)

    await ClockCycles(dut.clk, 20)

    for data in READ_INPUTS:
        await read_producer.produce(data)

    await ClockCycles(dut.clk, 100)

    triangles = await read_consumer.consume_all()

    assert len(triangles) == len(
        READ_OUTPUTS
    ), f"Incorrect number of triangles produced."

    for i, (triangle, actual_triangle) in enumerate(zip(triangles, READ_OUTPUTS)):
        assert triangle == actual_triangle, f"Failed assertion on index {i}."

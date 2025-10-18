from typing import Iterable

import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock

from stubs.modelbuffer import Modelbuffer
from types_ import Vertex, Triangle, RGB, Position
from tools.pipeline import Producer, Consumer
from logic_object import LogicObject, LogicField, UInt

VERILOG_MODULE = "ModelBuffer"

VERILOG_PARAMETERS = {
    "MAX_TRIANGLE_COUNT": 100,
    "MAX_MODEL_COUNT": 10,
}

class ModelBufData(LogicObject):
    model_id: int = LogicField(UInt(8)) # type: ignore
    triangle: Triangle = LogicField(Triangle) # type: ignore


class ModelBufReadInData(LogicObject):
    model_id: int = LogicField(UInt(8)) # type: ignore
    triangle_idx: int = LogicField(UInt(16)) # type: ignore

def make_triangle(i: int) -> Triangle:
    pos = Position(i, i, i)
    vertex = Vertex(pos, RGB(i, i, i))
    return Triangle(vertex, vertex, vertex)

class TriangleMetadata(LogicObject):
    last: int = LogicField(UInt(1)) # type: ignore


INPUTS = [
    ModelBufData(0, make_triangle(1)),
    ModelBufData(0, make_triangle(2)),
    ModelBufData(0, make_triangle(3)),
    ModelBufData(1, make_triangle(4)),
    ModelBufData(1, make_triangle(5)),
    ModelBufData(1, make_triangle(6)),
    ModelBufData(1, make_triangle(7)),
    ModelBufData(1, make_triangle(8)),
    ModelBufData(2, make_triangle(9)),
    ModelBufData(3, make_triangle(10)),
    ModelBufData(3, make_triangle(11)),
    ModelBufData(3, make_triangle(12)),
]

READ_INPUTS = [
    ModelBufReadInData(0, 0),
    ModelBufReadInData(0, 1),
    ModelBufReadInData(0, 2),
    ModelBufReadInData(1, 0),
    ModelBufReadInData(1, 1),
    ModelBufReadInData(1, 2),
    ModelBufReadInData(1, 3),
    ModelBufReadInData(1, 4),
    ModelBufReadInData(2, 0),
    ModelBufReadInData(3, 0),
    ModelBufReadInData(3, 1),
    ModelBufReadInData(3, 2),
]

READ_OUTPUTS = [
    (make_triangle(1), TriangleMetadata(0)),
    (make_triangle(2), TriangleMetadata(0)),
    (make_triangle(3), TriangleMetadata(1)),
    (make_triangle(4), TriangleMetadata(0)),
    (make_triangle(5), TriangleMetadata(0)),
    (make_triangle(6), TriangleMetadata(0)),
    (make_triangle(7), TriangleMetadata(0)),
    (make_triangle(8), TriangleMetadata(1)),
    (make_triangle(9), TriangleMetadata(1)),
    (make_triangle(10), TriangleMetadata(0)),
    (make_triangle(11), TriangleMetadata(0)),
    (make_triangle(12), TriangleMetadata(1)),
]

async def make_clock(dut: Modelbuffer):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.rstn.value = 0
    await RisingEdge(dut.clk)
    dut.rstn.value = 1

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

@cocotb.test()
async def test_write_model(dut: Modelbuffer):
    await make_clock(dut)

    write = Producer(dut, "write")
    read_producer = Producer(dut, "read")
    read_consumer = Consumer(dut, "read", Triangle, TriangleMetadata)
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

    assert len(triangles) == len(READ_OUTPUTS), f"Incorrect number of triangles produced."

    for i, (triangle, actual_triangle) in enumerate(zip(triangles, READ_OUTPUTS)):
        assert triangle == actual_triangle, f"Failed assertion on index {i}."

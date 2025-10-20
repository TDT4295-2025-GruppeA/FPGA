import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles

from cocotb.types import Range, LogicArray
from logic_object import LogicField, UInt
from types_ import (
    LogicObject,
    Triangle,
    RGB,
    Transform,
    Position,
    Vertex,
    RotationMatrix,
)
from tools.pipeline import Producer, Consumer

VERILOG_MODULE = "PipelineHead"


class ModelBufData(LogicObject):
    model_id: int = LogicField(UInt(8))  # type: ignore
    triangle: Triangle = LogicField(Triangle)  # type: ignore


class SceneBufData(LogicObject):
    model_id: int = LogicField(UInt(8))  # type: ignore
    transform: Transform = LogicField(Transform)  # type: ignore


class SceneBufMetadata(LogicObject):
    last: int = LogicField(UInt(1))  # type: ignore


class Byte(LogicObject):
    value: int = LogicField(UInt(8))  # type: ignore


class PipelineEntry(LogicObject):
    transform: Transform = LogicField(Transform)  # type: ignore
    triangle: Triangle = LogicField(Triangle)  # type: ignore


class PipelineEntryMeta(LogicObject):
    model_last: int = LogicField(UInt(1))  # type: ignore
    triangle_last: int = LogicField(UInt(1))  # type: ignore


CMD_BEGIN_UPLOAD = 0xA0
CMD_UPLOAD_TRIANGLE = 0xA1
CMD_ADD_MODEL_INSTANCE = 0xB0

# fmt: off
INPUTS = [
    CMD_BEGIN_UPLOAD, 0x00,  # Start upload model 0
    CMD_UPLOAD_TRIANGLE, *([1] * 14 * 3),  # Upload a triangle
    CMD_UPLOAD_TRIANGLE, *([2] * 14 * 3),  # Upload a triangle
    CMD_UPLOAD_TRIANGLE, *([3] * 14 * 3),  # Upload a triangle
    CMD_UPLOAD_TRIANGLE, *([4] * 14 * 3),  # Upload a triangle
    CMD_UPLOAD_TRIANGLE, *([5] * 14 * 3),  # Upload a triangle
    CMD_UPLOAD_TRIANGLE, *([6] * 14 * 3),  # Upload a triangle
    CMD_BEGIN_UPLOAD, 0x01,  # Start upload model 1
    CMD_UPLOAD_TRIANGLE, *([7] * 14 * 3),  # Upload a triangle
    CMD_UPLOAD_TRIANGLE, *([8] * 14 * 3),  # Upload a triangle
    CMD_UPLOAD_TRIANGLE, *([9] * 14 * 3),  # Upload a triangle
    CMD_UPLOAD_TRIANGLE, *([10] * 14 * 3),  # Upload a triangle
    CMD_UPLOAD_TRIANGLE, *([11] * 14 * 3),  # Upload a triangle
    CMD_UPLOAD_TRIANGLE, *([12] * 14 * 3),  # Upload a triangle
    CMD_ADD_MODEL_INSTANCE, 0x00, 0x00, *([1] * 48),  # Add transform
    CMD_ADD_MODEL_INSTANCE, 0x00, 0x00, *([2] * 48),  # Add transform
    CMD_ADD_MODEL_INSTANCE, 0x01, 0x00, *([3] * 48),  # Add transform, last in scene
    CMD_ADD_MODEL_INSTANCE, 0x00, 0x01, *([4] * 48),  # Add transform
    CMD_ADD_MODEL_INSTANCE, 0x01, 0x01, *([5] * 48),  # Add transform, last in scene
]
# fmt: on


def make_triangle(i: int) -> Triangle:
    pos = (i << 24) | (i << 16) | (i << 8) | i
    color = (i << 8) | i
    rgb = RGB.from_logicarray(LogicArray(color, Range(15, "downto", 0)))
    vertex = Vertex(Position(pos, pos, pos), rgb)
    return Triangle(vertex, vertex, vertex)


def make_transform(i: int) -> Transform:
    pos = (i << 24) | (i << 16) | (i << 8) | i

    return Transform(Position(pos, pos, pos), RotationMatrix(*([pos] * 9)))


OUTPUTS_CMD = []

OUTPUTS_PIPE = [
    (PipelineEntry(make_transform(1), make_triangle(1)), PipelineEntryMeta(0, 0)),
    (PipelineEntry(make_transform(1), make_triangle(2)), PipelineEntryMeta(0, 0)),
    (PipelineEntry(make_transform(1), make_triangle(3)), PipelineEntryMeta(0, 0)),
    (PipelineEntry(make_transform(1), make_triangle(4)), PipelineEntryMeta(0, 0)),
    (PipelineEntry(make_transform(1), make_triangle(5)), PipelineEntryMeta(0, 0)),
    (PipelineEntry(make_transform(1), make_triangle(6)), PipelineEntryMeta(0, 1)),
    (PipelineEntry(make_transform(2), make_triangle(1)), PipelineEntryMeta(0, 0)),
    (PipelineEntry(make_transform(2), make_triangle(2)), PipelineEntryMeta(0, 0)),
    (PipelineEntry(make_transform(2), make_triangle(3)), PipelineEntryMeta(0, 0)),
    (PipelineEntry(make_transform(2), make_triangle(4)), PipelineEntryMeta(0, 0)),
    (PipelineEntry(make_transform(2), make_triangle(5)), PipelineEntryMeta(0, 0)),
    (PipelineEntry(make_transform(2), make_triangle(6)), PipelineEntryMeta(0, 1)),
    (PipelineEntry(make_transform(3), make_triangle(1)), PipelineEntryMeta(1, 0)),
    (PipelineEntry(make_transform(3), make_triangle(2)), PipelineEntryMeta(1, 0)),
    (PipelineEntry(make_transform(3), make_triangle(3)), PipelineEntryMeta(1, 0)),
    (PipelineEntry(make_transform(3), make_triangle(4)), PipelineEntryMeta(1, 0)),
    (PipelineEntry(make_transform(3), make_triangle(5)), PipelineEntryMeta(1, 0)),
    (PipelineEntry(make_transform(3), make_triangle(6)), PipelineEntryMeta(1, 1)),
    (PipelineEntry(make_transform(4), make_triangle(7)), PipelineEntryMeta(0, 0)),
    (PipelineEntry(make_transform(4), make_triangle(8)), PipelineEntryMeta(0, 0)),
    (PipelineEntry(make_transform(4), make_triangle(9)), PipelineEntryMeta(0, 0)),
    (PipelineEntry(make_transform(4), make_triangle(10)), PipelineEntryMeta(0, 0)),
    (PipelineEntry(make_transform(4), make_triangle(11)), PipelineEntryMeta(0, 0)),
    (PipelineEntry(make_transform(4), make_triangle(12)), PipelineEntryMeta(0, 1)),
    (PipelineEntry(make_transform(5), make_triangle(7)), PipelineEntryMeta(1, 0)),
    (PipelineEntry(make_transform(5), make_triangle(8)), PipelineEntryMeta(1, 0)),
    (PipelineEntry(make_transform(5), make_triangle(9)), PipelineEntryMeta(1, 0)),
    (PipelineEntry(make_transform(5), make_triangle(10)), PipelineEntryMeta(1, 0)),
    (PipelineEntry(make_transform(5), make_triangle(11)), PipelineEntryMeta(1, 0)),
    (PipelineEntry(make_transform(5), make_triangle(12)), PipelineEntryMeta(1, 1)),
]


async def make_clock(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.rstn.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rstn.value = 1
    await RisingEdge(dut.clk)


@cocotb.test()
async def test_pipehead(dut):
    await make_clock(dut)
    producer = Producer(dut, "cmd")
    consumer = Consumer(dut, "triangle_tf", PipelineEntry, PipelineEntryMeta)

    await producer.run()
    await consumer.run()

    for cmd in INPUTS:
        await producer.produce(Byte(cmd))

    await ClockCycles(dut.clk, 1000)

    outputs = await consumer.consume_all()

    assert len(outputs) == len(
        OUTPUTS_PIPE
    ), f"Incorrect number of elements: {len(outputs)} vs {len(OUTPUTS_PIPE)}"
    for output, actual_output in zip(outputs, OUTPUTS_PIPE):
        assert output == actual_output

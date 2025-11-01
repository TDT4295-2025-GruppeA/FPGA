import cocotb
from cocotb.triggers import ClockCycles

from types_ import (
    Byte,
    TriangleTransform,
    TriangleTransformMeta,
)
from utilities.constructors import make_triangle, make_transform, make_clock
from tools.pipeline import Producer, Consumer

VERILOG_MODULE = "PipelineHead"

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

OUTPUTS_CMD = []

T1 = make_transform(1)
T2 = make_transform(2)
T3 = make_transform(3)
T4 = make_transform(4)
T5 = make_transform(5)
OUTPUTS_PIPE = [
    (TriangleTransform(make_triangle(1), T1), TriangleTransformMeta(0, 0)),
    (TriangleTransform(make_triangle(2), T1), TriangleTransformMeta(0, 0)),
    (TriangleTransform(make_triangle(3), T1), TriangleTransformMeta(0, 0)),
    (TriangleTransform(make_triangle(4), T1), TriangleTransformMeta(0, 0)),
    (TriangleTransform(make_triangle(5), T1), TriangleTransformMeta(0, 0)),
    (TriangleTransform(make_triangle(6), T1), TriangleTransformMeta(0, 1)),
    (TriangleTransform(make_triangle(1), T2), TriangleTransformMeta(0, 0)),
    (TriangleTransform(make_triangle(2), T2), TriangleTransformMeta(0, 0)),
    (TriangleTransform(make_triangle(3), T2), TriangleTransformMeta(0, 0)),
    (TriangleTransform(make_triangle(4), T2), TriangleTransformMeta(0, 0)),
    (TriangleTransform(make_triangle(5), T2), TriangleTransformMeta(0, 0)),
    (TriangleTransform(make_triangle(6), T2), TriangleTransformMeta(0, 1)),
    (TriangleTransform(make_triangle(1), T3), TriangleTransformMeta(1, 0)),
    (TriangleTransform(make_triangle(2), T3), TriangleTransformMeta(1, 0)),
    (TriangleTransform(make_triangle(3), T3), TriangleTransformMeta(1, 0)),
    (TriangleTransform(make_triangle(4), T3), TriangleTransformMeta(1, 0)),
    (TriangleTransform(make_triangle(5), T3), TriangleTransformMeta(1, 0)),
    (TriangleTransform(make_triangle(6), T3), TriangleTransformMeta(1, 1)),
    (TriangleTransform(make_triangle(7), T4), TriangleTransformMeta(0, 0)),
    (TriangleTransform(make_triangle(8), T4), TriangleTransformMeta(0, 0)),
    (TriangleTransform(make_triangle(9), T4), TriangleTransformMeta(0, 0)),
    (TriangleTransform(make_triangle(10), T4), TriangleTransformMeta(0, 0)),
    (TriangleTransform(make_triangle(11), T4), TriangleTransformMeta(0, 0)),
    (TriangleTransform(make_triangle(12), T4), TriangleTransformMeta(0, 1)),
    (TriangleTransform(make_triangle(7), T5), TriangleTransformMeta(1, 0)),
    (TriangleTransform(make_triangle(8), T5), TriangleTransformMeta(1, 0)),
    (TriangleTransform(make_triangle(9), T5), TriangleTransformMeta(1, 0)),
    (TriangleTransform(make_triangle(10), T5), TriangleTransformMeta(1, 0)),
    (TriangleTransform(make_triangle(11), T5), TriangleTransformMeta(1, 0)),
    (TriangleTransform(make_triangle(12), T5), TriangleTransformMeta(1, 1)),
]


@cocotb.test()
async def test_pipehead(dut):
    await make_clock(dut)
    producer = Producer(dut, "cmd")
    consumer = Consumer(dut, "triangle_tf", TriangleTransform, TriangleTransformMeta)

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

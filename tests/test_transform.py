import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from utils import to_fixed, to_float

from tools.pipeline import Producer, Consumer
from logic_object import LogicObject, UInt, LogicField
from types_ import Vertex, Triangle, Position, RotationMatrix, RGB, Transform as TransformStruct

VERILOG_MODULE = "Transform"

class InputData(LogicObject):
    triangle: Triangle = LogicField(Triangle)
    transform: TransformStruct = LogicField(TransformStruct)

class OutputData(LogicObject):
    triangle: Triangle = LogicField(Triangle)

async def make_clock(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.rstn.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rstn.value = 1
    await RisingEdge(dut.clk)

@cocotb.test()
async def test_transform_identity(dut):
    """Verify that identity transform leaves triangle unchanged."""
    await make_clock(dut)

    producer = Producer(dut, "triangle_tf", False, signal_style="ms")
    consumer = Consumer(dut, "triangle", OutputData, None, signal_style="ms")
    await producer.run()
    await consumer.run()

    transform = TransformStruct(
        Position(to_fixed(0), to_fixed(0), to_fixed(0)),
        RotationMatrix(
            to_fixed(1),0,0,
            0,to_fixed(1),0,
            0,0,to_fixed(1)
        )
    )

    triangle_in = Triangle(
        Vertex(Position(to_fixed(1), to_fixed(2), to_fixed(3)), RGB(1,2,3)),
        Vertex(Position(to_fixed(4), to_fixed(5), to_fixed(6)), RGB(4,5,6)),
        Vertex(Position(to_fixed(7), to_fixed(8), to_fixed(9)), RGB(7,8,9))
    )

    input_data = [(InputData(triangle=triangle_in, transform=transform), None)]
    for data, meta in input_data:
        await producer.produce(data, meta)

    await RisingEdge(dut.triangle_m_valid)
    out_data, _ = await consumer.consume()
    triangle_out = out_data.triangle

    assert triangle_out == triangle_in, (
        f"Triangle changed under identity transform!\nExpected: {triangle_in}\nGot: {triangle_out}"
    )

@cocotb.test()
async def test_transform_translation(dut):
    """Feed a triangle through Transform and verify translation is applied."""
    await make_clock(dut)

    producer = Producer(dut, "triangle_tf", False, signal_style="ms")
    consumer = Consumer(dut, "triangle", OutputData, None, signal_style="ms")
    await producer.run()
    await consumer.run()

    transform = TransformStruct(
        Position(to_fixed(1), to_fixed(2), to_fixed(3)),
        RotationMatrix(to_fixed(1),0,0,
                       0,to_fixed(1),0,
                       0,0,to_fixed(1))
    )

    triangle_in = Triangle(
    Vertex(Position(to_fixed(1), to_fixed(1), to_fixed(1)), RGB(1,1,1)),
    Vertex(Position(to_fixed(2), to_fixed(2), to_fixed(2)), RGB(1,1,1)),
    Vertex(Position(to_fixed(3), to_fixed(3), to_fixed(3)), RGB(1,1,1))
    )


    input_data = [(InputData(triangle=triangle_in, transform=transform), None)]

    triangle_expected = Triangle(
    Vertex(Position(to_fixed(2), to_fixed(3), to_fixed(4)), RGB(1,1,1)),
    Vertex(Position(to_fixed(3), to_fixed(4), to_fixed(5)), RGB(1,1,1)),
    Vertex(Position(to_fixed(4), to_fixed(5), to_fixed(6)), RGB(1,1,1))
    )


    for data, meta in input_data:
        await producer.produce(data, meta)

    await RisingEdge(dut.triangle_m_valid)

    out_data, _ = await consumer.consume()
    triangle_out = out_data.triangle

    assert triangle_out.v0 == triangle_expected.v0, (
        f"Transformed vertex 0 mismatch!\nExpected: {triangle_expected.v0}\nGot: {triangle_out.v0}"
    )
    assert triangle_out.v1 == triangle_expected.v1, (
        f"Transformed vertex 1 mismatch!\nExpected: {triangle_expected.v1}\nGot: {triangle_out.v1}"
    )
    assert triangle_out.v2 == triangle_expected.v2, (
        f"Transformed vertex 2 mismatch!\nExpected: {triangle_expected.v2}\nGot: {triangle_out.v2}"
    )

@cocotb.test()
async def test_transform_rotation_z_90(dut):
    """Rotate a triangle 90 degrees around Z and verify positions."""
    await make_clock(dut)

    producer = Producer(dut, "triangle_tf", False, signal_style="ms")
    consumer = Consumer(dut, "triangle", OutputData, None, signal_style="ms")
    await producer.run()
    await consumer.run()

    # 90° rotation about Z axis:
    # [ 0 -1  0 ]
    # [ 1  0  0 ]
    # [ 0  0  1 ]
    transform = TransformStruct(
        Position(to_fixed(0), to_fixed(0), to_fixed(0)),
        RotationMatrix(
            to_fixed(0),  to_fixed(-1), to_fixed(0),
            to_fixed(1),  to_fixed(0),  to_fixed(0),
            to_fixed(0),  to_fixed(0),  to_fixed(1)
        )

    )

    triangle_in = Triangle(
        Vertex(Position(to_fixed(1), to_fixed(0), to_fixed(0)), RGB(1,0,0)),
        Vertex(Position(to_fixed(0), to_fixed(1), to_fixed(0)), RGB(0,1,0)),
        Vertex(Position(to_fixed(-1), to_fixed(0), to_fixed(0)), RGB(0,0,1))
    )

    input_data = [(InputData(triangle=triangle_in, transform=transform), None)]

    # Expected results after 90° rotation:
    # (1,0,0) -> (0,1,0)
    # (0,1,0) -> (-1,0,0)
    # (-1,0,0) -> (0,-1,0)
    triangle_expected = Triangle(
        Vertex(Position(to_fixed(0), to_fixed(1), to_fixed(0)), RGB(1,0,0)),
        Vertex(Position(to_fixed(-1), to_fixed(0), to_fixed(0)), RGB(0,1,0)),
        Vertex(Position(to_fixed(0), to_fixed(-1), to_fixed(0)), RGB(0,0,1))
    )

    for data, meta in input_data:
        await producer.produce(data, meta)

    await RisingEdge(dut.triangle_m_valid)

    out_data, _ = await consumer.consume()
    triangle_out = out_data.triangle

    assert triangle_out.v0 == triangle_expected.v0, (
        f"Transformed vertex 0 mismatch!\nExpected: {triangle_expected.v0}\nGot: {triangle_out.v0}"
    )
    assert triangle_out.v1 == triangle_expected.v1, (
        f"Transformed vertex 1 mismatch!\nExpected: {triangle_expected.v1}\nGot: {triangle_out.v1}"
    )
    assert triangle_out.v2 == triangle_expected.v2, (
        f"Transformed vertex 2 mismatch!\nExpected: {triangle_expected.v2}\nGot: {triangle_out.v2}"
    )

    for data, meta in input_data:
        await producer.produce(data, meta)

    await RisingEdge(dut.triangle_m_valid)

    out_data, _ = await consumer.consume()
    triangle_out = out_data.triangle

    for i, (expected, got) in enumerate(zip(
        (triangle_expected.v0, triangle_expected.v1, triangle_expected.v2),
        (triangle_out.v0, triangle_out.v1, triangle_out.v2)
    )):
        assert got.position == expected.position, (
            f"Vertex {i} position mismatch!\nExpected: {expected.position}\nGot: {got.position}"
        )
        assert got.color == expected.color, (
            f"Vertex {i} color mismatch!\nExpected: {expected.color}\nGot: {got.color}"
        )

@cocotb.test()
async def test_transform_rotation_translation(dut):
    """Apply rotation and translation together."""
    await make_clock(dut)

    producer = Producer(dut, "triangle_tf", False, signal_style="ms")
    consumer = Consumer(dut, "triangle", OutputData, None, signal_style="ms")
    await producer.run()
    await consumer.run()

    # 180° rotation about Z axis: (x,y) → (-x,-y)
    transform = TransformStruct(
        Position(to_fixed(1), to_fixed(2), to_fixed(3)),
        RotationMatrix(
            to_fixed(-1), 0,           0,
            0,           to_fixed(-1), 0,
            0,           0,           to_fixed(1)
        )
    )

    triangle_in = Triangle(
        Vertex(Position(to_fixed(1), to_fixed(1), to_fixed(1)), RGB(5,5,5)),
        Vertex(Position(to_fixed(2), to_fixed(2), to_fixed(2)), RGB(10,10,10)),
        Vertex(Position(to_fixed(3), to_fixed(3), to_fixed(3)), RGB(15,15,15))
    )

    # Expected: rotate 180° around Z (negate x,y), then translate (+1,+2,+3)
    # (1,1,1) → (-1,-1,1) + (1,2,3) = (0,1,4)
    # (2,2,2) → (-2,-2,2) + (1,2,3) = (-1,0,5)
    # (3,3,3) → (-3,-3,3) + (1,2,3) = (-2,-1,6)
    triangle_expected = Triangle(
        Vertex(Position(to_fixed(0), to_fixed(1), to_fixed(4)), RGB(5,5,5)),
        Vertex(Position(to_fixed(-1), to_fixed(0), to_fixed(5)), RGB(10,10,10)),
        Vertex(Position(to_fixed(-2), to_fixed(-1), to_fixed(6)), RGB(15,15,15))
    )

    await producer.produce(InputData(triangle=triangle_in, transform=transform), None)

    await RisingEdge(dut.triangle_m_valid)

    out_data, _ = await consumer.consume()
    triangle_out = out_data.triangle

    for i, (expected, got) in enumerate(zip(
        (triangle_expected.v0, triangle_expected.v1, triangle_expected.v2),
        (triangle_out.v0, triangle_out.v1, triangle_out.v2)
    )):
        assert got.position == expected.position, (
            f"Vertex {i} position mismatch!\nExpected: {expected.position}\nGot: {got.position}"
        )
        assert got.color == expected.color, (
            f"Vertex {i} color mismatch!\nExpected: {expected.color}\nGot: {got.color}"
        )

@cocotb.test()
async def test_transform_metadata_passthrough(dut):
    """Verify that metadata (1-bit) is correctly latched and passed through the Transform module."""
    await make_clock(dut)

    class Bit(LogicObject):
        bit: int = LogicField(UInt(1)) # type: ignore

    producer = Producer(dut, "triangle_tf", has_metadata=True, signal_style="ms")
    consumer = Consumer(dut, "triangle", OutputData, Bit, signal_style="ms")
    await producer.run()
    await consumer.run()

    transform = TransformStruct(
        Position(to_fixed(0), to_fixed(0), to_fixed(0)),
        RotationMatrix(
            to_fixed(1), to_fixed(0), to_fixed(0),
            to_fixed(0), to_fixed(1), to_fixed(0),
            to_fixed(0), to_fixed(0), to_fixed(1)
        )
    )

    triangle_in = Triangle(
        Vertex(Position(to_fixed(1), to_fixed(1), to_fixed(1)), RGB(1,1,1)),
        Vertex(Position(to_fixed(2), to_fixed(2), to_fixed(2)), RGB(2,2,2)),
        Vertex(Position(to_fixed(3), to_fixed(3), to_fixed(3)), RGB(3,3,3))
    )


    for metadata_in in [0, 1]:
        triangle_expected = triangle_in
        metadata_expected = metadata_in

        await producer.produce(InputData(triangle=triangle_in, transform=transform), Bit(metadata_in))

        await RisingEdge(dut.triangle_m_valid)
        out_data, out_meta = await consumer.consume()

        triangle_out = out_data.triangle

        assert triangle_out == triangle_expected, (
            f"Triangle changed under identity transform!\nExpected: {triangle_expected}\nGot: {triangle_out}"
        )

        assert out_meta.bit == metadata_expected, (
            f"Metadata mismatch!\nExpected: {metadata_expected}\nGot: {out_meta.bit}"
        )

        prev_meta = int(dut.triangle_m_metadata.value)
        await RisingEdge(dut.clk)
        assert int(dut.triangle_m_metadata.value) == prev_meta, (
            "Metadata changed while valid asserted!"
        )


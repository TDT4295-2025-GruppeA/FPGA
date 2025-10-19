import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
from stubs.scenebuffer import Scenebuffer

from types_ import Transform, ModelInstance, Position, RotationMatrix
from tools.pipeline import Producer, Consumer

from logic_object import LogicObject, LogicField, UInt

VERILOG_MODULE = "SceneBuffer"

VERILOG_PARAMETERS = {
    "SCENE_COUNT": 2,
    "TRANSFORM_COUNT": 10,
}

class SceneBufMetadata(LogicObject):
    last: int = LogicField(UInt(1)) # type: ignore


def make_scene(size: int, offset: int = 0) -> list[tuple[ModelInstance, SceneBufMetadata]]:
    scene: list[tuple[ModelInstance, SceneBufMetadata]] = []
    for i in range(1, size + 1):
        x = float(i + offset)

        position = Position(x, x, x)
        rotation = RotationMatrix(*([x] * 9))
        transform = Transform(position=position, rotation=rotation)

        instance = ModelInstance(1, transform)
        if i == size:
            meta = SceneBufMetadata(1)
        else:
            meta = SceneBufMetadata(0)
        scene.append((instance, meta))
    return scene

INPUTS = [
    *make_scene(4, 0),
    *make_scene(1, 4),
    *make_scene(2, 5),
    *make_scene(5, 7),
]

OUTPUTS = [
    *make_scene(4, 0),
    *make_scene(1, 4),
    *make_scene(2, 5),
    *make_scene(5, 7),
]


async def make_clock(dut: Scenebuffer):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.rstn.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rstn.value = 1
    await RisingEdge(dut.clk)


@cocotb.test()
async def test_scenebuffer(dut):
    await make_clock(dut)
    producer = Producer(dut, "write", True)
    consumer = Consumer(dut, "read", ModelInstance, SceneBufMetadata)

    await producer.run()
    for item in INPUTS:
        await producer.produce(item[0], item[1])
    await ClockCycles(dut.clk, 20)

    await consumer.run()
    await ClockCycles(dut.clk, 50)
    outputs = await consumer.consume_all()

    assert len(outputs) == len(OUTPUTS), f"Incorrect number of elements: {len(outputs)} vs {len(OUTPUTS)}"
    for output, actual_output in zip(outputs, OUTPUTS):
        assert output == actual_output
    

import cocotb
from cocotb.triggers import ClockCycles

from stubs.scenebuffer import Scenebuffer
from core.types.types_ import ModelInstance, ModelInstanceMeta, ScenebufModelInstance
from tools.pipeline import Producer, Consumer
from tools.constructors import make_clock, make_scene, make_scene_camera

VERILOG_MODULE = "SceneBuffer"

VERILOG_PARAMETERS = {
    "SCENE_COUNT": 2,
    "TRANSFORM_COUNT": 10,
}

INPUTS = [
    *make_scene(4, 0),
    *make_scene(1, 4),
    *make_scene(2, 5),
    *make_scene(5, 7),
]

OUTPUTS = [
    *make_scene_camera(4, 0),
    *make_scene_camera(1, 4),
    *make_scene_camera(2, 5),
    *make_scene_camera(5, 7),
]


@cocotb.test()
async def test_scenebuffer(dut: Scenebuffer):
    await make_clock(dut)
    producer = Producer(dut, "write")
    consumer = Consumer(dut, "read", ScenebufModelInstance, ModelInstanceMeta)

    await producer.run()
    for item in INPUTS:
        await producer.produce(item[0], item[1])
    await ClockCycles(dut.clk, 20)

    await consumer.run()
    await ClockCycles(dut.clk, 50)
    outputs = await consumer.consume_all()

    assert len(outputs) == len(
        OUTPUTS
    ), f"Incorrect number of elements: {len(outputs)} vs {len(OUTPUTS)}"
    for output, actual_output in zip(OUTPUTS, outputs):
        assert output == actual_output

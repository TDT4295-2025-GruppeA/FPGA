import cocotb
from cocotb.triggers import ClockCycles

from tools.pipeline import Producer, Consumer
from types_ import (
    ModelBufferWrite,
    ModelInstance,
    ModelInstanceMeta,
    Byte,
)
from utilities.constructors import make_transform, make_triangle, make_clock
from stubs.commandinput import Commandinput


VERILOG_MODULE = "CommandInput"


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


OUTPUTS_MODEL = [
    (ModelBufferWrite(0, make_triangle(1)), None),
    (ModelBufferWrite(0, make_triangle(2)), None),
    (ModelBufferWrite(0, make_triangle(3)), None),
    (ModelBufferWrite(0, make_triangle(4)), None),
    (ModelBufferWrite(0, make_triangle(5)), None),
    (ModelBufferWrite(0, make_triangle(6)), None),
    (ModelBufferWrite(1, make_triangle(7)), None),
    (ModelBufferWrite(1, make_triangle(8)), None),
    (ModelBufferWrite(1, make_triangle(9)), None),
    (ModelBufferWrite(1, make_triangle(10)), None),
    (ModelBufferWrite(1, make_triangle(11)), None),
    (ModelBufferWrite(1, make_triangle(12)), None),
]
OUTPUTS_CMD = []
OUTPUTS_SCENE = [
    (ModelInstance(0, make_transform(1)), ModelInstanceMeta(0)),
    (ModelInstance(0, make_transform(2)), ModelInstanceMeta(0)),
    (ModelInstance(0, make_transform(3)), ModelInstanceMeta(1)),
    (ModelInstance(1, make_transform(4)), ModelInstanceMeta(0)),
    (ModelInstance(1, make_transform(5)), ModelInstanceMeta(1)),
]


@cocotb.test()
async def test_command(dut: Commandinput):
    await make_clock(dut)
    cmd_in = Producer(dut, "cmd")
    cmd_out = Consumer(dut, "cmd", Byte)

    model_out = Consumer(dut, "model", ModelBufferWrite)
    scene_out = Consumer(dut, "scene", ModelInstance, ModelInstanceMeta)
    await cmd_in.run()
    await cmd_out.run()
    await model_out.run()
    await scene_out.run()

    for byte in INPUTS:
        await cmd_in.produce(Byte(byte))

    await ClockCycles(dut.clk, 1000)  # wait plenty cycles

    output_commands = await cmd_out.consume_all()
    output_models = await model_out.consume_all()
    output_scenes = await scene_out.consume_all()

    assert len(output_commands) == len(OUTPUTS_CMD)
    assert len(output_models) == len(OUTPUTS_MODEL)
    assert len(output_scenes) == len(OUTPUTS_SCENE)
    assert output_commands == OUTPUTS_CMD
    for (model, _), (model_actual, _) in zip(output_models, OUTPUTS_MODEL):
        assert model.model_id == model_actual.model_id
        assert model.triangle.a == model_actual.triangle.a
        assert model.triangle.b == model_actual.triangle.b
        assert model.triangle.c == model_actual.triangle.c

    for idx, ((scene, _), (scene_actual, _)) in enumerate(
        zip(output_scenes, OUTPUTS_SCENE)
    ):
        assert (
            scene.model_id == scene_actual.model_id
        ), f"Model ID did not match in index {idx}"
        assert (
            scene.transform.position == scene_actual.transform.position
        ), f"Transform did not match in index {idx}"
        assert (
            scene.transform.rotation == scene_actual.transform.rotation
        ), f"Rotation did not match in index {idx}"

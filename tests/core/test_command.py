import cocotb

from tools.pipeline import PipelineTester
from core.types.types_ import (
    ModelBufferWrite,
    ModelInstance,
    ModelInstanceMeta,
    Byte,
)
from tools.constructors import make_transform, make_triangle, make_clock
from stubs.commandinput import Commandinput


VERILOG_MODULE = "CommandInput"


CMD_RESET = 0x55
CMD_BEGIN_UPLOAD = 0xA0
CMD_UPLOAD_TRIANGLE = 0xA1
CMD_ADD_MODEL_INSTANCE = 0xB0
CMD_SET_CAMERA_TRANSFORM = 0xC0

# fmt: off
INPUTS_IDEAL = [
    CMD_RESET, CMD_RESET, # Reset command
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
    CMD_SET_CAMERA_TRANSFORM, *([6] * 48), # Set camera transform
    CMD_ADD_MODEL_INSTANCE, 0x00, 0x00, *([1] * 48),  # Add transform
    CMD_ADD_MODEL_INSTANCE, 0x00, 0x00, *([2] * 48),  # Add transform
    CMD_ADD_MODEL_INSTANCE, 0x01, 0x00, *([3] * 48),  # Add transform, last in scene
    CMD_ADD_MODEL_INSTANCE, 0x00, 0x01, *([4] * 48),  # Add transform
    CMD_ADD_MODEL_INSTANCE, 0x01, 0x01, *([5] * 48),  # Add transform, last in scene
]

INPUTS_FUCKED = [
    0x00, 0x00, 0x00, 0x00, # Someone started the clock started too early...
    CMD_RESET, CMD_RESET, # Reset command
    CMD_BEGIN_UPLOAD, 0x00,  # Start upload model 0
    0x00, # Whops, a zero too much!
    CMD_UPLOAD_TRIANGLE, *([1] * 14 * 3),  # Upload a triangle
    0x69, # Nice
    CMD_UPLOAD_TRIANGLE, *([2] * 14 * 3),  # Upload a triangle
    CMD_UPLOAD_TRIANGLE, *([3] * 14 * 3),  # Upload a triangle
    CMD_UPLOAD_TRIANGLE, *([4] * 14 * 3),  # Upload a triangle
    CMD_UPLOAD_TRIANGLE, *([5] * 14 * 3),  # Upload a triangle
    CMD_UPLOAD_TRIANGLE, *([6] * 14 * 3),  # Upload a triangle
    CMD_BEGIN_UPLOAD, 0x01,  # Start upload model 1
    CMD_UPLOAD_TRIANGLE, *([7] * 14 * 3),  # Upload a triangle
    CMD_UPLOAD_TRIANGLE, *([8] * 14 * 3),  # Upload a triangle
    0xAA, 0xAA, 0xAA, 0xAA, # Looks like someone accidentally connected the clock?
    CMD_UPLOAD_TRIANGLE, *([9] * 14 * 3),  # Upload a triangle
    CMD_UPLOAD_TRIANGLE, *([10] * 14 * 3),  # Upload a triangle
    CMD_UPLOAD_TRIANGLE, *([11] * 14 * 3),  # Upload a triangle
    CMD_UPLOAD_TRIANGLE, *([12] * 14 * 3),  # Upload a triangle
    CMD_SET_CAMERA_TRANSFORM, *([6] * 48), # Set camera transform
    CMD_ADD_MODEL_INSTANCE, 0x00, 0x00, *([1] * 48),  # Add transform
    CMD_ADD_MODEL_INSTANCE, 0x00, 0x00, *([2] * 48),  # Add transform
    CMD_ADD_MODEL_INSTANCE, 0x01, 0x00, *([3] * 48),  # Add transform, last in scene
    CMD_ADD_MODEL_INSTANCE, 0x00, 0x01, *([4] * 48),  # Add transform
    0x83, 0x87, 0x17,  # Ups, some noise
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

OUTPUTS_CAMERA = [(make_transform(6), None)]


@cocotb.test()
@cocotb.parametrize(cmd_data=[INPUTS_IDEAL, INPUTS_FUCKED])
async def test_command(dut: Commandinput, cmd_data: list[int]):
    await make_clock(dut)
    tester = PipelineTester(dut)
    await tester.add_input_stream(
        "cmd",
        [Byte(byte) for byte in cmd_data],
        processing_time=1,
    )
    # NOTE: be careful changing processing_time values in this test.
    # The module is designed to drop data if the scenebuffer is not ready
    # to receive.
    data, metadata = zip(*OUTPUTS_SCENE)
    await tester.add_output_stream("scene", data, metadata, processing_time=1)
    data, metadata = zip(*OUTPUTS_MODEL)
    await tester.add_output_stream("model", data, metadata, processing_time=10)
    data, metadata = zip(*OUTPUTS_CAMERA)
    await tester.add_output_stream("camera", data, metadata, processing_time=10)
    await tester.run_test(1000)

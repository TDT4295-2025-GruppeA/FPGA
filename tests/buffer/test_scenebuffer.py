from dataclasses import field, dataclass
from typing import Iterable

import cocotb
from cocotb.triggers import RisingEdge
from cocotb.clock import Clock
from stubs.scenebuffer import Scenebuffer

from types_ import Transform, ModelInstance, Position, RotationMatrix

VERILOG_MODULE = "SceneBuffer"

VERILOG_PARAMETERS = {
    "SCENE_COUNT": 2,
    "TRANSFORM_COUNT": 10,
}


def make_scene(size: int, offset: int = 0) -> list[ModelInstance]:
    scene: list[ModelInstance] = []
    for i in range(1, size + 1):
        x = i + offset

        position = Position(x, x, x)
        rotation = RotationMatrix(*([x] * 9))
        transform = Transform(position=position, rotation=rotation)

        instance = ModelInstance(1, transform)
        scene.append(instance)
    return scene


async def make_clock(dut: Scenebuffer):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.rstn.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rstn.value = 1
    await RisingEdge(dut.clk)


async def write_scene(dut: Scenebuffer, transforms: Iterable[ModelInstance]):
    """Write a full scene and mark it ready."""
    dut.write_en.value = 1
    for t in transforms:
        dut.write_transform.value = t.to_logicarray()
        await RisingEdge(dut.clk)

    dut.write_en.value = 0
    dut.write_transform.value = 0

    # Mark scene as ready
    dut.write_ready.value = 1
    await RisingEdge(dut.clk)
    dut.write_ready.value = 0
    await RisingEdge(dut.clk)


async def read_scene(dut: Scenebuffer) -> list[ModelInstance]:
    """Read a scene until read_done asserts."""
    result: list[ModelInstance] = []
    dut.read_en.value = 1
    while True:
        await RisingEdge(dut.clk)
        if dut.read_valid.value:
            print(dut.read_transform.value)
            result.append(ModelInstance.from_logicarray(dut.read_transform.value))
        if dut.read_done.value:
            break
    dut.read_en.value = 0
    await RisingEdge(dut.clk)
    return result


@cocotb.test()
async def test_single_scene(dut: Scenebuffer):
    await make_clock(dut)

    scene = make_scene(3)

    await write_scene(dut, scene)
    result = await read_scene(dut)

    assert scene == result


@cocotb.test()
async def test_multiple_scenes(dut: Scenebuffer):
    await make_clock(dut)

    scene1 = make_scene(3)
    scene2 = make_scene(3, 3)

    await write_scene(dut, scene1)
    await write_scene(dut, scene2)

    result1 = await read_scene(dut)
    result2 = await read_scene(dut)

    assert result1 == scene1
    assert result2 == scene2


@cocotb.test()
async def test_wraparound(dut: Scenebuffer):
    """Write more scenes than SCENE_COUNT and check circular reuse."""
    await make_clock(dut)

    scene1 = make_scene(3)
    scene2 = make_scene(3, 3)
    scene3 = make_scene(3, 6)
    await write_scene(dut, scene1)
    await write_scene(dut, scene2)
    scene1_read = await read_scene(dut)
    await write_scene(dut, scene3)
    scene2_read = await read_scene(dut)
    scene3_read = await read_scene(dut)

    assert scene1_read == scene1
    assert scene2_read == scene2
    assert scene3_read == scene3


@cocotb.test()
async def test_reset(dut: Scenebuffer):
    """Check that reset clears buffer state."""
    await make_clock(dut)

    scene = make_scene(3)
    await write_scene(dut, scene)

    dut.rstn.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rstn.value = 1
    await RisingEdge(dut.clk)

    assert not dut.read_valid.value

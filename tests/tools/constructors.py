from typing import Protocol

import cocotb
import cocotb.handle
from cocotb.types import LogicArray, Range
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from tools.utils import to_float, to_fixed

from core.types.types_ import (
    Triangle,
    RGB,
    Vertex,
    Position,
    Transform,
    RotationMatrix,
    ModelInstance,
    ModelInstanceMeta,
)


class ClockRstnDevice(Protocol):
    clk: cocotb.handle.LogicObject
    rstn: cocotb.handle.LogicObject


def twos_comp(val: int, bits: int) -> int:
    if (val & (1 << (bits - 1))) != 0:
        val = val - (1 << bits)
    return val


def make_triangle(i: int) -> Triangle:
    # TODO: hardcoded transforms
    x = (((i << 24) | (i << 16) | (i << 8) | i) >> 2) & 0x1FFFFFF
    pos = to_float(twos_comp(x, 25))

    color = (i << 8) | i
    rgb = RGB.from_c565(color)
    vertex = Vertex(Position(pos, pos, pos), rgb)
    return Triangle(vertex, vertex, vertex)


def make_transform(i: int) -> Transform:
    x = (((i << 24) | (i << 16) | (i << 8) | i) >> 2) & 0x1FFFFFF
    pos = to_float(twos_comp(x, 25))

    return Transform(Position(pos, pos, pos), RotationMatrix(*([pos] * 9)))


async def make_clock(dut: ClockRstnDevice):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.rstn.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rstn.value = 1
    await RisingEdge(dut.clk)


def make_scene(
    size: int, offset: int = 0, model_id: int = 1
) -> list[tuple[ModelInstance, ModelInstanceMeta]]:
    scene: list[tuple[ModelInstance, ModelInstanceMeta]] = []
    for i in range(1, size + 1):
        instance = ModelInstance(model_id, make_transform(i + offset))
        meta = ModelInstanceMeta(i == size)
        scene.append((instance, meta))
    return scene

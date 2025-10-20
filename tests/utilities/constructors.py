from typing import Protocol

import cocotb
import cocotb.handle
from cocotb.types import LogicArray, Range
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

from types_ import (
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


def make_triangle(i: int) -> Triangle:
    pos = (i << 24) | (i << 16) | (i << 8) | i
    color = (i << 8) | i
    rgb = RGB.from_logicarray(LogicArray(color, Range(15, "downto", 0)))
    vertex = Vertex(Position(pos, pos, pos), rgb)
    return Triangle(vertex, vertex, vertex)


def make_transform(i: int) -> Transform:
    pos = (i << 24) | (i << 16) | (i << 8) | i

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

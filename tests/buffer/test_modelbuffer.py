from dataclasses import field
from typing import Iterable

import cocotb
from cocotb.triggers import RisingEdge
from cocotb.clock import Clock
import cocotb.types

from stubs.modelbuffer import Modelbuffer
from logic_object import LogicObject

VERILOG_MODULE = "ModelBuffer"

VERILOG_PARAMETERS = {
    "MAX_TRIANGLE_COUNT": 10,
    "MAX_MODEL_COUNT": 10,
}


class RGB(LogicObject):
    r: int = field(metadata={"size": 4, "type": "uint"})
    g: int = field(metadata={"size": 4, "type": "uint"})
    b: int = field(metadata={"size": 4, "type": "uint"})

class Triangle(LogicObject):
    x: int = field(metadata={"size": 32})
    y: int = field(metadata={"size": 32})
    z: int = field(metadata={"size": 32})
    color: RGB = field(metadata={"size": 12, "type": RGB})

async def make_clock(dut: Modelbuffer):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

@cocotb.test()
async def test_write_single_triangle(dut: Modelbuffer):
    await make_clock(dut)

    triangle = Triangle(1,2,3, RGB(4,5,6))

    dut.write_en.value = 1
    dut.write_model_index.value = 0
    dut.write_triangle.value = triangle.to_logicarray()
    dut.write_triangle_index.value = 0

    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)

    triangle_out = Triangle.from_logicarray(dut.model_buffer.value[0])

    assert triangle_out == triangle


async def write_model(dut: Modelbuffer, model_index: int, triangles: Iterable[Triangle]):
    dut.write_model_index.value = model_index
    dut.write_en.value = 1

    # Write a set of triangles to the buffer
    for i, triangle in enumerate(triangles):
        dut.write_triangle.value = triangle.to_logicarray()
        dut.write_triangle_index.value = i

        await RisingEdge(dut.clk)

    # Disable the input
    dut.write_en.value = 0
    dut.write_triangle_index.value = 0
    dut.write_triangle.value = 0

    # Need extra clock cycle to write last triangle
    await RisingEdge(dut.clk)


async def read_model(dut: Modelbuffer, model_index: int) -> list[Triangle]:
    i = 0
    result: list[Triangle] = []
    dut.read_model_index.value = model_index
    dut.read_en.value = 1
    while not dut.read_last_index.value:
        dut.read_triangle_index.value = i
        await RisingEdge(dut.clk)
        result.append(Triangle.from_logicarray(dut.read_triangle.value))
        i += 1
    
    dut.read_triangle_index.value = 0
    dut.read_en.value = 0
    dut.read_model_index.value = 0
    await RisingEdge(dut.clk)

    return result

@cocotb.test()
async def test_write_model(dut: Modelbuffer):
    await make_clock(dut)
    
    model = [Triangle(i,i,i, RGB(i,i,i)) for i in range(1, 6)]
    await write_model(dut, 0, model)
    
    model_result = await read_model(dut, 0)

    assert model == model_result


@cocotb.test()
async def test_multimodel(dut: Modelbuffer):
    await make_clock(dut)

    model1 = [Triangle(i,i,i, RGB(i,i,i)) for i in range(1,4)]
    model2 = [Triangle(i,i,i, RGB(i,i,i)) for i in range(4, 7)]
    model3 = [Triangle(i,i,i, RGB(i,i,i)) for i in range(7, 10)]


    await write_model(dut, 0, model1)
    await write_model(dut, 1, model2)
    await write_model(dut, 2, model3)

    model1_result = await read_model(dut, 0)
    model2_result = await read_model(dut, 1)
    model3_result = await read_model(dut, 2)

    assert model1 == model1_result
    assert model2 == model2_result
    assert model3 == model3_result


@cocotb.test()
async def test_no_overwrite(dut: Modelbuffer):
    """Test that its not possible to redefine a module"""
    await make_clock(dut)

    model1 = [Triangle(i,i,i, RGB(i,i,i)) for i in range(1, 4)]
    model2 = [Triangle(i,i,i, RGB(i,i,i)) for i in range(4, 7)]

    await write_model(dut, 0, model1)
    await write_model(dut, 1, model1)
    await write_model(dut, 0, model2)

    model1_result = await read_model(dut, 0)
    
    assert model1 == model1_result

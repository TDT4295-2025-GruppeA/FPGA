import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer
from stubs.modelrom import Modelrom

from types_ import Triangle

TRIANGLE_COUNT = 12

VERILOG_MODULE = "ModelRom"
VERILOG_PARAMETERS = {
    "TRIANGLE_COUNT": TRIANGLE_COUNT,
    "FILE_PATH": '"../static/models/cube"',
}


@cocotb.test(timeout_time=1, timeout_unit="us")
async def test_model_rom(dut: Modelrom):
    clock = Clock(dut.clk, 10, "ns")
    cocotb.start_soon(clock.start())

    for address in range(TRIANGLE_COUNT):
        dut.address.value = address
        await clock.cycles(1)
        await Timer(1, "ns")
        triangle = Triangle.from_logicarray(dut.triangle.value)
        cocotb.log.info(
            f"Address: {address}\n"
            f"Bits: {hex(dut.triangle.value.to_unsigned())}\n"
            f"Struct: {triangle}"
        )

    # We don't do any asserts as the test is that Triangle.from_logicarray
    # does not raise any errors when reading all triangles from the ROM.

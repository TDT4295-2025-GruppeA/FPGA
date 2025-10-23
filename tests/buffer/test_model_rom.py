import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer
from stubs.modelrom import Modelrom

from types_ import Triangle

TRIANGLE_COUNT = 12

VERILOG_MODULE = "ModelRom"
VERILOG_PARAMETERS = {
    "TRIANGLE_COUNT": TRIANGLE_COUNT,
    "FILE_PATH": "\"../static/cube\"",
}

@cocotb.test(timeout_time=1, timeout_unit="us")
async def test_model_rom(dut: Modelrom):
    clock = Clock(dut.clk, 10, "ns")
    cocotb.start_soon(clock.start())

    for address in range(TRIANGLE_COUNT):
        dut.address.value = address
        await clock.cycles(1)
        await Timer(1, "ns")
        cocotb.log.info(
            f"Address: {address}\n"
            f"Bits: {hex(dut.triangle.value.to_unsigned())}\n"
            f"Struct: {Triangle.from_logicarray(dut.triangle.value)}"
        )

    assert False
import cocotb
from cocotb.triggers import Timer
from stubs.adder import Adder

# Define which verilog module that should appear as device under testing
# in the tests in this module
VERILOG_MODULE = "Adder"


@cocotb.test()
async def test_adder_1(dut: Adder):
    """Very simple test to demonstrate test-system"""
    dut.a.value = 1
    dut.b.value = 2

    await Timer(1)

    assert dut.sum.value == 3

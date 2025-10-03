import cocotb
from cocotb.triggers import Timer
from stubs.example import Example

VERILOG_MODULE = "Example"


@cocotb.test()
async def test_adder_1(dut: Example):
    """Very simple test to demonstrate test-system"""
    dut.a.value = 1
    dut.b.value = 2

    await Timer(1)

    assert dut.sum.value == 3


@cocotb.test()
async def test_always_pass(dut):
    """Example test that will never fail"""
    assert True


@cocotb.test(expect_fail=True)
async def test_always_fail(dut):
    """Example test that will always fail"""
    assert False

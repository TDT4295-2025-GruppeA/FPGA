import cocotb
from cocotb.triggers import Timer
from cocotb.binary import BinaryValue

@cocotb.test()
async def test_always_pass(dut):
    """Example test that will never fail"""
    assert True


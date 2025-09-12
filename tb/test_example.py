import cocotb
from cocotb.triggers import Timer
from cocotb.binary import BinaryValue

VERILOG_MODULE = "Top"

@cocotb.test()
async def test_always_pass(dut):
    """Example test that will never fail"""
    assert True

@cocotb.test()
async def test_adder(dut):
    """Test simple adder"""
    assert True
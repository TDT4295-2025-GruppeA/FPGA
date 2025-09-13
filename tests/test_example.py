import cocotb

VERILOG_MODULE = "Top"

@cocotb.test()
async def test_always_pass(dut):
    """Example test that will never fail"""
    assert True

@cocotb.test(expect_fail=True)
async def test_always_fail(dut):
    """Example test that will always fail"""
    assert False
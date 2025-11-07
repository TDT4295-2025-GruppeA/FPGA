# import cocotb

# from stubs.serialtoparallel import Serialtoparallel
# from serial.serial_to_parallel_tester import (
#     tester_serial_to_parallel,
#     tester_noncontinuous,
# )

# # OUTPUT_SIZE must be divisible by INPUT_SIZE
# INPUT_SIZE = 8
# OUTPUT_SIZE = 8 * 5

# VERILOG_MODULE = "SerialToParallel"
# VERILOG_PARAMETERS = {
#     "INPUT_SIZE": INPUT_SIZE,
#     "OUTPUT_SIZE": OUTPUT_SIZE,
# }

# CLOCK_PERIOD = 4

# TEST_DATA = [
#     0xDEABCDEF88,
#     0xADCFB229FE,
#     0xBE648833BF,
#     0xEFFFFFFFFF,
#     0xFFFFFFFFFE,
#     0x0000000000,
#     0xFFFFFFFFFF,
#     0x427751BD99,
# ]


# @cocotb.test()
# async def test_serial_to_parallel(dut: Serialtoparallel):
#     await tester_serial_to_parallel(
#         dut, TEST_DATA, INPUT_SIZE, OUTPUT_SIZE, CLOCK_PERIOD
#     )


# @cocotb.test()
# async def test_noncontinous_serial_to_parallel(dut: Serialtoparallel):
#     await tester_noncontinuous(dut, TEST_DATA, INPUT_SIZE, OUTPUT_SIZE, CLOCK_PERIOD)

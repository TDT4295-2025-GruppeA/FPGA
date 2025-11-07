# """
# This test can generate an image from the pipeline output, and
# could be useful for testing
# """
# import cocotb
# from cocotb.clock import Clock
# from stubs.top import Top
# import numpy as np
# from PIL import Image
# from tools.constructors import make_clock
# from tools.pipeline import Producer
# from cocotb.triggers import ClockCycles, RisingEdge
# import numpy as np

# from core.types.types_ import (
#     Byte,
# )

# BUFFER_WIDTH = 160
# BUFFER_HEIGHT = 120

# VERILOG_MODULE = "Top"

# CMD_BEGIN_UPLOAD = 0xA0
# CMD_UPLOAD_TRIANGLE = 0xA1
# CMD_ADD_MODEL_INSTANCE = 0xB0

# async def make_clock(dut: Top):
#     cocotb.start_soon(Clock(dut.clk_ext, 10, unit="ns").start())
#     dut.reset.value = 1
#     await RisingEdge(dut.clk_ext)
#     await RisingEdge(dut.clk_ext)
#     dut.reset.value = 0
#     await RisingEdge(dut.clk_ext)


# @cocotb.test(timeout_time=100, timeout_unit="ms")
# async def test_graphics_pipeline(dut: Top):
#     with open("../cmds.data", "rb") as f:
#         INPUTS = list(f.read())
#     await make_clock(dut)
#     producer = Producer(dut.pipeline_inst, "cmd", clock_name="clk_system")
#     write_en = dut.pipeline_inst.pipeline_tail.drawing_manager_inst.write_en
#     write_addr = dut.pipeline_inst.pipeline_tail.drawing_manager_inst.write_addr
#     write_data = dut.pipeline_inst.pipeline_tail.drawing_manager_inst.write_data
#     frame_done = dut.pipeline_inst.pipeline_tail.drawing_manager_inst.frame_done

#     await producer.run()
#     for cmd in INPUTS:
#         await producer.produce(Byte(cmd))

#     for i in range(10):
#         frame_buffer = np.zeros((BUFFER_HEIGHT, BUFFER_WIDTH, 3), dtype=np.uint8)
#         while not frame_done.value:
#             data = write_data.value.to_unsigned()
#             addr = write_addr.value.to_unsigned()

#             r = (data >> 8) & 0xF
#             g = (data >> 4) & 0xF
#             b = (data >> 0) & 0xF
#             if write_en.value:
#                 x = addr % BUFFER_WIDTH
#                 y = addr // BUFFER_WIDTH
#                 frame_buffer[y, x, 0] = (r << 4) | r
#                 frame_buffer[y, x, 1] = (g << 4) | g
#                 frame_buffer[y, x, 2] = (b << 4) | b
#             await ClockCycles(dut.clk_ext, 1)
#         img = Image.fromarray(frame_buffer, "RGB")
#         img.save(f"images/image{i}.png")
#         await RisingEdge(dut.pipeline_inst.pipeline_tail.drawing_manager_inst.draw_ack)
#         await ClockCycles(dut.clk_ext, 10)

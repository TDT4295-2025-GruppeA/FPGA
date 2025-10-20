import cocotb
from tools.pipeline import Producer, Consumer

from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles
from logic_object import LogicObject, UInt, LogicField
from stubs.serialtoparallelstream import Serialtoparallelstream

INPUT_SIZE = 1
OUTPUT_SIZE = 8

VERILOG_MODULE = "SerialToParallelStream"
VERILOG_PARAMETERS = {
    "INPUT_SIZE": INPUT_SIZE,
    "OUTPUT_SIZE": OUTPUT_SIZE,
}

TESTS = [0x00, 0xFF, 0xFE, 0x7F, 0xAB, 0xDD, 0x01, 0x80]


class InputData(LogicObject):
    serial: int = LogicField(UInt(1))  # type: ignore


class OutputData(LogicObject):
    parallel: int = LogicField(UInt(8))  # type: ignore


async def make_clock(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.rstn.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rstn.value = 1
    await RisingEdge(dut.clk)


@cocotb.test()
async def test_serial_parallel_stream_1x8(dut: Serialtoparallelstream):
    await make_clock(dut)
    producer = Producer(dut, "serial")
    consumer = Consumer(dut, "parallel", OutputData)
    await producer.run()
    await consumer.run()

    if len(TESTS) == 0:
        raise ValueError(f"No tests to run: {TESTS}.")

    inputs = []
    outputs: list[OutputData] = []
    for test in TESTS:
        for i in reversed(range(OUTPUT_SIZE)):
            bit = (test >> i) & 1
            inputs.append(InputData(bit))
        outputs.append(OutputData(test))

    for data in inputs:
        await producer.produce(data)

    await ClockCycles(dut.clk, OUTPUT_SIZE * len(TESTS))

    for i in range(len(TESTS)):
        result = (await consumer.consume())[0]
        assert (
            result == outputs[i]
        ), f"Failed with data: '{result.parallel:0{OUTPUT_SIZE}b}'. Expected '{outputs[i].parallel:0{OUTPUT_SIZE}b}'"


@cocotb.test()
async def test_noncontinous_serial_parallel_stream_1x8(dut: Serialtoparallelstream):
    await make_clock(dut)
    producer = Producer(dut, "serial")
    consumer = Consumer(dut, "parallel", OutputData)
    await producer.run()
    await consumer.run()

    if len(TESTS) == 0:
        raise ValueError(f"No tests to run: {TESTS}.")

    inputs = []
    outputs: list[OutputData] = []
    for test in TESTS:
        for i in reversed(range(OUTPUT_SIZE)):
            bit = (test >> i) & 1
            inputs.append(InputData(bit))
        outputs.append(OutputData(test))

    for i in range(0, len(inputs), 4):
        for data in inputs[i : i + 4]:
            await producer.produce(data)
        await ClockCycles(dut.clk, 10)

    for i in range(len(TESTS)):
        result = (await consumer.consume())[0]
        assert (
            result == outputs[i]
        ), f"Failed with data: '{result.parallel:0{OUTPUT_SIZE}b}'. Expected '{outputs[i].parallel:0{OUTPUT_SIZE}b}'"

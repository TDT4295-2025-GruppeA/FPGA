import cocotb
from tools.pipeline import Producer, Consumer

from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, ClockCycles
from tools.logic_object import LogicObject, UInt, LogicField
from stubs.serialtoparallelstream import Serialtoparallelstream

INPUT_SIZE = 8
OUTPUT_SIZE = 8 * 5

VERILOG_MODULE = "SerialToParallelStream"
VERILOG_PARAMETERS = {
    "INPUT_SIZE": INPUT_SIZE,
    "OUTPUT_SIZE": OUTPUT_SIZE,
}

TESTS = [
    0xDEABCDEF88,
    0xADCFB229FE,
    0xBE648833BF,
    0xEFFFFFFFFF,
    0xFFFFFFFFFE,
    0x0000000000,
    0xFFFFFFFFFF,
    0x427751BD99,
]


class InputData(LogicObject):
    serial: int = LogicField(UInt(8))  # type: ignore


class OutputData(LogicObject):
    parallel: int = LogicField(UInt(40))  # type: ignore


async def make_clock(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.rstn.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rstn.value = 1
    await RisingEdge(dut.clk)


@cocotb.test()
async def test_serial_parallel_stream_8x40(dut: Serialtoparallelstream):
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
        for i in reversed(range(0, OUTPUT_SIZE, INPUT_SIZE)):
            element = (test >> i) & ((1 << INPUT_SIZE) - 1)
            inputs.append(InputData(element))
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
async def test_noncontinous_serial_parallel_stream_8x40(dut: Serialtoparallelstream):
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
        for i in reversed(range(0, OUTPUT_SIZE, INPUT_SIZE)):
            element = (test >> i) & ((1 << INPUT_SIZE) - 1)
            inputs.append(InputData(element))
        outputs.append(OutputData(test))

    for i in range(0, len(inputs), 3):
        for data in inputs[i : i + 3]:
            await producer.produce(data)
        await ClockCycles(dut.clk, 10)

    for i in range(len(TESTS)):
        result = (await consumer.consume())[0]
        assert (
            result == outputs[i]
        ), f"Failed with data: '{result.parallel:0{OUTPUT_SIZE}b}'. Expected '{outputs[i].parallel:0{OUTPUT_SIZE}b}'"

import cocotb
from tools.pipeline import Producer, Consumer

from cocotb.clock import Clock
from cocotb.triggers import RisingEdge
from logic_object import LogicObject, UInt, LogicField
from stubs.pipelinetoolstester import Pipelinetoolstester

VERILOG_MODULE = "PipelineToolsTester"


class InputData(LogicObject):
    test: int = LogicField(UInt(8))  # type: ignore


class OutputData(LogicObject):
    test: int = LogicField(UInt(8))  # type: ignore


class InputMetadata(LogicObject):
    test: int = LogicField(UInt(4))  # type: ignore


class OutputMetadata(LogicObject):
    test: int = LogicField(UInt(4))  # type: ignore


async def make_clock(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="ns").start())
    dut.rstn.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rstn.value = 1
    await RisingEdge(dut.clk)


@cocotb.test(timeout_time=10 * 1000, timeout_unit="ns")
async def test_producer_consumer(dut: Pipelinetoolstester):
    await make_clock(dut)
    producer = Producer(dut, "stage", True)
    consumer = Consumer(dut, "stage", OutputData, OutputMetadata)
    await producer.run()
    await consumer.run()

    input_data = [(InputData(i), InputMetadata(i + 1)) for i in range(10)]

    for data, metadata in input_data:
        await producer.produce(data, metadata)

    for _ in range(10):
        await RisingEdge(dut.stage_out_valid)
        dut._log.info("Out valid got high")

    output_data: list[tuple[OutputData, OutputMetadata | None]] = []
    for _ in range(10):
        output_data.append(await consumer.consume())


@cocotb.test(timeout_time=10 * 1000, timeout_unit="ns")
async def test_no_metadata(dut: Pipelinetoolstester):
    await make_clock(dut)
    producer = Producer(dut, "stage", False)
    consumer = Consumer(dut, "stage", OutputData, None)
    await producer.run()
    await consumer.run()

    input_data = [(InputData(i), None) for i in range(10)]

    for data, metadata in input_data:
        await producer.produce(data, metadata)

    for _ in range(10):
        await RisingEdge(dut.stage_out_valid)
        dut._log.info("Out valid got high")

    output_data: list[tuple[OutputData, None]] = []
    for _ in range(10):
        output_data.append(await consumer.consume())

    for i in range(10):
        i_data, _ = input_data[i]
        o_data, o_metadata = output_data[i]
        assert o_metadata is None, f"Output metadata was not None when it should be"
        assert (
            i_data.test == o_data.test
        ), f"Data at index {i} did not match: {i_data.test} != {o_data.test}"

import abc
from typing import Protocol, Type, TypeVar, Generic, Literal, Sequence

import cocotb
import cocotb.handle
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.queue import Queue
from cocotb.handle import Force

from tools.logic_object import LogicObject


class PipelineDut(Protocol):
    """DUT interface — signals accessed dynamically via getattr()."""


_Data = TypeVar("_Data", bound=LogicObject)
_Metadata = TypeVar("_Metadata", bound=LogicObject)


class PipelineBase(abc.ABC):
    def __init__(self, dut: PipelineDut, name: str, type: str, clock_name: str = "clk"):
        self._dut = dut
        self._name = name
        self._type = type
        self._clock_name = clock_name

    def _get_signal(self, name: str) -> cocotb.handle.ValueObjectBase:
        signal_name = f"{self._name}_{self._type}_{name}"
        if not hasattr(self._dut, signal_name):
            raise TypeError(f"dut is missing the signal `{signal_name}`")
        signal = getattr(self._dut, signal_name)
        if not isinstance(signal, cocotb.handle.ValueObjectBase):
            raise TypeError(
                f"Signal `{signal_name}` of dut is not a valid signal. Got `{type(signal)}`"
            )
        return signal

    @property
    def _valid(self):
        return self._get_signal("valid")

    @property
    def _ready(self):
        return self._get_signal("ready")

    @property
    def _data(self):
        return self._get_signal("data")

    @property
    def _metadata(self):
        return self._get_signal("metadata")

    @property
    def _clk(self):
        return getattr(self._dut, self._clock_name)

    async def run(self):
        """Run the pipeline handler"""
        cocotb.start_soon(self._run_loop())

    @abc.abstractmethod
    async def _run_loop(self): ...


class Producer(PipelineBase, Generic[_Data, _Metadata]):
    def __init__(
        self,
        dut: PipelineDut,
        name: str,
        has_metadata: bool = False,
        signal_style: str = "inout",
        clock_name: str = "clk",
        processing_time: int = 1,
    ):
        type = "in" if signal_style == "inout" else "s"
        super().__init__(dut, name, type, clock_name=clock_name)
        self._input_queue: Queue[tuple[_Data, _Metadata | None]] = Queue()

        if processing_time < 1:
            raise ValueError(
                f"{processing_time} is not a valid processing time. Must be 1 or higher."
            )
        self._processing_time = processing_time

    async def produce(self, data: _Data, metadata: _Metadata | None = None):
        """Push a transaction into the DUT (with optional metadata)."""
        await self._input_queue.put((data, metadata))

    async def produce_all(self, data: list[_Data], metadata: list[_Metadata | None]):
        for item, item_meta in zip(data, metadata, strict=True):
            await self.produce(item, item_meta)

    async def _run_loop(self):
        """
        Coroutine that will constantly push items from the production
        queue into the DUT.
        """
        while True:
            # Get the next item to produce
            data, metadata = await self._input_queue.get()

            # If metadata is enabled, we want to set the metadata signal
            if metadata is not None:
                self._metadata.value = Force(metadata.to_logicarray())

            # Set the data, and mark the data as valid
            self._data.value = Force(data.to_logicarray())
            self._valid.value = Force(1)

            # Make sure the data actually makes it to the DUT
            await RisingEdge(self._clk)

            # Wait for item to be consumed
            while not self._ready.value:
                await RisingEdge(self._clk)

            # Wait fake "processing_time" to produce next item
            # (simulate pipeline bubble)
            if self._processing_time > 1:
                self._valid.value = Force(0)
                await ClockCycles(self._clk, self._processing_time - 1)

            # Set data as invalid if we do not have more items
            if self._input_queue.empty():
                self._valid.value = Force(0)
                await RisingEdge(self._clk)


class Consumer(PipelineBase, Generic[_Data, _Metadata]):
    def __init__(
        self,
        dut: PipelineDut,
        name: str,
        data_type: Type[_Data],
        metadata_type: Type[_Metadata] | None = None,
        signal_style: str = "inout",
        clock_name: str = "clk",
        processing_time: int = 1,
    ):
        type = "out" if signal_style == "inout" else "m"
        super().__init__(dut, name, type, clock_name=clock_name)

        # Store the output type so we can use them to convert LogicArray
        # to the output type
        self._data_type = data_type
        self._metadata_type = metadata_type

        self._output_queue: Queue[tuple[_Data, _Metadata | None]] = Queue()

        if processing_time < 1:
            raise ValueError(
                f"{processing_time} is not a valid processing time. Must be 1 or higher."
            )
        self._processing_time = processing_time

    async def consume(self) -> tuple[_Data, _Metadata | None]:
        """Retrieve a transaction from the DUT."""
        return await self._output_queue.get()

    async def consume_all(self) -> list[tuple[_Data, _Metadata | None]]:
        items = []
        while not self._output_queue.empty():
            items.append(await self._output_queue.get())
        return items

    async def _run_loop(self):
        while True:
            # Sleep for processing_time clock cycles
            self._ready.value = 0
            if self._processing_time > 1:
                await ClockCycles(self._clk, self._processing_time - 1)
            self._ready.value = 1
            await ClockCycles(self._clk, 1)

            # Wait for data to become valid
            while not self._valid.value:
                await ClockCycles(self._clk, 1)

            # Read the output data
            data = self._data_type.from_logicarray(self._data.value)
            metadata = (
                self._metadata_type.from_logicarray(self._metadata.value)
                if self._metadata_type is not None
                else None
            )

            # Store it for consumption by the end user
            await self._output_queue.put((data, metadata))


class PipelineTester:
    def __init__(self, dut: PipelineDut, clock_name: str = "clk"):
        self._producers: list[Producer] = []
        self._consumers: list[
            tuple[Consumer, Sequence[LogicObject], Sequence[LogicObject | None]]
        ] = []
        self._clock_name = clock_name
        self._dut = dut

    async def add_input_stream(
        self,
        signal_name: str,
        data: Sequence[LogicObject],
        metadata: Sequence[LogicObject | None] | None = None,
        signal_style: Literal["ms", "inout"] = "inout",
        processing_time: int = 2,
    ):
        producer = Producer(
            dut=self._dut,
            name=signal_name,
            signal_style=signal_style,
            clock_name=self._clock_name,
            processing_time=processing_time,
        )
        if metadata is None:
            metadata = [None] * len(data)
        for item, item_meta in zip(data, metadata, strict=True):
            await producer.produce(item, item_meta)
        self._producers.append(producer)

    async def add_output_stream(
        self,
        signal_name: str,
        data: Sequence[LogicObject],
        metadata: Sequence[LogicObject] | Sequence[None] | None = None,
        signal_style: Literal["ms", "inout"] = "inout",
        processing_time: int = 3,
    ):
        if len(data) == 0:
            raise ValueError("stream must have at least one output")
        output_type = type(data[0])
        if metadata is None:
            output_metadata_type = None
        else:
            if metadata[0] == None:
                output_metadata_type = None
            else:
                output_metadata_type = type(metadata[0])

        consumer = Consumer(
            self._dut,
            name=signal_name,
            data_type=output_type,
            metadata_type=output_metadata_type,
            signal_style=signal_style,
            clock_name=self._clock_name,
            processing_time=processing_time,
        )
        if metadata is None:
            metadata = [None] * len(data)
        self._consumers.append((consumer, data, metadata))

    async def _init_streams(self):
        for producer in self._producers:
            await producer.run()

        for consumer, _, _ in self._consumers:
            await consumer.run()

    async def run_test(self, delay: int):
        await self._init_streams()
        # TODO: better timeout control
        await ClockCycles(getattr(self._dut, self._clock_name), delay)

        # The test should now be executed, we can consume from all consumers and compare.
        # list of expected vs actual results
        results = []
        for consumer, data, meta in self._consumers:
            actual = await consumer.consume_all()
            if len(actual) > 0:
                actual_data, actual_meta = zip(*actual)
            else:
                actual_data = []
                actual_meta = []
            results.append((data, meta, actual_data, actual_meta))

        for result in results:
            self._assert_result(*result)

    def _assert_result(
        self,
        data: list[LogicObject],
        meta: list[LogicObject | None],
        actual_data: list[LogicObject],
        actual_meta: list[LogicObject | None],
    ):
        assert len(data) == len(
            actual_data
        ), "Actual length did not match expected data length."
        assert len(meta) == len(
            actual_data
        ), "Actual meta length did not matche expected meta length"

        for item0, item1 in zip(data, actual_data):
            assert item0 == item1, "Output data did not match expected data"

        for item0, item1 in zip(meta, actual_meta):
            assert item0 == item1, "Output metadata did not match expected metadata"

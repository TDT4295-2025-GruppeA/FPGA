import abc
from typing import Protocol, Type, TypeVar, Generic

import cocotb
import cocotb.handle
from cocotb.triggers import RisingEdge
from cocotb.queue import Queue

from logic_object import LogicObject


class PipelineDut(Protocol):
    """DUT interface — signals accessed dynamically via getattr()."""

    clk: cocotb.handle.LogicObject


_Data = TypeVar("_Data", bound=LogicObject)
_Metadata = TypeVar("_Metadata", bound=LogicObject)


class PipelineBase(abc.ABC):
    def __init__(self, dut: PipelineDut, name: str, type: str):
        self._dut = dut
        self._name = name
        self._type = type

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
    ):
        type = "in" if signal_style == "inout" else "s"
        super().__init__(dut, name, type)
        self._has_metadata = has_metadata
        self._input_queue: Queue[tuple[_Data, _Metadata | None]] = Queue()

    async def produce(self, data: _Data, metadata: _Metadata | None = None):
        """Push a transaction into the DUT (with optional metadata)."""
        if self._has_metadata and metadata is None:
            raise ValueError(
                "Metadata is missing from produce call, but metadata is enabled"
            )
        await self._input_queue.put((data, metadata))

    async def _run_loop(self):
        """
        Coroutine that will constantly push items from the production
        queue into the DUT.
        """
        while True:
            # Get the next item to produce
            data, metadata = await self._input_queue.get()

            # If metadata is enabled, we want to set the metadata signal
            if self._has_metadata and metadata is not None:
                self._metadata.value = metadata.to_logicarray()

            # Set the data, and mark the data as valid
            self._data.value = data.to_logicarray()
            self._valid.value = 1

            # Make sure the data actually makes it to the DUT
            await RisingEdge(self._dut.clk)

            # Wait for item to be consumed
            while not self._ready.value:
                await RisingEdge(self._dut.clk)

            # Set data as invalid if we do not have more items
            if self._input_queue.empty():
                self._valid.value = 0
                await RisingEdge(self._dut.clk)


class Consumer(PipelineBase, Generic[_Data, _Metadata]):
    def __init__(
        self,
        dut: PipelineDut,
        name: str,
        data_type: Type[_Data],
        metadata_type: Type[_Metadata] | None = None,
        signal_style: str = "inout",
    ):
        type = "out" if signal_style == "inout" else "m"
        super().__init__(dut, name, type)

        # Store the output type so we can use them to convert LogicArray
        # to the output type
        self._data_type = data_type
        self._metadata_type = metadata_type

        self._output_queue: Queue[tuple[_Data, _Metadata | None]] = Queue()

    async def consume(self) -> tuple[_Data, _Metadata | None]:
        """Retrieve a transaction from the DUT."""
        return await self._output_queue.get()

    async def consume_all(self) -> list[tuple[_Data, _Metadata | None]]:
        items = []
        while not self._output_queue.empty():
            items.append(await self._output_queue.get())
        return items

    async def _run_loop(self):
        # TODO: expose this to the user so they can control when to
        # consume?
        self._ready.value = 1

        while True:
            # Wait for the data to become valid
            await RisingEdge(self._dut.clk)
            if not self._valid.value:
                continue

            # Read the output data
            data = self._data_type.from_logicarray(self._data.value)
            metadata = (
                self._metadata_type.from_logicarray(self._metadata.value)
                if self._metadata_type is not None
                else None
            )

            # Store it for consumption by the end user
            await self._output_queue.put((data, metadata))

from dataclasses import dataclass, Field
from typing import dataclass_transform

from cocotb.types import LogicArray, Range


def concat(a: LogicArray, *arr: LogicArray) -> LogicArray:
    arr = (a, *arr)

    sizes = []
    for x in arr:
        sizes.append(x.range.left - x.range.right + 1)
    total_size = sum(sizes)

    new_range = Range(total_size - 1, 0)
    result = LogicArray(0, new_range)

    index = 0
    for x, size in zip(reversed(arr), reversed(sizes)):
        result[x.range.left + index : x.range.right + index] = x
        index += size
    return result


@dataclass_transform()
class _Meta(type):
    def __new__(cls, *args, **kwargs):
        cls = super().__new__(cls, *args, **kwargs)
        return dataclass(cls)


class LogicObject(metaclass=_Meta):
    @classmethod
    def from_logicarray(cls, logic_array: LogicArray):
        field: Field
        values = {}
        index = 0
        for key, field in reversed(cls.__dataclass_fields__.items()):
            if "size" not in field.metadata:
                raise ValueError("Missing 'size' metadata in field")
            size = field.metadata.get("size")
            if not isinstance(size, int):
                raise TypeError(
                    f"Incorrect metadata value for 'size'. Got: '{type(size)}', expected '{int}'"
                )

            value_type = field.metadata.get("type", "int")

            sliced = logic_array[index + size - 1 : index]
            sliced.range = Range(size-1, "downto", 0)

            if value_type == "int":
                values[key] = sliced.to_signed()
            elif value_type == "uint":
                values[key] = sliced.to_unsigned()
            elif value_type == "bytes":
                values[key] = sliced.to_bytes(byteorder="big")  # TODO: expose byteorder
            elif isinstance(value_type, type) and issubclass(value_type, LogicObject):
                values[key] = value_type.from_logicarray(sliced)
            else:
                raise ValueError(f"Invalid value type '{value_type}'")

            index += size
        return cls(**values)

    def to_logicarray(self) -> LogicArray:
        arrays = []
        field: Field
        for key, field in self.__dataclass_fields__.items():
            value = getattr(self, key)

            if "size" not in field.metadata:
                raise ValueError("Missing 'size' metadata in field")
            size = field.metadata.get("size")
            if not isinstance(size, int):
                raise TypeError(
                    f"Incorrect metadata value for 'size'. Got: '{type(size)}', expected '{int}'"
                )

            if issubclass(type(value), LogicObject):
                value = value.to_logicarray()
            arr = LogicArray(value, Range(size - 1, 0))
            arrays.append(arr)

        if len(arrays) == 0:
            raise ValueError("Cannot pack empty logicarray")

        return concat(*arrays)

from dataclasses import dataclass, Field, field, fields
from typing import dataclass_transform, Literal

from utils import quantize, to_fixed, to_float
from cocotb.types import LogicArray, Logic, Range


class _LogicType:
    def __init__(self, size: int):
        self.size = size


class Int(_LogicType):
    def __init__(self, size: int):
        super().__init__(size)


class UInt(_LogicType):
    def __init__(self, size: int):
        super().__init__(size)


class Fixed(_LogicType):
    def __init__(self):
        super().__init__(32)


class Bytes(_LogicType):
    def __init__(self, size: int, byteorder: Literal["big", "little"]):
        super().__init__(size)
        self.byteorder: Literal["big", "little"] = byteorder


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
        if isinstance(logic_array, Logic):
            logic_array = LogicArray(int(logic_array), Range(0, 0))
        values = {}
        index = 0
        for key in reversed(cls.__dataclass_fields__.keys()):
            size = cls._get_field_size(key)
            field_type = cls._get_field_type(key)

            sliced = logic_array[index + size - 1 : index]
            sliced.range = Range(size - 1, "downto", 0)

            if issubclass(field_type, Int):
                values[key] = sliced.to_signed()
            elif issubclass(field_type, UInt):
                values[key] = sliced.to_unsigned()
            elif issubclass(field_type, Fixed):
                values[key] = to_float(sliced.to_signed())
            elif issubclass(field_type, Bytes):
                values[key] = sliced.to_bytes(byteorder="big")  # TODO: expose byteorder
            elif issubclass(field_type, LogicObject):
                values[key] = field_type.from_logicarray(sliced)
            else:
                raise ValueError(f"Invalid value type '{field_type}'")

            index += size
        return cls(**values)

    def to_logicarray(self) -> LogicArray:
        arrays = []
        for key in self.__dataclass_fields__.keys():
            value = getattr(self, key)
            size = self._get_field_size(key)

            field_type = self._get_field_type(key)
            arr_range = Range(size - 1, "downto", 0)

            if issubclass(field_type, Int):
                arr = LogicArray.from_signed(value, arr_range)
            elif issubclass(field_type, UInt):
                arr = LogicArray.from_unsigned(value, arr_range)
            elif issubclass(field_type, Bytes):
                raise NotImplemented
            elif isinstance(value, float):
                value = to_fixed(value)
                arr = LogicArray.from_signed(value, arr_range)
            elif issubclass(field_type, LogicObject):
                if isinstance(value, LogicObject):
                    value = value.to_logicarray()
                    arr = LogicArray(value, arr_range)
                else:
                    raise TypeError(
                        f"value is '{type(value)}', not LogicObject when field type is LogicObject."
                    )
            else:
                raise ValueError(f"Invalid field type '{field_type}'")

            arrays.append(arr)

        if len(arrays) == 0:
            raise ValueError("Cannot pack empty logicarray")

        return concat(*arrays)

    @classmethod
    def _get_field_size(cls, field_name: str) -> int:
        value_field = cls.__dataclass_fields__.get(field_name)
        if not isinstance(value_field, Field):
            raise TypeError(
                f"dataclass field for '{field_name}' in '{cls.__name__}' is not of type 'Field'"
            )

        field_type = value_field.metadata.get("type")

        if isinstance(field_type, _LogicType):
            return field_type.size
        if isinstance(field_type, type) and issubclass(field_type, LogicObject):
            return field_type.size()
        else:
            raise TypeError(
                f"Invalid field type '{field_type}' for field '{field_name}'"
            )

    @classmethod
    def _get_field_type(cls, field_name: str) -> "type[_LogicType] | type[LogicObject]":
        value_field = cls.__dataclass_fields__.get(field_name)
        if not isinstance(value_field, Field):
            raise TypeError(
                f"dataclass field for '{field_name}' in '{cls.__name__}' is not of type 'Field'"
            )

        field_type = value_field.metadata.get("type")

        if isinstance(field_type, _LogicType):
            return type(field_type)
        elif isinstance(field_type, type) and issubclass(field_type, LogicObject):
            return field_type
        else:
            raise TypeError(
                f"Invalid field type '{field_type}' for field '{field_name}'"
            )

    @classmethod
    def size(cls) -> int:
        """Total size of the LogicObject in bits"""
        total_size = 0
        for field_name in cls.__dataclass_fields__.keys():
            field_size = cls._get_field_size(field_name)
            total_size += field_size

        return total_size

    def __post_init__(self):
        for field in fields(self):
            value = getattr(self, field.name)
            logic_type = field.metadata.get("type")

            # Quantize float to fixed point representation.
            if isinstance(logic_type, Fixed):
                if not isinstance(value, (int, float)):
                    raise TypeError(
                        f"Field '{field.name}' must be of type 'int' or 'float', got '{type(value)}'"
                    )

                setattr(self, field.name, quantize(value))


class LogicField(Field):
    def __new__(cls, field_type: _LogicType | type[LogicObject], *args, **kwargs):
        metadata = kwargs.get("metadata", {})
        if not isinstance(metadata, dict):
            raise TypeError("metadata must be of type 'dict'")
        metadata.update({"type": field_type})
        kwargs.update({"metadata": metadata})
        return field(*args, **kwargs)

    def __init__(self, field_type: _LogicType | type[LogicObject]): ...

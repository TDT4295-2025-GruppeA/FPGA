"""Python-versions of types defined in src/types.sv"""

from logic_object import LogicObject, Int, UInt, LogicField

# static type checkers don't recognize that the field declarations here
# are semantically equivalent to
#
# from dataclasses import field
# class A:
#   a: int = field(...)
#
# so it spews type errors. That is why everything is explicitly
# type-ignored.


class RGB(LogicObject):
    r: int = LogicField(UInt(4))  # type: ignore
    g: int = LogicField(UInt(4))  # type: ignore
    b: int = LogicField(UInt(4))  # type: ignore


class Position(LogicObject):
    x: int = LogicField(Int(32))  # type: ignore
    y: int = LogicField(Int(32))  # type: ignore
    z: int = LogicField(Int(32))  # type: ignore


class Vertex(LogicObject):
    position: Position = LogicField(Position)  # type: ignore
    color: RGB = LogicField(RGB)  # type: ignore


class Triangle(LogicObject):
    v0: Vertex = LogicField(Vertex)  # type: ignore
    v1: Vertex = LogicField(Vertex)  # type: ignore
    v2: Vertex = LogicField(Vertex)  # type: ignore


class RotationMatrix(LogicObject):
    m00: int = LogicField(Int(32))  # type: ignore
    m01: int = LogicField(Int(32))  # type: ignore
    m02: int = LogicField(Int(32))  # type: ignore
    m10: int = LogicField(Int(32))  # type: ignore
    m11: int = LogicField(Int(32))  # type: ignore
    m12: int = LogicField(Int(32))  # type: ignore
    m20: int = LogicField(Int(32))  # type: ignore
    m21: int = LogicField(Int(32))  # type: ignore
    m22: int = LogicField(Int(32))  # type: ignore


class Transform(LogicObject):
    position: Position = LogicField(Position)  # type: ignore
    rotation: RotationMatrix = LogicField(RotationMatrix)  # type: ignore


class ModelInstance(LogicObject):
    model_id: int = LogicField(UInt(8))  # type: ignore
    transform: Transform = LogicField(Transform)  # type: ignore


class PixelCoordinate(LogicObject):
    x: int = LogicField(UInt(10))  # type: ignore
    y: int = LogicField(UInt(10))  # type: ignore

class PixelData(LogicObject):
    valid: int = LogicField(UInt(1)) # type: ignore
    color: RGB = LogicField(RGB) # type: ignore
    depth: int = LogicField(Int(32)) # type: ignore
    coordinate: PixelCoordinate = LogicField(PixelCoordinate) # type: ignore


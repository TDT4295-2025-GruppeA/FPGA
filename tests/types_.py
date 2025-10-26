"""Python-versions of types defined in src/types.sv"""

from logic_object import Fixed, LogicObject, UInt, LogicField

# static type checkers don't recognize that the field declarations here
# are semantically equivalent to
#
# from dataclasses import field
# class A:
#   a: int = field(...)
#
# so it spews type errors. That is why everything is explicitly
# type-ignored.


class Bit(LogicObject):
    bit: int = LogicField(UInt(1))  # type: ignore


class RGB(LogicObject):
    r: int = LogicField(UInt(4), default=0)  # type: ignore
    g: int = LogicField(UInt(4), default=0)  # type: ignore
    b: int = LogicField(UInt(4), default=0)  # type: ignore
    reserved: int = LogicField(UInt(4), default=0)  # type: ignore


class Position(LogicObject):
    x: float = LogicField(Fixed())  # type: ignore
    y: float = LogicField(Fixed())  # type: ignore
    z: float = LogicField(Fixed())  # type: ignore


class Vertex(LogicObject):
    position: Position = LogicField(Position)  # type: ignore
    color: RGB = LogicField(RGB, default_factory=RGB)  # type: ignore


class Triangle(LogicObject):
    v0: Vertex = LogicField(Vertex)  # type: ignore
    v1: Vertex = LogicField(Vertex)  # type: ignore
    v2: Vertex = LogicField(Vertex)  # type: ignore


class TriangleMetadata(LogicObject):
    last: int = LogicField(UInt(1))  # type: ignore


class RotationMatrix(LogicObject):
    m00: float = LogicField(Fixed())  # type: ignore
    m01: float = LogicField(Fixed())  # type: ignore
    m02: float = LogicField(Fixed())  # type: ignore
    m10: float = LogicField(Fixed())  # type: ignore
    m11: float = LogicField(Fixed())  # type: ignore
    m12: float = LogicField(Fixed())  # type: ignore
    m20: float = LogicField(Fixed())  # type: ignore
    m21: float = LogicField(Fixed())  # type: ignore
    m22: float = LogicField(Fixed())  # type: ignore


class Transform(LogicObject):
    position: Position = LogicField(Position)  # type: ignore
    rotation: RotationMatrix = LogicField(RotationMatrix)  # type: ignore


class TriangleTransform(LogicObject):
    triangle: Triangle = LogicField(Triangle)  # type: ignore
    transform: Transform = LogicField(Transform)  # type: ignore


class ModelInstance(LogicObject):
    model_id: int = LogicField(UInt(8))  # type: ignore
    transform: Transform = LogicField(Transform)  # type: ignore


class PixelCoordinate(LogicObject):
    x: int = LogicField(UInt(10))  # type: ignore
    y: int = LogicField(UInt(10))  # type: ignore


class PixelData(LogicObject):
    covered: int = LogicField(UInt(1))  # type: ignore
    depth: float = LogicField(Fixed())  # type: ignore
    color: RGB = LogicField(RGB)  # type: ignore
    coordinate: PixelCoordinate = LogicField(PixelCoordinate)  # type: ignore


class PixelDataMetadata(LogicObject):
    last: int = LogicField(UInt(1))  # type: ignore

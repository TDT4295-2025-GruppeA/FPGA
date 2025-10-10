import numpy as np
from cocotb.types import Array, LogicArray

TOLERANCE = 0.001

# This needs to match the fixed point format used in the Verilog code
DECIMAL_WIDHT = 16


def to_fixed(value):
    """Convert a float to fixed point."""
    res = value * (1 << DECIMAL_WIDHT)

    if isinstance(res, np.ndarray):
        return res.astype(int)

    return int(res)


def to_float(value):
    """Convert a fixed point to float."""
    return value / (1 << DECIMAL_WIDHT)


def within_tolerance(
    a: int | float | np.ndarray,
    b: int | float | np.ndarray,
    tolerance: float = TOLERANCE,
) -> bool:
    """Check if two values are within a certain tolerance. The values may be scalars or numpy arrays."""
    return bool(np.allclose(a, b, atol=TOLERANCE, rtol=0))


def cocotb_to_numpy(cocotb_matrix: Array | LogicArray) -> np.ndarray:
    """Converts a cocotb ArrayObject of fixed point integers to a numpy array of floats."""

    def convert_array(array: Array | LogicArray) -> int | np.ndarray:
        if isinstance(array, Array):
            return np.array([convert_array(element) for element in array])

        if isinstance(array, LogicArray):
            return array.to_signed()

        # This should never happen
        raise RuntimeError("Element is not an Array or LogicArray")

    res = convert_array(cocotb_matrix)

    return to_float(res)  # type: ignore


def numpy_to_cocotb(np_matrix: np.ndarray) -> list:
    """Converts a numpy array of floats to a cocotb ArrayObject of fixed point integers."""
    return to_fixed(np_matrix).tolist()  # type: ignore


def binary_to_gray(gray: int) -> int:
    """
    Convert a binary number to its Gray code representation.
    Implementation take from Wikipedia.
    """
    return gray ^ (gray >> 1)


def gray_to_binary(gray: int) -> int:
    """
    Convert a Gray code number to its binary representation.
    Implementation taken from Wikipedia.
    """
    mask = gray
    while mask != 0:
        mask >>= 1
        gray ^= mask
    return gray


def differ_by_one_bit(a: int, b: int) -> bool:
    """Check if two integers differ by exactly one bit."""
    # If a and b differ by one bit, x will be a power of two.
    # (Power of two in binary has exactly one bit set.)
    x = a ^ b
    # We can use this cursed formula to check if x is a power of two.
    return x != 0 and (x & (x - 1)) == 0

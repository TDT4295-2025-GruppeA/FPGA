from typing import overload
import math
import numpy as np
from cocotb.types import Array, LogicArray

# How many decimals bits are used in the fixed point format.
# IMPORTANT: This needs to match the fixed point format used in the Verilog code
FRACTIONAL_BITS = 14
TOTAL_WIDTH = 25

# The smallest representable interval in the fixed point format.
RESOLUTION = 2**-FRACTIONAL_BITS

MAX_VALUE = ((1 << (TOTAL_WIDTH - 1)) - 1) * RESOLUTION
MIN_VALUE = -(1 << (TOTAL_WIDTH - 1)) * RESOLUTION

# Tolerance for comparisons, in least significant bits (LSBs).
# Used to determine if two fixed point values are "close enough" to be considered equal.
TOLERANCE_LSB = 1


# Taken from: https://stackoverflow.com/questions/51689594/how-to-round-away-from-0-in-python-3-x
def round_away(x: float) -> float:
    """Rounds a float away from zero."""
    if x >= 0.0:
        return math.floor(x + 0.5)
    else:
        return math.ceil(x - 0.5)


# Numpy version of above function
def np_round_away(x: np.ndarray) -> np.ndarray:
    """Rounds a numpy array of floats away from zero."""
    return np.where(x >= 0.0, np.floor(x + 0.5), np.ceil(x - 0.5))


@overload
def to_fixed(value: float, fractional_bits: int = FRACTIONAL_BITS) -> int: ...
@overload
def to_fixed(value: np.ndarray, fractional_bits: int = FRACTIONAL_BITS) -> np.ndarray: ...
def to_fixed(value: float | np.ndarray, fractional_bits: int = FRACTIONAL_BITS) -> int | np.ndarray:
    """Convert a float to fixed point."""
    res = value * (1 << fractional_bits)

    # It is important that we round away from zero here
    # as that is what System Verilog does.

    if isinstance(res, np.ndarray):
        return np_round_away(res).astype(np.int32)

    return int(round_away(res))


@overload
def to_float(value: int, fractional_bits: int = FRACTIONAL_BITS) -> float: ...
@overload
def to_float(value: np.ndarray, fractional_bits: int = FRACTIONAL_BITS) -> np.ndarray: ...
def to_float(value: int | np.ndarray, fractional_bits: int = FRACTIONAL_BITS) -> float | np.ndarray:
    """Convert a fixed point to float."""
    return value / (1 << fractional_bits)


@overload
def quantize(value: float, fractional_bits: int = FRACTIONAL_BITS) -> float: ...
@overload
def quantize(value: np.ndarray, fractional_bits: int = FRACTIONAL_BITS) -> np.ndarray: ...
def quantize(value: float | np.ndarray, fractional_bits: int = FRACTIONAL_BITS) -> float | np.ndarray:
    """Round a float or numpy array to the closest fixed point representation."""
    return to_float(to_fixed(value), fractional_bits)


def within_tolerance(
    a: int | float | np.ndarray,
    b: int | float | np.ndarray,
    tolerance_lsb: float = TOLERANCE_LSB,
) -> bool:
    """Check if two values are within a certain tolerance. The values may be scalars or numpy arrays."""
    return bool(np.allclose(a, b, atol=tolerance_lsb * RESOLUTION, rtol=0))


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

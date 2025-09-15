import numpy as np
from cocotb.handle import ArrayObject
from cocotb.types import Array

TOLERANCE = 0.001

# This needs to match the fixed point format used in the Verilog code
DECIMAL_WIDHT = 16

def to_fixed(value):
    """Convert a float to fixed point."""
    res = (value * (1 << DECIMAL_WIDHT))

    if isinstance(value, np.ndarray):
        return res.astype(int)
    
    return int(res)

def to_float(value):
    """Convert a fixed point to float."""
    return value / (1 << DECIMAL_WIDHT)

def within_tolerance(a, b, tolerance = TOLERANCE):
    """Check if two values are within a certain tolerance. The values may be scalars or numpy arrays."""
    return np.any(np.abs(a - b) < tolerance)

def cocotb_to_numpy(cocotb_matrix: ArrayObject) -> np.ndarray:
    """Converts a cocotb ArrayObject of fixed point integers to a numpy array of floats."""
    def convert_element(elem):
        if isinstance(elem, Array):
            return np.array([convert_element(e) for e in elem])

        return int(elem)
    
    res = convert_element(cocotb_matrix)

    return to_float(res)

def numpy_to_cocotb(np_matrix: np.ndarray) -> list:
    """Converts a numpy array of floats to a cocotb ArrayObject of fixed point integers."""
    return to_fixed(np_matrix).tolist()

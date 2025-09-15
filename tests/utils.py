import numpy as np
from cocotb.types import Array, LogicArray

TOLERANCE = 0.001

# This needs to match the fixed point format used in the Verilog code
DECIMAL_WIDHT = 16

def to_fixed(value):
    """Convert a float to fixed point."""
    res = (value * (1 << DECIMAL_WIDHT))

    if isinstance(res, np.ndarray):
        return res.astype(int)
    
    return int(res)

def to_float(value):
    """Convert a fixed point to float."""
    return value / (1 << DECIMAL_WIDHT)

def within_tolerance(a: int | float | np.ndarray, b: int | float | np.ndarray, tolerance: float = TOLERANCE) -> bool:
    """Check if two values are within a certain tolerance. The values may be scalars or numpy arrays."""
    return bool(np.allclose(a, b, atol=TOLERANCE, rtol=0))

def cocotb_to_numpy(cocotb_matrix: Array) -> np.ndarray:
    """Converts a cocotb ArrayObject of fixed point integers to a numpy array of floats."""
    def convert_element(elem) -> int | np.ndarray:
        if isinstance(elem, Array):
            return np.array([convert_element(e) for e in elem])

        if isinstance(elem, LogicArray):
            return elem.to_signed()
        
        # This should never happen
        raise RuntimeError("Element is not an Array or LogicArray")
    
    res = convert_element(cocotb_matrix)

    return to_float(res) # type: ignore

def numpy_to_cocotb(np_matrix: np.ndarray) -> list:
    """Converts a numpy array of floats to a cocotb ArrayObject of fixed point integers."""
    return to_fixed(np_matrix).tolist() # type: ignore

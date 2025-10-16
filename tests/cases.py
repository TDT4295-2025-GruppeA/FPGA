import numpy as np

# Turn black formatter off to keep my pretty formatting. :)
# fmt: off

# A set of real values to use for testing fixed point arithmetic.
# Zero is added explicitly to ensure it is included.
TEST_VALUES = set(np.concat([
    np.linspace(-1, 1, 49), 
    np.linspace(-10, 10, 49), 
    [np.float64(0.0)]
]))

# A set of vectors used for testing vector operations.
TEST_VECTORS = [
    np.array([ 0,     0,     0   ]),
    np.array([ 1,     0,     0   ]),
    np.array([ 0,     1,     0   ]),
    np.array([ 0,     0,     1   ]),
    np.array([-1,     0,     0   ]),
    np.array([ 1,    -1,     1   ]),
    np.array([ 1,     2,     3   ]),
    np.array([ 4,     5,     6   ]),
    np.array([ 0.1,   0.2,   0.3 ]),
    np.array([ 0.4,   0.5,   0.6 ]),
    np.array([-1,    -2,    -3   ]),
    np.array([-4,    -5,    -6   ]),
    np.array([ 0.5,  -0.5,   0.5 ]),
    np.array([-0.5,   0.5,  -0.5 ]),
    np.array([ 0.25,  0.50,  0.75]),
    np.array([-0.10,  0.20, -0.50]),
]

# fmt: on

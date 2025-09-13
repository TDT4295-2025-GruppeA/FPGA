import functools

import pytest
import cocotb_test.simulator
import os

DIR_TESTS = os.path.join(os.path.abspath("."), "tests")

def create_test(toplevel: str, filename, module_name: str, testcase: str | None = None):
    def decorator(func):
        with open("tb-files.txt") as f:
            files = f.read().split("\n")

        @functools.wraps(func)
        @pytest.mark.module(filename, module_name, testcase)
        def wrapper(*args, **kwargs):
            del args, kwargs  # ignore args
            cocotb_test.simulator.run(
                simulator="verilator",
                verilog_sources=files,
                toplevel=toplevel,
                module=module_name,
                includes=["."],
                compile_args=["--structs-packed", "-DSIMULATION"],
                testcase=testcase,
                # Different simbuild dir to utilize cache on each module
                sim_build=f"build/test/simbuild_{toplevel}",
                python_search=[DIR_TESTS],
            )

        return wrapper

    return decorator
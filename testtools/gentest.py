import glob
import importlib
from types import ModuleType
from dataclasses import dataclass
import warnings
import sys
import os

import jinja2
import cocotb._decorators

DIR_TESTS = "tests"
DIR_TOOLS = "testtools"

# TODO: clean up paths accross modules?
abs_path = os.path.abspath(".")
test_path = os.path.join(abs_path, DIR_TESTS)
sys.path.insert(0, abs_path)
sys.path.insert(0, test_path)


@dataclass
class TestFunction:
    name: str
    func: cocotb._decorators.Test


@dataclass
class TestModule:
    name: str
    module: ModuleType
    tests: dict[str, TestFunction]
    verilog_toplevel: str
    verilog_parameters: str | None


def import_module(module_name: str, testdir: str) -> TestModule:
    # Find and import the module
    # Remove prefix and suffix, and replace remaining / with .
    name = module_name.rsplit(".py", 1)[0]
    name = name.split(f"{testdir}/", 1)[1]
    name = name.replace("/", ".")

    module = importlib.import_module(".".join(("tests", name)))
    tests = find_tests(module)

    # Get name of verilog toplevel module
    if hasattr(module, "VERILOG_MODULE"):
        verilog_toplevel = getattr(module, "VERILOG_MODULE")
    else:
        raise ImportError(
            f"Module '{name}' is missing required 'VERILOG_MODULE' definition. Ignoring module"
        )

    if not isinstance(verilog_toplevel, str):
        raise ImportError(
            f"Module '{name}' has invalid value for 'VERILOG_MODULE'. Got '{type(name)}', expected str. Ignoring module"
        )

    # Get parameters to toplevel module if available
    if hasattr(module, "VERILOG_PARAMETERS"):
        verilog_parameters = getattr(module, "VERILOG_PARAMETERS")

        if not isinstance(verilog_parameters, dict):
            raise ImportError(
                f"Module '{name}' has non-dict value for 'VERILOG_PARAMETERS."
            )

        verilog_parameters = repr(verilog_parameters)
    else:
        verilog_parameters = None

    return TestModule(
        name=name,
        module=module,
        tests=tests,
        verilog_toplevel=verilog_toplevel,
        verilog_parameters=verilog_parameters,
    )


def find_test_modules(testdir: str) -> dict[str, TestModule]:
    modules = {}
    for module_name in glob.glob(f"{testdir}/**/test_*.py", recursive=True):
        try:
            module = import_module(module_name=module_name, testdir=testdir)
        except (ImportError, ModuleNotFoundError) as e:
            warnings.warn(f"Failed to import module '{module_name}': {e!s}")
            continue

        module_name = module_name.split(f"{testdir}/", 1)[1]

        modules[module_name] = module
    return modules


def find_tests(module: ModuleType) -> dict[str, TestFunction]:
    tests: dict[str, TestFunction] = {}
    for var in vars(module):
        if var.startswith("test_"):
            # This is probably a test. Check if it is a cocotb test
            func = getattr(module, var)
            if isinstance(
                func, (cocotb._decorators.Test, cocotb._decorators.Parameterized)
            ):
                tests[var] = TestFunction(var, func)

    return tests


def main():

    # Discover tests
    modules = find_test_modules(DIR_TESTS)

    # Generate tests
    env = jinja2.Environment(loader=jinja2.FileSystemLoader(DIR_TOOLS))
    template = env.get_template("testrunner.py.jinja2")
    testrunner = template.render(modules=modules)
    with open(f"{DIR_TOOLS}/testrunner.py", "w") as f:
        f.write(testrunner)


if __name__ == "__main__":
    main()

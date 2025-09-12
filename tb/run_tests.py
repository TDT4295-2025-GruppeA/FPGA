import pytest
import warnings
warnings.filterwarnings("ignore", category=UserWarning)
import cocotb.runner

collected_modules = {}

class CollectorPlugin:
    def pytest_collection_modifyitems(self, session, config, items):
        for item in items:
            test_module = item.module.__name__
            try:
                verilog_module = getattr(item.module, "VERILOG_MODULE")
            except:
                raise RuntimeError(f"Missing 'VERILOG_MODULE' in test '{test_module}'")
            collected_modules[test_module] = verilog_module

# Run pytest in collection-only mode
pytest.main(["--collect-only"], plugins=[CollectorPlugin()])

@pytest.mark.parametrize(["test_module", "verilog_module"], collected_modules.items())
def test_trying_stuff(test_module, verilog_module):
    with open("tb-files.txt") as f:
        verilog_sources = f.read().split("\n")

    runner = cocotb.runner.get_runner("verilator")
    runner.build(
        verilog_sources=verilog_sources,
        build_args=["-DSIMULATION", "--structs-packed"],
        includes=["."],
        build_dir="build/test",
        hdl_toplevel=verilog_module,
    )
    
    runner.test(
        test_module=test_module,
        hdl_toplevel=verilog_module,
        hdl_toplevel_lang="verilog",
    )
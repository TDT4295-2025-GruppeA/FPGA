# TDT4295 Datamaskinprosjekt - FPGA

This repository contains the code for the fpga in our TDT4295 project.

## Table of contents
* [Quickstart](#quickstart)
* [Testing](#testing)
    * [Test setup](#test-setup)
    * [Example test](#example-test) 
* [Tools](#tools)
    * [Recommended setup](#recommended-setup-linux)
    * [Calculate clock config](#calc_display_clk_configpy)
    * [Convert image to .mem](#convert_img_to_mempy)


## Quickstart

* Install vivado
* run `make synth`
  * optionally specify target with `make synth TARGET=100t`. Currently supported targets are `100t` and `35t`
  * You can also specify board `make synth BOARD=arty7`. Currently only supports `arty7`.
* run `make flash` (again optional `TARGET=100t`, to write to flash set `FLASH_MODE=flash`)

NOTE: if using a on-board framebuffer of `12` bit color,`640x480`, the design will be too large to fit on a`Artix 7A35t`

## Testing

To run the testbenches simply run `make test`.

### Test setup
The entire test-solution is a bit of a wacky setup.
The goal of the test solution is to be able to unit-test specific modules.
Because of the nature of how verilator, and cocotb works, this is not an
easy problem to solve. cocotb is designed to test a single top-module at
a time, that is not unit-testing the modules. We could make a test-harness
containing all the modules to unit-test, but that is also a sub-optimal
solution.

The solution implemented here lets you write tests like in normal cocotb,
but you are able to specify which verilog module to test by specifying
`VERILOG_MODULE` in each test-module. The tools in `testtools` will then
read this module, and make sure those tests get the requested module as
`dut`.

It does this by generating fake `pytest`-tests, each containing its own
cocotb test-run configured specifically for that test. It then modifies
`pytest`'s test-report to make it look like the original user-written
tests. It does not do this perfectly, but its close.

Typing stubs are also auto-generated for every verilog-module when running
tests. You can also manually generate these by running `make stubs`

### Example test

Here is an example test testing the `Example` module, located in
`src/example.sv`

    import cocotb
    from cocotb.triggers import Timer
    from stubs.example import Example

    VERILOG_MODULE = "Example"

    @cocotb.test()
    async def test_adder_1(dut: Example):
        """Very simple test to demonstrate test-system"""
        dut.a.value = 1
        dut.b.value = 2

        await Timer(1)

        assert dut.sum.value == 3

    ...

In this test, the `dut` will be the `Example`-module. we set values for
a and b, then yielding to the simulator to calculate the result. The
result is then available and asserted to see if it is correct.

### Stub generation

> [!Warning]
> Stub generation requires all verilog modules to have a default value
> assigned for all parameters.

Python typing stubs for tests can be generated with

    make stubs

The stubs will also be automatically generated when running `make test`


## Tools

There are some python scripts to assist in generating parameters and files.

#### Recommended setup (linux):
Python 3.12 is required to use the tools. It is recommended to use a virtual environment.
To set up a t virtual environment with the required packages the following commands can be used:

    python3 -m venv .venv
    source .venv/bin/activate
    python3 -m pip install -r requirements.txt

#### calc_display_clk_config.py
Probably smarter to use clock wizard to calculate values, but this exists too. It currently assumes it can use a float for last clock division, which is only the case for clock 0 in `MMCME2_BASE`. Should be modified in the future to use integers.

#### convert_img_to_mem.py
Converts an image (any format supported by PIL) to a format that can be read by `$readmemh` in verilog. This is used to initialize block ram with an image.

Images should be stored in `static/images` with the name `<IMAGE_NAME>_<RES_H>x<RES_V>p<COLOR_WIDTH>.mem`. For example `banana_640x480p12.mem` for a `640x480` image of a banana with 12-bit colors (`RGB444`)

Example usage:
```bash
python tools/convert_img_to_mem.py banana.png static/images/banana.mem
```

#### convert_stl_to_mem.py
Converts a 3D STL model into our custom format. The script applies random colors to each vertex and applies a uniform winding order to all the tirangles. It produces one `.mem` file containing the entire model data and a folder with the same name as the file containing the data split into five 72 bit `.mem` files. The latter is required as Vivado did not want to synthesize BRAM with wordsizes larger than 72.

The converted models should be stored in `static/models` with the name `<MODEL_NAME>.mem`. 

Example usage:
```bash
python tools/convert_stl_to_mem.py suzanne.stl static/models/suzanne.mem
```

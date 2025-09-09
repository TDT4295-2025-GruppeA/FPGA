# TDT4295 Datamaskinprosjekt - FPGA

This repository contains the code for the fpga in our TDT4295 project.

## Table of contents
* [Quickstart](#quickstart)
* [Tools](#tools)
    * [Recommended setup](#recommended-setup-linux)
    * [Calculate clock config](#calc_display_clk_configpy)
    * [Convert image to .mem](#convert_img_to_mempy)


## Quickstart

* Install vivado
* run `make synth`
  * optionally specify target with `make synth TARGET=100t`. Currently supported targets are `100t` and `35t`
  * You can also specify board `make synth BOARD=arty7`. Currently only supports `arty7`.
* run `make flash` (again optional `TARGET=100t`)

NOTE: if using a on-board framebuffer of `12` bit color,`640x480`, the design will be too large to fit on a`Artix 7A35t`


## Tools

There are some python scripts to assist in generating parameters and files.

#### Recommended setup (linux):
To use the tools written in Python the following is recommended:

    python3 -m venv .venv
    source .venv/bin/activate
    python3 -m pip install -r tools/requirements.txt

This creates a virtual environment and install the necessary packages.

#### calc_display_clk_config.py
Probably smarter to use clock wizard to calculate values. But this exists too. It currently assumes it can use a float for last clock division, which is only the case for clock 0 in `MMCME2_BASE`. Should be modified in the future to use integers.

#### convert_img_to_mem.py
Convers an image (any format supported by PIL) to a format that can be read by `$readmemh` in verilog. This is used to initialize block ram with an image.

Images should be stored in `static` with the name `<IMAGE_NAME>_<RES_H>x<RES_V>p<COLOR_WIDTH>.mem`. For example `banana_640x480p12.mem` for a `640x480` image of a banana with 12-bit colors (`RGB444`)


## Testing

To run the testbenches simply run `make test`.

The testbenches are run using Xilinx Vivado Simulator.
This comes packaged with Vivado and is good enough for our use case.

The test runner is a simple bash script.
It loads the specified files in `tb-files.txt`.
Then, it elaborates them in the specified order.
And finally, it runs the test and simply checks if the output contained "Error".

An example testbench `src/example_tb.sv` has been provided.
It can be used as a template (if you are very lazy).

#### A note on `tb-files.txt`
It would be preferrable to not have to specify the testbench files manually.
However, Xilinx Vivado Simulator parses the files in the provided
order without any dependency analysis. If one file that depends on anohter
is provided first the parsing will fail. Thus, simple globbing will not do.
If anyone has a better suggestion please inform us.

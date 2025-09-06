# TDT4295 Datamaskinprosjekt - FPGA

This repository contains the code for the fpga in our TDT4295 project.

## Table of contents
* [Quickstart](#quickstart)
* [Tools](#tools)
    * [Recommended setup](#recommended-setup)
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

    python3 -m venv .venv
    source .venv/bin/activate
    python3 -m pip install -r tools/requirements.txt

#### calc_display_clk_config.py
Probably smarter to use clock wizard to calculate values. But this exists too. It currently assumes it can use a float for last clock division, which is only the case for clock 0 in `MMCME2_BASE`. Should be modified in the future to use integers.

#### convert_img_to_mem.py
Convers an image (any format supported by PIL) to a format that can be read by `$readmemh` in verilog. This is used to initialize block ram with an image.

Images should be stored in `static` with the name `<IMAGE_NAME>_<RES_H>x<RES_V>p<COLOR_WIDTH>.mem`. For example `banana_640x480p12.mem` for a `640x480` image of a banana with 12-bit colors (`RGB444`)
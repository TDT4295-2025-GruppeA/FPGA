#!/bin/bash

# Script to find all modules in a set of verilog files

# TODO: this does not respect if we have verilog predicates (* DONT_TOUCH *)
# for example
sed -n 's/^[[:space:]]*module[[:space:]]\+\([A-Za-z_][A-Za-z0-9_$]*\).*/\1/p' $@
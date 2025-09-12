
BUILD_TIME := $(shell date +"%Y%m%d_%H%M%S")

SOURCES := $(shell find src | grep ".\.sv")

PART_A735T_SHORT := xc7a35t_0
PART_A735T_LONG := xc7a35ticsg324-1L
PART_A7100T_SHORT := xc7a100t_0
PART_A7100T_LONG := xc7a100ticsg324-1L

TARGET ?= 35t
BOARD ?= arty7

ifeq ($(TARGET),35t)
	PART_LONG = $(PART_A735T_LONG)
	PART_SHORT = $(PART_A735T_SHORT)
else ifeq ($(TARGET),100t)
	PART_LONG = $(PART_A7100T_LONG)
	PART_SHORT = $(PART_A7100T_SHORT)
endif

.PHONY : synth flash test clean rmbuid rmgen rmlogs shell

synth:
	@echo "Synthesizing and implementing design for target $(TARGET)"
	mkdir -p build/logs
	FPGA_BOARD=$(BOARD) FPGA_TARGET="$(TARGET)" FPGA_PART_LONG="$(PART_LONG)" vivado -mode batch -source scripts/synth.tcl -journal "build/logs/synth_$(BUILD_TIME).jou"  -log "build/logs/synth_$(BUILD_TIME).log"
	rm build/lastlog.*
	ln -s logs/synth_$(BUILD_TIME).jou build/lastlog.jou
	ln -s logs/synth_$(BUILD_TIME).log build/lastlog.log
	[ -f "clockInfo.txt" ] && mv clockInfo.txt build/reports
	[ -f "tight_setup_hold_pins.txt" ] && mv tight_setup_hold_pins.txt build/reports

flash:
	@echo "Flashing FPGA target $(TARGET)"
	mkdir -p build/logs
	FPGA_TARGET="$(TARGET)" FPGA_PART_SHORT="$(PART_SHORT)" vivado -mode batch -source scripts/flash.tcl -journal "build/logs/flash_$(BUILD_TIME).jou"  -log "build/logs/flash_$(BUILD_TIME).log"

test:
	@echo "Running testbenches"
	bash scripts/test.bash

clean:
	@echo "Cleaning up"
	make rmbuid
	make rmgen
	make rmtest
	make rmlogs

rmbuid:
	@echo "Removing build files"
	rm -rf build

rmgen:
	@echo "Removing generated ip cores files"
	rm -rf ip/**/gen

rmtest:
	@echo "Removing testbench files"
	rm -rf build_tb

rmlogs:
	@echo "Removing log files"
	rm -rf build/logs

shell:
	vivado -mode tcl -journal "build/logs/synth_$(BUILD_TIME).jou"  -log "build/logs/synth_$(BUILD_TIME).log"

test:
	verilator src/clock/clock_modes.sv src/clock/clock.sv src/clock/clock_manager.sv src/display/video_modes.sv src/display/upscale_img.sv src/buffer.sv src/display/display.sv src/main.sv --binary

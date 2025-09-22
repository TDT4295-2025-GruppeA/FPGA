
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

VERILOG_SOURCES := $(shell find src -type f -name "*.*v")

# Requires build/file_compile_order.txt as dependency when used.
VERILOG_MODULES = $(shell awk '{print $$1}' build/file_compile_order.txt)

TEST_MODULES ?= $(VERILOG_MODULES)

.PHONY : synth flash test clean rmbuild rmgen rmlogs shell

synth:
	@echo "Synthesizing and implementing design for target $(TARGET)"
	mkdir -p build/logs
	FPGA_BOARD=$(BOARD) FPGA_TARGET="$(TARGET)" FPGA_PART_LONG="$(PART_LONG)" vivado -mode batch -source scripts/synth.tcl -journal "build/logs/synth_$(BUILD_TIME).jou"  -log "build/logs/synth_$(BUILD_TIME).log"
	rm -f build/lastlog.*
	ln -s logs/synth_$(BUILD_TIME).jou build/lastlog.jou
	ln -s logs/synth_$(BUILD_TIME).log build/lastlog.log
	[ ! -f "clockInfo.txt" ] || mv clockInfo.txt build/reports
	[ ! -f "tight_setup_hold_pins.txt" ] || mv tight_setup_hold_pins.txt build/reports

flash:
	@echo "Flashing FPGA target $(TARGET)"
	mkdir -p build/logs
	FPGA_TARGET="$(TARGET)" FPGA_PART_SHORT="$(PART_SHORT)" vivado -mode batch -source scripts/flash.tcl -journal "build/logs/flash_$(BUILD_TIME).jou"  -log "build/logs/flash_$(BUILD_TIME).log"

script:
	@echo "Running tcl script"
	mkdir -p build/logs
	vivado -mode batch -source $(SCRIPT) -journal "build/logs/$(SCRIPT)_$(BUILD_TIME).jou"  -log "build/logs/$(SCRIPT)_$(BUILD_TIME).log"

clean:
	@echo "Cleaning up"
	make rmbuild
	make rmgen
	make rmlogs

rmbuild:
	@echo "Removing build files"
	rm -rf build

rmgen:
	@echo "Removing generated ip cores files"
	rm -rf ip/**/gen

rmlogs:
	@echo "Removing log files"
	rm -rf build/logs

shell:
	vivado -mode tcl -journal "build/logs/synth_$(BUILD_TIME).jou"  -log "build/logs/synth_$(BUILD_TIME).log"

build/file_compile_order.txt: scripts/dependency.tcl $(VERILOG_SOURCES)
	mkdir -p build
	vivado -mode batch -journal /dev/null -log /dev/null -source scripts/dependency.tcl 2>&1 >/dev/null

test: build/file_compile_order.txt
	python testtools/gentest.py
	pytest testtools/testrunner.py -k "$(shell echo $(TEST_MODULES) | sed 's/ / or /g')"

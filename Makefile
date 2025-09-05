
BUILD_TIME := $(shell date +"%Y%m%d_%H%M%S")

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

synth:
	@echo "Synthesizing and implementing design for target $(TARGET)"
	mkdir -p build/logs
	FPGA_BOARD=$(BOARD) FPGA_TARGET="$(TARGET)" FPGA_PART_LONG="$(PART_LONG)" vivado -mode batch -source scripts/synth.tcl -journal "build/logs/synth_$(BUILD_TIME).jou"  -log "build/logs/synth_$(BUILD_TIME).log"
	rm build/lastlog.*
	ln -s logs/synth_$(BUILD_TIME).jou build/lastlog.jou
	ln -s logs/synth_$(BUILD_TIME).log build/lastlog.log

flash:
	@echo "Flashing FPGA target $(TARGET)"
	mkdir -p build/logs
	FPGA_TARGET="$(TARGET)" FPGA_PART_SHORT="$(PART_SHORT)" vivado -mode batch -source scripts/flash.tcl -journal "build/logs/flash_$(BUILD_TIME).jou"  -log "build/logs/flash_$(BUILD_TIME).log"

clean:
	rm -r build

rmlogs:
	rm -r build/logs
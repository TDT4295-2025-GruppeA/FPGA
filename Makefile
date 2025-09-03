
BUILD_TIME := $(shell date +"%Y%m%d%H%M%S")

synth:
	mkdir -p build/logs
	vivado -mode batch -source scripts/synth.tcl -journal "build/logs/$(BUILD_TIME).jou"  -log "build/logs/$(BUILD_TIME).log"

flash:
	mkdir -p build/logs
	vivado -mode batch -source scripts/flash.tcl -journal "build/logs/$(BUILD_TIME).jou"  -log "build/logs/$(BUILD_TIME).log"

clean:
	rm -r build

rmlogs:
	rm -r build/logs

BUILD_TIME := $(shell date +"%Y%m%d_%H%M%S")

synth:
	mkdir -p build/logs
	vivado -mode batch -source scripts/synth.tcl -journal "build/logs/synth_$(BUILD_TIME).jou"  -log "build/logs/synth_$(BUILD_TIME).log"
	rm build/lastlog.*
	ln -s logs/synth_$(BUILD_TIME).jou build/lastlog.jou
	ln -s logs/synth_$(BUILD_TIME).log build/lastlog.log

flash:
	mkdir -p build/logs
	vivado -mode batch -source scripts/flash.tcl -journal "build/logs/flash_$(BUILD_TIME).jou"  -log "build/logs/flash_$(BUILD_TIME).log"

clean:
	rm -r build

rmlogs:
	rm -r build/logs
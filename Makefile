synth:
	vivado -mode batch -source scripts/synth.tcl

flash:
	vivado -mode batch -source scripts/flash.tcl

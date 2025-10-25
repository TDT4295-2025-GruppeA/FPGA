set part_short $::env(FPGA_PART_SHORT)
set target $::env(FPGA_TARGET)
set top $::env(TOP)

# Open and configure hardware
open_hw_manager
connect_hw_server 
open_hw_target
current_hw_device [get_hw_devices $part_short]

# Configure program
set_property PROGRAM.FILE "build${top}_${target}.bit" [get_hw_devices $part_short]

# Program hardware
program_hw_devices [get_hw_devices $part_short]

# Configure ila
refresh_hw_device [get_hw_devices $part_short]

# Open and configure hardware
open_hw_manager
connect_hw_server 
open_hw_target
current_hw_device [get_hw_devices xc7a35t_0]

# Configure program
set_property PROGRAM.FILE {build/top.bit} [get_hw_devices xc7a35t_0]

# Program hardware
program_hw_devices [get_hw_devices xc7a35t_0]

# Configure ila
refresh_hw_device [get_hw_devices xc7a35t_0]

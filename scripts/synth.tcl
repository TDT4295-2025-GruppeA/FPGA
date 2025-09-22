package require fileutil

set_param general.maxThreads 8

set rpt_dir "build/reports"
# xc7a35ticsg324-1L
set part_long $::env(FPGA_PART_LONG)
set target $::env(FPGA_TARGET)
set board $::env(FPGA_BOARD)

# Load configuration and code
read_verilog [ fileutil::findByPattern src *.*v ]

# Synthesize

# Basys 3
#read_xdc verilog/vivado/constraints/basys3_cpu.xdc
# synth_design -top Top -part xc7a35tcpg236-1

# Nexys A7
# read_xdc verilog/vivado/constraints/nexysa7_cpu.xdc
# synth_design -top Top -part xc7a100tcsg324-1

# Arty A7
read_xdc constraints/${board}.xdc
synth_design -top Top -part $part_long

write_checkpoint -force $rpt_dir/post_synth_checkpoint

# Implement
opt_design
place_design
route_design

write_checkpoint -force $rpt_dir/post_route_checkpoint

# Generate post-routing reports
report_power -file $rpt_dir/post_route_power.rpt
report_utilization -file $rpt_dir/post_route_utilization.rpt
report_timing -delay_type min_max -max_paths 1 -file $rpt_dir/post_route_timing.rpt

# Write bitstream result
file mkdir -p build
write_bitstream -force build/top_${target}.bit

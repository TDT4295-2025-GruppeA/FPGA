package require fileutil

set_param general.maxThreads 8

set rpt_dir "build/reports"
# xc7a35ticsg324-1L
set part_long $::env(FPGA_PART_LONG)
set target $::env(FPGA_TARGET)
set board $::env(FPGA_BOARD)

#########
# Setup #
#########

# Create temporary project
# This is required to generate and synthesize ip cores.
create_project -in_memory -part $part_long

# Load ip cores
# TODO: Make it so that the ip config file is not dependent on the target part.
read_ip [ fileutil::findByPattern ip *.*xci ]

# Generate ip cores
generate_target all [get_ips]

# Load source files
read_verilog [ fileutil::findByPattern src *.*v ]

#############
# Synthesis #
#############

# Load constratins for Arty A7
read_xdc constraints/${board}.xdc

synth_design -top Top

write_checkpoint -force $rpt_dir/post_synth_checkpoint

#################
# Place & Route #
#################

opt_design
place_design
route_design

write_checkpoint -force $rpt_dir/post_route_checkpoint

# Generate post-routing reports
report_power -file $rpt_dir/post_route_power.rpt
report_utilization -file $rpt_dir/post_route_utilization.rpt
report_utilization -hierarchical -file $rpt_dir/post_route_utilization_hierarchical.rpt -hierarchical_depth 5
report_timing -delay_type min_max -max_paths 1 -file $rpt_dir/post_route_timing.rpt

#############
# Bitstream #
#############

# Ensure build directory exists
exec mkdir -p build

write_bitstream -force build/top_${target}.bit

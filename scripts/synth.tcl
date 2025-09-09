package require fileutil

set_param general.maxThreads 8

set rpt_dir "build/reports"
# xc7a35ticsg324-1L
set part_long $::env(FPGA_PART_LONG)
set target $::env(FPGA_TARGET)
set board $::env(FPGA_BOARD)

# Set the target part for the rest of the script
set_part $part_long

# Generate IP cores
read_ip ip/mig_ddr3/mig_ddr3.xci
generate_target all [get_ips mig_ddr3]

# Load configuration and code
read_verilog [ fileutil::findByPattern src *.*v ]

read_xdc constraints/${board}.xdc
# read_xdc constraints/${board}_ddr3.xdc

# Synthesize design
synth_design -top Top

write_checkpoint -force $rpt_dir/_design_synth_checkpoint

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
exec mkdir -p build
write_bitstream -force build/top_${target}.bit

# Script to generate compile order of verilog, respecting dependencies.
# This is primarily to set file input order into verilator.
# While verilator is able to resolve dependencies of modules, it is
# not able to resolve dependencies of packages. In addition, inserting
# all files into verilator will result in it watching all source files
# for changes, even though most files are not relevant for the specified
# module. This leads to unnessecary many re-compilations.
package require fileutil

read_verilog [ fileutil::findByPattern src *.*v ]


# Find modules to include in dependency analysis
set modules {}
foreach file [get_files] {
    set names [exec ./scripts/find_modules.sh $file]
    foreach name [split $names "\n"] {
        lappend modules $name
    }
}

# TODO: ability to change path
set fh [open "build/file_compile_order.txt" w]

set_property verilog_define SIMULATION [current_fileset]
set_property source_mgmt_mode All [current_project]
foreach item $modules {
    set_property top $item [current_fileset]
    set files [get_files -compile_order sources -used_in simulation -of_objects [ get_filesets sources_1 ]]
    set file_list [join $files ":"]
    puts $fh "$item $file_list"
}

close $fh

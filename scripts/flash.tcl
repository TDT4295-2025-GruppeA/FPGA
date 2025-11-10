set part_short $::env(FPGA_PART_SHORT)
set target $::env(FPGA_TARGET)
set top $::env(TOP)
set flash_mode $::env(FLASH_MODE)

set bit_file "build/${top}_${target}.bit"
set mcs_file "build/${top}_${target}.mcs"

open_hw_manager
connect_hw_server
open_hw_target

set dev [get_hw_devices $part_short]
current_hw_device $dev
refresh_hw_device $dev

if {$flash_mode eq "flash"} {
    puts "Writing to flash"

    # TODO: Make this configurable.
    set cfgmem_name "mt25ql128-spi-x1_x2_x4"
    create_hw_cfgmem -hw_device $dev $cfgmem_name

    # Create MCS file from bitfile.
    write_cfgmem -force \
        -format mcs \
        -size 128 \
        -interface SPIx4 \
        -loadbit "up 0x0 $bit_file" \
        $mcs_file

    # Set programming properties.
    # This configuration was copied from the Vivado GUI.
    set cfgmem_obj [get_hw_cfgmems]
    set_property PROGRAM.ADDRESS_RANGE  {entire_device} $cfgmem_obj
    set_property PROGRAM.FILES [list $mcs_file ] $cfgmem_obj
    set_property PROGRAM.UNUSED_PIN_TERMINATION {pull-none} $cfgmem_obj
    set_property PROGRAM.BLANK_CHECK  0 $cfgmem_obj
    set_property PROGRAM.ERASE  0 $cfgmem_obj
    set_property PROGRAM.CFG_PROGRAM  1 $cfgmem_obj
    set_property PROGRAM.VERIFY  1 $cfgmem_obj
    set_property PROGRAM.CHECKSUM  0 $cfgmem_obj

    # Write configuration to flash.
    # This sequence of commands was also copied from the Vivado GUI.
    create_hw_bitstream -hw_device $dev [get_property PROGRAM.HW_CFGMEM_BITFILE $dev];
    program_hw_devices $dev;
    refresh_hw_device $dev;
    program_hw_cfgmem -hw_cfgmem [ get_property PROGRAM.HW_CFGMEM $dev]

    # Restart device with new configuration.
    boot_hw_device [get_hw_devices $part_short]
} elseif {$flash_mode eq "ram"} {
    puts "Writing to RAM"

    # Specify bitstream file to program.
    set_property PROGRAM.FILE $bit_file $dev

    # Write to RAM.
    program_hw_devices $dev
} else {
    puts "Unknown flash mode: $flash_mode"
    exit 1
}

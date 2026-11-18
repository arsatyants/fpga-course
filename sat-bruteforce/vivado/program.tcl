# Залить top.bit по JTAG.
# Run:   cd vivado && vivado -mode batch -source program.tcl
set script_dir [file normalize [file dirname [info script]]]
open_hw_manager
connect_hw_server
open_hw_target
set dev [lindex [get_hw_devices xc7z010*] 0]
current_hw_device $dev
set_property PROGRAM.FILE $script_dir/top.bit $dev
program_hw_devices $dev
puts "=== PROGRAMMED ==="

# Vivado Hardware Manager: прошити top.bit + top.ltx (ELF уже в bitstream).
# Run:  cd hw && vivado -mode batch -source program.tcl   (hold_ps.tcl має працювати)
open_hw_manager
connect_hw_server -url localhost:3121
open_hw_target
set dev [lindex [get_hw_devices xc7z010*] 0]
current_hw_device $dev
set_property PROGRAM.FILE ../vivado/top.bit $dev
set_property PROBES.FILE  ../vivado/top.ltx $dev
set_property FULL_PROBES.FILE ../vivado/top.ltx $dev
program_hw_devices $dev
refresh_hw_device $dev
set ila [lindex [get_hw_ilas -of $dev] 0]
puts "ILA: $ila  depth [get_property CONTROL.DATA_DEPTH $ila]"
foreach p [get_hw_probes -of $ila] { puts "PROBE [get_property NAME $p] width [get_property WIDTH $p]" }

# Lesson 14: системна Behavioral Simulation top (без ILA) з ELF lesson12 у LMB.
# Run:   cd vivado && vivado -mode batch -source sim.tcl
set script_dir [file normalize [file dirname [info script]]]
cd $script_dir
open_project ./ILA_FRAME_DMA/ILA_FRAME_DMA.xpr

set tb [file normalize ../tb/tb_top.v]
if {[llength [get_files -quiet -of [get_filesets sim_1] $tb]] == 0} { add_files -fileset sim_1 -norecurse $tb }
set_property top tb_top [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
set_property verilog_define {NO_ILA} [get_filesets sim_1]
update_compile_order -fileset sim_1

set elf [file normalize ../../lesson12/vitis/frame_dma_mb.elf]
if {[llength [get_files -quiet -of [get_filesets sim_1] $elf]] == 0} { add_files -fileset sim_1 -norecurse $elf }
set_property SCOPED_TO_REF   design_1     [get_files -of [get_filesets sim_1] $elf]
set_property SCOPED_TO_CELLS microblaze_0 [get_files -of [get_filesets sim_1] $elf]

set_property -name {xsim.simulate.runtime} -value {8ms} -objects [get_filesets sim_1]
set_property -name {xsim.simulate.log_all_signals} -value {false} -objects [get_filesets sim_1]
launch_simulation -simset sim_1 -mode behavioral
close_sim -quiet
set d ./ILA_FRAME_DMA/ILA_FRAME_DMA.sim/sim_1/behav/xsim
file copy -force $d/ila_probes.vcd ../docs/sim_probes.vcd
puts "=== SIM DONE ==="

# Behavioral simulation of LED_AXI_GPIO_MB with the real Vitis ELF running on MicroBlaze.
# Usage (from this directory): vivado -mode batch -source sim.tcl
# The ELF is attached to microblaze_0 in sim_1, so xsim loads it into LMB BRAM (no updatemem / /tmp files).
set script_dir [file dirname [file normalize [info script]]]
cd $script_dir

set elf [file normalize $script_dir/../../vitis/LED_AXI_GPIO_MB_app.elf]
if {![file exists $elf]} { error "ELF not found: $elf" }

open_project ./LED_AXI_GPIO_MB.xpr

# The wrapper lives in *.gen (not versioned) -> regenerate it and add it to sources_1 if the project lacks it.
set bd [get_files design_1.bd]
if {[llength [get_files -quiet design_1_wrapper.v]] == 0} {
    generate_target all $bd
    set wrap [make_wrapper -files $bd -top]
    add_files -norecurse $wrap
}
set_property top design_1_wrapper [get_filesets sources_1]
update_compile_order -fileset sources_1

if {[lsearch -glob [get_files -of [get_filesets sim_1]] *tb_design_1.v] == -1} {
    add_files -fileset sim_1 -norecurse ./tb_design_1.v
}
set_property top tb_design_1 [get_filesets sim_1]

if {[lsearch -glob [get_files -of [get_filesets sim_1]] *LED_AXI_GPIO_MB_app.elf] == -1} {
    add_files -fileset sim_1 -norecurse $elf
}
set elf_file [get_files -of [get_filesets sim_1] *LED_AXI_GPIO_MB_app.elf]
set_property used_in_simulation true $elf_file
set_property SCOPED_TO_CELLS {microblaze_0} $elf_file
set_property SCOPED_TO_REF design_1 $elf_file

set_property -name xsim.simulate.runtime -value 0ns -objects [get_filesets sim_1]
set_property -name xsim.simulate.log_all_signals -value true -objects [get_filesets sim_1]

launch_simulation
run all
puts "=== SIM DONE ==="
close_sim

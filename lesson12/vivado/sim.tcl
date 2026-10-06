# Step 3: Behavioral Simulation of the whole system with the real MicroBlaze ELF.
# Prerequisites: create_project.tcl (project) + ../vitis/build_app.sh (ELF).
# Run:   cd vivado && vivado -mode batch -source sim.tcl
# GUI:   open FRAME_DMA_MB/FRAME_DMA_MB.xpr -> Run Simulation -> Behavioral.
set script_dir [file normalize [file dirname [info script]]]
cd $script_dir

open_project ./FRAME_DMA_MB/FRAME_DMA_MB.xpr

# ---- testbench ----
set tb_dir [file normalize ../tb]
foreach f [list $tb_dir/tb_design_1.v $tb_dir/pix_source.vh] {
    if {[llength [get_files -quiet -of [get_filesets sim_1] $f]] == 0} {
        add_files -fileset sim_1 -norecurse $f
    }
}
set_property file_type {Verilog Header} [get_files -of [get_filesets sim_1] $tb_dir/pix_source.vh]
set_property include_dirs $tb_dir [get_filesets sim_1]
set_property top tb_design_1 [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
update_compile_order -fileset sim_1

# ---- ELF -> MicroBlaze local memory (Vivado builds the BRAM init for the simulator) ----
set elf [file normalize ../vitis/frame_dma_mb.elf]
if {[llength [get_files -quiet -of [get_filesets sim_1] $elf]] == 0} {
    add_files -fileset sim_1 -norecurse $elf
}
set_property SCOPED_TO_REF   design_1     [get_files -of [get_filesets sim_1] $elf]
set_property SCOPED_TO_CELLS microblaze_0 [get_files -of [get_filesets sim_1] $elf]

set_property -name {xsim.simulate.runtime} -value {12ms} -objects [get_filesets sim_1]
set_property -name {xsim.simulate.log_all_signals} -value {false} -objects [get_filesets sim_1]

launch_simulation -simset sim_1 -mode behavioral
close_sim -quiet

puts "=== SIM DONE ==="
puts "Log: [file normalize ./FRAME_DMA_MB/FRAME_DMA_MB.sim/sim_1/behav/xsim/simulate.log]"

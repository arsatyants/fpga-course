# Step 4 (optional, for the board): synth + impl + bitstream with the ELF baked
# into MicroBlaze local memory, and an XSA with the bitstream.
# Run:   cd vivado && vivado -mode batch -source impl.tcl
set script_dir [file normalize [file dirname [info script]]]
cd $script_dir

open_project ./FRAME_DMA_MB/FRAME_DMA_MB.xpr

set elf [file normalize ../vitis/frame_dma_mb.elf]
if {[llength [get_files -quiet -of [get_filesets sources_1] $elf]] == 0} {
    add_files -fileset sources_1 -norecurse $elf
}
set_property SCOPED_TO_REF   design_1     [get_files -of [get_filesets sources_1] $elf]
set_property SCOPED_TO_CELLS microblaze_0 [get_files -of [get_filesets sources_1] $elf]

reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} { error "synth failed" }

launch_runs impl_1 -jobs 4 -to_step write_bitstream
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} { error "impl/bitstream failed" }

open_run impl_1
report_utilization -file ./utilization.rpt
report_timing_summary -file ./timing_summary.rpt
puts "WNS: [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]"

file copy -force ./FRAME_DMA_MB/FRAME_DMA_MB.runs/impl_1/design_1_wrapper.bit ./design_1_wrapper.bit
write_hw_platform -fixed -include_bit -force ./design_1_wrapper.xsa

puts "=== DONE ==="
puts "Bitstream: [file normalize ./design_1_wrapper.bit]"

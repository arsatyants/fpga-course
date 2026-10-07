# Lesson 14, крок 2: synth + impl + bitstream + .ltx (probes file для Hardware Manager).
# Run:   cd vivado && vivado -mode batch -source impl.tcl
set script_dir [file normalize [file dirname [info script]]]
cd $script_dir
open_project ./ILA_FRAME_DMA/ILA_FRAME_DMA.xpr

# OOC-рани IP, які не дійшли до 100% (напр. убиті OOM), лишають маркер
# __synthesis_is_running__, і synth_1 чекає на них вічно -> скинути.
foreach r [get_runs -filter {IS_SYNTHESIS && NAME != synth_1}] {
    if {[get_property PROGRESS $r] ne "100%"} { puts "reset stale $r"; reset_run $r }
}
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} { error "synth failed" }

launch_runs impl_1 -jobs 4 -to_step write_bitstream
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} { error "impl/bitstream failed" }

open_run impl_1
report_utilization -file ./utilization.rpt
report_utilization -hierarchical -hierarchical_depth 2 -file ./utilization_hier.rpt
report_timing_summary -file ./timing_summary.rpt
puts "WNS: [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]"
puts "WHS: [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -hold]]"

file copy -force ./ILA_FRAME_DMA/ILA_FRAME_DMA.runs/impl_1/top.bit ./top.bit
file copy -force ./ILA_FRAME_DMA/ILA_FRAME_DMA.runs/impl_1/top.ltx ./top.ltx
puts "=== DONE ==="

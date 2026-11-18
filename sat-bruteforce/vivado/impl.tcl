# sat-bruteforce, шаг 2: synth + impl + bitstream + отчёты.
# Run:   cd vivado && vivado -mode batch -source impl.tcl
set script_dir [file normalize [file dirname [info script]]]
cd $script_dir
open_project ./SAT_BRUTEFORCE/SAT_BRUTEFORCE.xpr

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

file copy -force ./SAT_BRUTEFORCE/SAT_BRUTEFORCE.runs/impl_1/top.bit ./top.bit
puts "=== DONE ==="

# sat-bruteforce, шаг 1: проект Vivado.
# Run:   cd vivado && vivado -mode batch -source create_project.tcl
# Формула берётся из formula.mem / formula_params.vh в этой папке (tools/gen_cnf.py --out ../vivado).
# Число ядер: -tclargs LOGP, по умолчанию 6 (64 ядра).
set script_dir [file normalize [file dirname [info script]]]
cd $script_dir

set proj_name "SAT_BRUTEFORCE"
set part "xc7z010clg400-1"
set logp [expr {$argc > 0 ? [lindex $argv 0] : 6}]

create_project -force $proj_name ./$proj_name -part $part

add_files -norecurse [list \
    [file normalize ../rtl/top.v] \
    [file normalize ../rtl/sat_bruteforce.v] \
    [file normalize ../rtl/uart_tx.v] \
    [file normalize ./formula_params.vh] \
    [file normalize ./formula.mem]]
set_property file_type {Verilog Header} [get_files formula_params.vh]
set_property file_type {Memory Initialization Files} [get_files formula.mem]
set_property include_dirs [list $script_dir] [get_filesets sources_1]
set_property generic "LOGP=$logp" [get_filesets sources_1]

set_property top top [get_filesets sources_1]
update_compile_order -fileset sources_1

add_files -fileset constrs_1 -norecurse ./top.xdc

puts "=== PROJECT CREATED (LOGP=$logp) ==="

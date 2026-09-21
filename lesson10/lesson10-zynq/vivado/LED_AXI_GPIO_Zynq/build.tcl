#!/bin/bash
# Rebuild Vivado project for lesson_10 HW, ZYNQ variant (LED running light).
# Board: MicroPhase Z7-Lite-ES1 (xc7z010clg400-1), onboard 50 MHz PL clock.
# Pins: PL_LED1=P15, PL_LED2=U12, PL_KEY1=P16, PL_KEY2=T12, PL_CLK_50M=N18.
# Run:   vivado -mode batch -source build.tcl
set script_dir [file dirname [info script]]
cd $script_dir

set proj_name "LED_AXI_GPIO_Zynq"
set part "xc7z010clg400-1"

create_project -force $proj_name . -part $part

# ---- Block design ----
source ./bd.tcl

# ---- Constraints ----
add_files -fileset constrs_1 -norecurse ./design_1.xdc

# ---- Generate wrapper ----
make_wrapper -files [get_files ./LED_AXI_GPIO_Zynq.srcs/sources_1/bd/design_1/design_1.bd] -top
add_files -norecurse ./LED_AXI_GPIO_Zynq.gen/sources_1/bd/design_1/hdl/design_1_wrapper.v
update_compile_order -fileset sources_1

# ---- Synth / impl / bitstream ----
set_property top design_1_wrapper [current_fileset]
launch_runs synth_1 -jobs 4
wait_on_run synth_1
set synth_attempt 1
while {[get_property PROGRESS [get_runs synth_1]] ne "100%" && $synth_attempt < 5} {
    puts "=== synth attempt $synth_attempt failed, retrying ==="
    reset_run synth_1
    launch_runs synth_1 -jobs 4
    wait_on_run synth_1
    incr synth_attempt
}
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} { error "synth failed after retries" }

launch_runs impl_1 -jobs 8 -to_step write_bitstream
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} { error "impl/bitstream failed" }

# ---- Export XSA ----
write_hw_platform -fixed -include_bit -force ./design_1_wrapper.xsa

puts "=== DONE ==="
puts "Bitstream: [file normalize ./$proj_name.runs/impl_1/design_1_wrapper.bit]"
puts "XSA:       [file normalize ./design_1_wrapper.xsa]"
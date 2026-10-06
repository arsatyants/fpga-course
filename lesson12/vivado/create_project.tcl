# Step 1: create Vivado project + block design, export pre-synthesis XSA for Vitis.
# Board: MicroPhase Z7-Lite-ES1 (xc7z010clg400-1).
# Run:   cd vivado && vivado -mode batch -source create_project.tcl
set script_dir [file normalize [file dirname [info script]]]
cd $script_dir

set proj_name "FRAME_DMA_MB"
set part "xc7z010clg400-1"

create_project -force $proj_name ./$proj_name -part $part

# ---- IP repo: axi4_full_ram (packaged IP from lecture example) ----
set_property ip_repo_paths [file normalize ../ip_repo] [current_project]
update_ip_catalog

# ---- Own RTL (used in BD as module reference) ----
add_files -norecurse [list [file normalize ../rtl/frame_rx_axis.v] [file normalize ../rtl/async_fifo.v]]
update_compile_order -fileset sources_1

# ---- Block design ----
source ./bd.tcl

# ---- Constraints ----
add_files -fileset constrs_1 -norecurse ./design_1.xdc

# ---- Wrapper ----
set bd_file [get_files design_1.bd]
make_wrapper -files $bd_file -top
add_files -norecurse ./$proj_name/$proj_name.gen/sources_1/bd/design_1/hdl/design_1_wrapper.v
set_property top design_1_wrapper [get_filesets sources_1]
update_compile_order -fileset sources_1
generate_target all $bd_file

# ---- Pre-synthesis XSA (enough for BSP/app build in Vitis) ----
write_hw_platform -fixed -force ./design_1_wrapper.xsa

puts "=== PROJECT CREATED ==="
puts "XSA: [file normalize ./design_1_wrapper.xsa]"

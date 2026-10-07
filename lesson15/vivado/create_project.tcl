# Lesson 15: Vivado-проєкт для перевірки HLS IP moving_max (версія pipe) Verilog-тестбенчем.
# Run:   cd vivado && vivado -mode batch -source create_project.tcl
#   IP береться з hls/pipe/moving_max/moving_max.zip (результат vitis-run --package, є в git)
#   і розпаковується в ./ip_repo/moving_max.
set script_dir [file normalize [file dirname [info script]]]
cd $script_dir
set proj moving_max_sim

create_project -force $proj ./$proj -part xc7z010clg400-1
set_property target_language Verilog [current_project]
file delete -force ./ip_repo
file mkdir ./ip_repo/moving_max
exec unzip -q -o [file normalize ../hls/pipe/moving_max/moving_max.zip] -d ./ip_repo/moving_max
set_property ip_repo_paths [file normalize ./ip_repo] [current_project]
update_ip_catalog

create_ip -vlnv xilinx.com:hls:moving_max:1.0 -module_name moving_max_0
generate_target all [get_ips moving_max_0]

add_files -fileset sim_1 -norecurse [file normalize ../tb/tb_moving_max.v]
set_property top tb_moving_max [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {all} -objects [get_filesets sim_1]
update_compile_order -fileset sim_1
puts "=== PROJECT CREATED ==="

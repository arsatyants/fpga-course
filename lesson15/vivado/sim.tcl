# Lesson 15: Behavioral Simulation tb_moving_max (batch). Run:  cd vivado && vivado -mode batch -source sim.tcl
set script_dir [file normalize [file dirname [info script]]]
cd $script_dir
open_project ./moving_max_sim/moving_max_sim.xpr
launch_simulation -simset sim_1 -mode behavioral
run all
close_sim
puts "=== SIM DONE ==="

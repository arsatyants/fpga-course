# Lesson 15: симуляція tb_moving_max у Vivado GUI -- для скриншотів docs/vivado_sim_*.png
# (docs/screenshot.py робить їх на віртуальному дисплеї Xvfb).
#   vivado -mode gui -source sim_gui.tcl -tclargs <zoom_from_ns> <zoom_to_ns>
# Зум задається через .wcfg (Tcl-команд зуму у Vivado немає): спершу сигнали
# додаються add_wave і зберігаються, потім у файл дописується zoom_setting і він відкривається знову.
lassign $argv z0 z1
set script_dir [file normalize [file dirname [info script]]]
cd $script_dir
open_project ./moving_max_sim/moving_max_sim.xpr
launch_simulation -simset sim_1 -mode behavioral
close_wave_config -force [current_wave_config]
create_wave_config tb
set tb /tb_moving_max
add_wave $tb/clk $tb/ap_start $tb/ap_done $tb/ap_idle
add_wave -radix dec $tb/vec
add_wave -radix unsigned $tb/in_data_address0
add_wave $tb/in_data_ce0
add_wave -radix dec $tb/in_sample
add_wave -radix unsigned $tb/out_data_address0
add_wave $tb/out_data_we0
add_wave -radix dec $tb/out_sample
run all
set f [file normalize ./tb_moving_max.wcfg]
save_wave_config $f
close_wave_config -force [current_wave_config]
set h [open $f]; set w [read $h]; close $h
set zoom "<zoom_setting>\n      <ZoomStartTime time=\"[expr {$z0*1000}]ps\"></ZoomStartTime>\n      <ZoomEndTime time=\"[expr {$z1*1000}]ps\"></ZoomEndTime>\n   </zoom_setting>"
regsub {<zoom_setting>.*?</zoom_setting>} $w $zoom w
set h [open $f w]; puts -nonewline $h $w; close $h
open_wave_config $f
set h [open ./gui_ready w]; puts $h ok; close $h

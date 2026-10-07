# Vivado Hardware Manager: один захват ILA (плата вже прошита program.tcl).
#   vivado -mode batch -source ila_capture.tcl -tclargs start   -- Advanced Trigger (TSM, ila_frame_start.tsm):
#        фронт start від MicroBlaze, ПОТІМ перший pix_fsync & pix_valid -> перший піксель
#        захопленого кадру. Буває рівно раз на натискання KEY2.
#   vivado -mode batch -source ila_capture.tcl -tclargs end     -- Basic trigger:
#        спад busy (frame_rx_axis віддав останнє слово кадру) -- теж раз на натискання.
# Результат: captures/<mode>.ila (відкривається в Vivado: read_hw_ila_data + display_hw_ila_data),
#            captures/<mode>.csv, captures/<mode>.vcd
set mode [lindex $argv 0]
set tmo  [expr {[llength $argv] > 1 ? [lindex $argv 1] : 10}]  ;# хвилин чекати на натискання
set out  [file normalize ./captures]
file mkdir $out
proc mark {msg} { set f [open ./ila_status.txt a]; puts $f "[clock format [clock seconds] -format %T] $msg"; close $f; puts $msg }

open_hw_manager
connect_hw_server -url localhost:3121
open_hw_target
set dev [lindex [get_hw_devices xc7z010*] 0]
current_hw_device $dev
set_property PROBES.FILE      ../vivado/top.ltx $dev
set_property FULL_PROBES.FILE ../vivado/top.ltx $dev
refresh_hw_device $dev
set ila [lindex [get_hw_ilas -of $dev] 0]

proc probe {pat} { global ila; return [lindex [get_hw_probes -of $ila -filter "NAME =~ \"$pat\""] 0] }
set p_data  [probe *pix_data*]
set p_valid [probe *pix_valid*]
set p_fsync [probe *pix_fsync*]
set p_start [probe *dbg_start*]
# probe4 = {led[0], dbg_status[1:0], btn} у .ltx розпадається на окремі сигнали за іменами нетів
set p_stat  [probe *dbg_status*]   ;# [1]=overflow [0]=busy
mark "probes: $p_data | $p_valid | $p_fsync | $p_start | $p_stat"

reset_hw_ila $ila
set_property CONTROL.DATA_DEPTH 32768 $ila
set_property CONTROL.CAPTURE_MODE ALWAYS $ila
foreach p [get_hw_probes -of $ila] { set_property TRIGGER_COMPARE_VALUE "eq[get_property WIDTH $p]'h[string repeat X [expr {([get_property WIDTH $p]+3)/4}]]" $p }

if {$mode eq "start"} {
    # Advanced Trigger: двостанова TSM. Ім'я проби в TSM = ім'я з .ltx.
    set tsm [file normalize ./ila_frame_start.tsm]
    set f [open $tsm w]
    puts $f "# Lesson 14: перший піксель кадру, захопленого ПІСЛЯ фронту start"
    puts $f "state wait_start:"
    puts $f "    if ($p_start == 1'bR) then"
    puts $f "        goto wait_fsync;"
    puts $f "    else"
    puts $f "        goto wait_start;"
    puts $f "    endif"
    puts $f ""
    puts $f "state wait_fsync:"
    puts $f "    if (($p_fsync == 1'b1) && ($p_valid == 1'b1)) then"
    puts $f "        trigger;"
    puts $f "    else"
    puts $f "        goto wait_fsync;"
    puts $f "    endif"
    close $f
    set_property CONTROL.TRIGGER_MODE ADVANCED_ONLY $ila
    set_property CONTROL.TSM_FILE $tsm $ila
    set_property CONTROL.TRIGGER_POSITION 4096 $ila
} else {
    # Basic: спад busy (dbg_status[0])
    set_property CONTROL.TRIGGER_MODE BASIC_ONLY $ila
    set_property CONTROL.TRIGGER_CONDITION AND $ila
    set_property TRIGGER_COMPARE_VALUE eq2'bXF $p_stat
    set_property CONTROL.TRIGGER_POSITION 31000 $ila
}

run_hw_ila $ila
mark "ARMED $mode -- press KEY2"
wait_on_hw_ila -timeout $tmo $ila
set st [get_property STATUS.CORE_STATUS $ila]
mark "core status: $st"
if {$st ne "FULL" && $st ne "IDLE"} { mark "NO TRIGGER"; exit 1 }

set data [upload_hw_ila_data $ila]
write_hw_ila_data -force $out/$mode.ila $data
write_hw_ila_data -force -csv_file $out/$mode.csv $data
write_hw_ila_data -force -vcd_file $out/$mode.vcd $data
mark "CAPTURED $mode -> $out/$mode.ila"

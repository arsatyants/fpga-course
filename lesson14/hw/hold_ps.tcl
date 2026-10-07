# xsdb: зупинити обидва ядра Cortex-A9 і тримати їх зупиненими, поки скрипт живий.
# Плата Z7-Lite вантажиться з SD, і програма на ARM перепрошиває PL через кілька
# секунд після JTAG-програмування -- без цього ILA/MicroBlaze зникають.
# Run (у фоні, на весь час роботи з платою):  xsdb hold_ps.tcl
connect
foreach c {"ARM Cortex-A9 MPCore #0*" "ARM Cortex-A9 MPCore #1*"} {
    targets -set -filter "name =~ \"$c\""
    catch {stop}
}
set f [open hold_ps.status w]; puts $f "PS HALTED [clock format [clock seconds] -format %T]"; close $f
while {1} { after 5000 }

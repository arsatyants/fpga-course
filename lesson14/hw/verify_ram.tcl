# xsdb: прочитати весь кадр з axi4_full_ram (0xC000_0000, 16000 слів) через MicroBlaze
# і порівняти з формулою генератора: pix(x,y,f) = (x + 2y + 7f) & 0xFF.
# Номер кадру f -- з першого пікселя: 7f = b mod 256 -> f = 183*b mod 256.
connect
targets -set -filter {name =~ "MicroBlaze #0*"}
stop
set w [mrd -force -value 0xC0000000 16000]
foreach {n a} {led 0x40010000 DMASR 0x41E00034 LENGTH 0x41E00058} { puts [format "%-7s 0x%08X" $n [lindex [mrd -force -value $a 1] 0]] }
con
set b0 [expr {[lindex $w 0] & 0xFF}]
set f [expr {(183 * $b0) & 0xFF}]
set bad 0
for {set i 0} {$i < 16000} {incr i} {
    set e 0
    for {set k 3} {$k >= 0} {incr k -1} {
        set p [expr {$i*4 + $k}]
        set e [expr {($e << 8) | ((($p % 320) + 2*($p / 320) + 7*$f) & 0xFF)}]
    }
    if {[lindex $w $i] != $e} { if {$bad < 5} { puts [format "MISMATCH word %d: 0x%08X exp 0x%08X" $i [lindex $w $i] $e] }; incr bad }
}
puts "RAM: frame f=$f (mod 256), first word [format 0x%08X [lindex $w 0]], last word [format 0x%08X [lindex $w end]], mismatches $bad / 16000"

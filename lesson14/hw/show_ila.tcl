# Vivado GUI: показати захват ILA з captures/<mode>.ila (без плати) -- для скриншотів docs/vivado_ila_*.png.
# Зум навколо тригера, курсор на тригері, pix_data як аналоговий графік.
#   vivado -mode gui -source show_ila.tcl -tclargs start 3700 6100 4096
#   vivado -mode gui -source show_ila.tcl -tclargs end 29000 31600 31000
# Аргументи -- номери семплів. Зум і стиль задаються через .wcfg (Tcl-команд зуму у Vivado немає);
# -wcfg діє лише при ПЕРШОМУ display_hw_ila_data. Одиниця часу у .wcfg для ILA: 1 семпл = 1 ps.
lassign $argv mode z0 z1 cur
set here [file dirname [file normalize [info script]]]
set cap  $here/captures/$mode.ila
open_hw_manager
set d [read_hw_ila_data $cap]
set f [open $here/ila_template.wcfg]; set w [read $f]; close $f
set zoom "\t<zoom_setting>\n\t\t<ZoomStartTime time=\"${z0}ps\"></ZoomStartTime>\n\t\t<ZoomEndTime time=\"${z1}ps\"></ZoomEndTime>\n\t\t<Cursor1Time time=\"${cur}ps\"></Cursor1Time>\n\t</zoom_setting>\n\t<column_width_setting>\n\t\t<NameColumnWidth column_width=\"170\"></NameColumnWidth>\n\t\t<ValueColumnWidth column_width=\"60\"></ValueColumnWidth>\n\t</column_width_setting>\n\t<WVObjectSize"
set w [string map [list "\t<WVObjectSize" $zoom] $w]
set ana "<obj_property name=\"Radix\">UNSIGNEDDECRADIX</obj_property>\n\t\t<obj_property name=\"WaveformStyle\">STYLE_ANALOG</obj_property>\n\t\t<obj_property name=\"CellHeight\">90</obj_property>"
regsub {(fp_name="pix_data".*?)<obj_property name="Radix">HEXRADIX</obj_property>} $w "\\1$ana" w
set f [open $here/captures/$mode.wcfg w]; puts -nonewline $f $w; close $f
display_hw_ila_data -wcfg $here/captures/$mode.wcfg $d

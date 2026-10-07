# Lesson 14: BD lesson12 (../../lesson12/vivado/bd.tcl) без змін логіки + виводи для top.v:
#   * clk_wiz: clk_out2 = 40 МГц -> pix_clk_o (такт генератора кадрів у top.v);
#   * aclk_o = clk_out1 (100 МГц) -> такт ILA;
#   * dbg_start / dbg_status -- внутрішні сигнали BD назовні, для проб ILA.
source [file normalize ../../lesson12/vivado/bd.tcl]

set_property -dict [list CONFIG.CLKOUT2_USED {true} CONFIG.CLKOUT2_REQUESTED_OUT_FREQ {40.000}] [get_bd_cells clk_wiz_0]

create_bd_port -dir O -type clk aclk_o
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_ports aclk_o]
create_bd_port -dir O -type clk pix_clk_o
connect_bd_net [get_bd_pins clk_wiz_0/clk_out2] [get_bd_ports pix_clk_o]

create_bd_port -dir O -from 0 -to 0 dbg_start
connect_bd_net [get_bd_pins axi_gpio_0/gpio2_io_o] [get_bd_ports dbg_start]
create_bd_port -dir O -from 1 -to 0 dbg_status
connect_bd_net [get_bd_pins frame_rx_0/status] [get_bd_ports dbg_status]

validate_bd_design
save_bd_design

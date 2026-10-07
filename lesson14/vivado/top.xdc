# Constraints, lesson 14 -- MicroPhase Z7-Lite-ES1 (XC7Z010 CLG400).
# Як lesson12/vivado/design_1.xdc, але піксельна шина тепер внутрішня
# (pix_pattern_gen у top.v), тож пінів JP1 і create_clock pix_clk немає.

set_property -dict {PACKAGE_PIN N18 IOSTANDARD LVCMOS33} [get_ports clk_50m]
create_clock -period 20.000 -name clk_50m [get_ports clk_50m]
set_property -dict {PACKAGE_PIN P16 IOSTANDARD LVCMOS33 PULLUP true} [get_ports rst_n]
set_property -dict {PACKAGE_PIN T12 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {btn[0]}]
set_property -dict {PACKAGE_PIN P15 IOSTANDARD LVCMOS33} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN U12 IOSTANDARD LVCMOS33} [get_ports {led[1]}]

# pix_clk (40 МГц) і aclk (100 МГц) обидва з clk_wiz, але генератор кадрів імітує
# ЗОВНІШНЮ камеру з власним тактом -> як і в lesson12, домени вважаємо асинхронними:
# перехід лише через Gray-FIFO та 2-FF синхронізатори frame_rx_axis.
set_clock_groups -asynchronous \
    -group [get_clocks -of_objects [get_pins -hier -filter {NAME =~ */clk_wiz_0/inst/mmcm_adv_inst/CLKOUT0}]] \
    -group [get_clocks -of_objects [get_pins -hier -filter {NAME =~ */clk_wiz_0/inst/mmcm_adv_inst/CLKOUT1}]]

set_false_path -from [get_ports {btn[*] rst_n}]

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

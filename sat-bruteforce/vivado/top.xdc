# sat-bruteforce — MicroPhase Z7-Lite-ES1 (XC7Z010 CLG400), чистый PL без PS.
# Пины clk/rst_n/btn/led — как в lesson14. uart_tx — на JP2 (тот же пин G15, что `q` в lesson4):
# подключить RX USB-UART адаптера 3.3 В к этому пину, GND к GND. Бортовой USB-UART висит на PS (MIO),
# из чистого PL до него не достать.

set_property -dict {PACKAGE_PIN N18 IOSTANDARD LVCMOS33} [get_ports clk_50m]
create_clock -period 20.000 -name clk_50m [get_ports clk_50m]

set_property -dict {PACKAGE_PIN P16 IOSTANDARD LVCMOS33 PULLUP true} [get_ports rst_n]
set_property -dict {PACKAGE_PIN T12 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {btn[0]}]
set_property -dict {PACKAGE_PIN P15 IOSTANDARD LVCMOS33} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN U12 IOSTANDARD LVCMOS33} [get_ports {led[1]}]
set_property -dict {PACKAGE_PIN G15 IOSTANDARD LVCMOS33} [get_ports uart_tx]

set_false_path -from [get_ports {btn[*] rst_n}]
set_false_path -to   [get_ports {led[*] uart_tx}]

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

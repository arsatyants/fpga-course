# Z7-Lite-ES1 pin constraints for lesson4 `top` module.
# clk -> onboard PL_CLK_50M (bank13). All other ports -> JP2 header (bank35),
# which is entirely free on this standalone (non-ethernet) project.
# Pin table source: docs/source/DEV_BOARD/Z7-LITE/Z7-Lite_Reference_Manual.md
# in ~/code/z7-lite-es1 (JP2 GPIO2_0..17 P/N table).
#
# leds[14:0] -> JP2 header pins 24-40 (physical LED strip location),
# in ascending header-pin order. Pins 29/30 are GND/VCC on this header,
# not GPIO, so they're skipped.

set_property PACKAGE_PIN N18     [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 20.000 -name clk [get_ports clk]

set_property PACKAGE_PIN L16     [get_ports reset]
set_property IOSTANDARD LVCMOS33 [get_ports reset]
set_property PULLTYPE PULLDOWN   [get_ports reset]

set_property PACKAGE_PIN H15     [get_ports d]
set_property IOSTANDARD LVCMOS33 [get_ports d]
set_property PULLTYPE PULLDOWN   [get_ports d]

set_property PACKAGE_PIN G15     [get_ports q]
set_property IOSTANDARD LVCMOS33 [get_ports q]

# onboard PL_LED1 - JTAG/clock sanity check, independent of external JP2 wiring
set_property PACKAGE_PIN P15     [get_ports heartbeat]
set_property IOSTANDARD LVCMOS33 [get_ports heartbeat]

# leds[0] = JP2 pin 31 (GPIO2_13P) ... leds[7] = JP2 pin 38 (GPIO2_16N)
set_property PACKAGE_PIN L19     [get_ports {leds[0]}]
set_property PACKAGE_PIN L20     [get_ports {leds[1]}]
set_property PACKAGE_PIN F19     [get_ports {leds[2]}]
set_property PACKAGE_PIN F20     [get_ports {leds[3]}]
set_property PACKAGE_PIN M19     [get_ports {leds[4]}]
set_property PACKAGE_PIN M20     [get_ports {leds[5]}]
set_property PACKAGE_PIN K19     [get_ports {leds[6]}]
set_property PACKAGE_PIN J19     [get_ports {leds[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports {leds[*]}]

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

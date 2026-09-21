# Constraints for MicroPhase Z7-Lite-ES1 (XC7Z010 CLG400) - MicroBlaze variant
# LED running light: onboard PL_LED1 (P15), PL_LED2 (U12),
# buttons PL_KEY1 (P16), PL_KEY2 (T12), 50 MHz PL clock on N18.
# LEDs are active-LOW on this board; keys are active-LOW (pressed = low).

# ---- Clock + reset ----
set_property -dict {PACKAGE_PIN N18 IOSTANDARD LVCMOS33} [get_ports clk_50m]
create_clock -period 20.000 -name clk_50m [get_ports clk_50m]
set_property -dict {PACKAGE_PIN P16 IOSTANDARD LVCMOS33} [get_ports rst_n]
# PL_KEY1 pressed = LOW, so rst_n = pressed -> held in reset; release = run.
# Alternative: tie rst_n high via pullup and use KEY for something else.
set_property PULLUP true [get_ports rst_n]

# ---- LEDs (active low) ----
set_property -dict {PACKAGE_PIN P15 IOSTANDARD LVCMOS33} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN U12 IOSTANDARD LVCMOS33} [get_ports {led[1]}]
# Only 2 onboard PL LEDs; led[2:3] routed to spare JP1 pins (GPIO1_2N U17, GPIO1_7N Y14)
set_property -dict {PACKAGE_PIN U17 IOSTANDARD LVCMOS33} [get_ports {led[2]}]
set_property -dict {PACKAGE_PIN Y14 IOSTANDARD LVCMOS33} [get_ports {led[3]}]

# ---- Buttons (active low) ----
set_property -dict {PACKAGE_PIN T12 IOSTANDARD LVCMOS33} [get_ports {btn[0]}]
# btn[1:3] unused on hardware - routed to spare JP1 pins, pulled up
set_property -dict {PACKAGE_PIN W18 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {btn[1]}]
set_property -dict {PACKAGE_PIN Y16 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {btn[2]}]
set_property -dict {PACKAGE_PIN W14 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {btn[3]}]

# ---- Switches ----
# Board has no onboard DIP switches; sw routed to spare JP1 pins, pulled up.
set_property -dict {PACKAGE_PIN V17 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {sw[0]}]
set_property -dict {PACKAGE_PIN V18 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {sw[1]}]

# ---- I/O banking ----
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
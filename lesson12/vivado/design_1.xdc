# Constraints, lesson 12 homework -- MicroPhase Z7-Lite-ES1 (XC7Z010 CLG400)
# JP1 header map: see z7-lite-es1/bringup/z7lite_ada107_jp1.xdc (user-verified).

# ---- System clock + reset ----
set_property -dict {PACKAGE_PIN N18 IOSTANDARD LVCMOS33} [get_ports clk_50m]
create_clock -period 20.000 -name clk_50m [get_ports clk_50m]
# PL_KEY1 (active-low) = reset
set_property -dict {PACKAGE_PIN P16 IOSTANDARD LVCMOS33 PULLUP true} [get_ports rst_n]

# ---- Button "start capture": PL_KEY2, active-low ----
set_property -dict {PACKAGE_PIN T12 IOSTANDARD LVCMOS33 PULLUP true} [get_ports {btn[0]}]

# ---- LEDs (active-low): led[0] = frame OK, led[1] = error ----
set_property -dict {PACKAGE_PIN P15 IOSTANDARD LVCMOS33} [get_ports {led[0]}]
set_property -dict {PACKAGE_PIN U12 IOSTANDARD LVCMOS33} [get_ports {led[1]}]

# ---- External pixel bus on JP1 ----
# pix_clk must be on a clock-capable pin: U14 = IO_L11P_T1_SRCC_34 (JP1-35)
set_property -dict {PACKAGE_PIN U14 IOSTANDARD LVCMOS33} [get_ports pix_clk]
create_clock -period 25.000 -name pix_clk [get_ports pix_clk]
set_property -dict {PACKAGE_PIN N17 IOSTANDARD LVCMOS33} [get_ports pix_valid]     ;# JP1-1
set_property -dict {PACKAGE_PIN P18 IOSTANDARD LVCMOS33} [get_ports pix_fsync]     ;# JP1-2
set_property -dict {PACKAGE_PIN T16 IOSTANDARD LVCMOS33} [get_ports {pix_data[0]}] ;# JP1-5
set_property -dict {PACKAGE_PIN U17 IOSTANDARD LVCMOS33} [get_ports {pix_data[1]}] ;# JP1-6
set_property -dict {PACKAGE_PIN W18 IOSTANDARD LVCMOS33} [get_ports {pix_data[2]}] ;# JP1-7
set_property -dict {PACKAGE_PIN W19 IOSTANDARD LVCMOS33} [get_ports {pix_data[3]}] ;# JP1-8
set_property -dict {PACKAGE_PIN Y18 IOSTANDARD LVCMOS33} [get_ports {pix_data[4]}] ;# JP1-9
set_property -dict {PACKAGE_PIN Y19 IOSTANDARD LVCMOS33} [get_ports {pix_data[5]}] ;# JP1-10
set_property -dict {PACKAGE_PIN Y16 IOSTANDARD LVCMOS33} [get_ports {pix_data[6]}] ;# JP1-13
set_property -dict {PACKAGE_PIN Y17 IOSTANDARD LVCMOS33} [get_ports {pix_data[7]}] ;# JP1-14

# Source launches data on the falling edge of pix_clk (half period = 12.5 ns
# before capture). Assume up to 3 ns source/board skew around that edge.
set_input_delay -clock pix_clk -clock_fall -max 3.0 [get_ports {pix_data[*] pix_valid pix_fsync}]
set_input_delay -clock pix_clk -clock_fall -min -3.0 [get_ports {pix_data[*] pix_valid pix_fsync}]

# pix_clk and the 100 MHz system clock are asynchronous; the crossing goes
# only through the Gray-coded FIFO pointers and 2-FF synchronizers.
set_clock_groups -asynchronous -group [get_clocks pix_clk] -group [get_clocks -include_generated_clocks clk_50m]

# Button / reset are asynchronous to everything
set_false_path -from [get_ports {btn[*] rst_n}]

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

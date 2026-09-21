# Block design for MicroBlaze variant: MicroBlaze + AXI GPIO (LED/btn/sw) + AXI Timer.
# LED running-light homework, Z7-Lite-ES1.
create_bd_design "design_1"

# ---- Clocking + reset (50 MHz PL clock, active-low) ----
create_bd_port -dir I -type clk clk_50m
set_property -dict [list CONFIG.FREQ_HZ {50000000}] [get_bd_ports clk_50m]
create_bd_port -dir I -type rst rst_n

# Clocking wizard: 50 MHz -> 100 MHz for MicroBlaze
create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_0
set_property -dict [list CONFIG.PRIM_IN_FREQ {50.000} CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {100.000} CONFIG.RESET_TYPE {ACTIVE_LOW}] [get_bd_cells clk_wiz_0]
connect_bd_net [get_bd_ports clk_50m] [get_bd_pins clk_wiz_0/clk_in1]

create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_100M
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins rst_100M/slowest_sync_clk]
connect_bd_net [get_bd_ports rst_n] [get_bd_pins rst_100M/ext_reset_in]
connect_bd_net [get_bd_ports rst_n] [get_bd_pins clk_wiz_0/resetn]
connect_bd_net [get_bd_pins clk_wiz_0/locked] [get_bd_pins rst_100M/dcm_locked]

# ---- MicroBlaze ----
create_bd_cell -type ip -vlnv xilinx.com:ip:microblaze:11.0 microblaze_0
set_property -dict [list \
    CONFIG.C_DEBUG_ENABLED {1} \
    CONFIG.C_D_AXI {1} \
    CONFIG.C_D_LMB {1} \
    CONFIG.C_I_LMB {1} \
    CONFIG.C_ICACHE_LINE_LEN {4} \
    CONFIG.C_IRQ_IS_LEVEL {1} \
    CONFIG.C_USE_MSR_INSTR {1} \
    CONFIG.C_USE_BARREL {1} \
    CONFIG.C_USE_HW_MUL {1} \
    CONFIG.C_USE_DIV {1} \
    CONFIG.C_NUMBER_OF_PC_BRK {2} \
    CONFIG.C_NUMBER_OF_B_BRK {1} \
] [get_bd_cells microblaze_0]

# ---- Local memory + axi_periph + axi_intc via automation ----
apply_bd_automation -rule xilinx.com:bd_rule:microblaze -config {local_mem "64KB" ecc "None" cache "None" debug_module "None" axi_periph "Enabled" axi_intc "1" clk "/clk_wiz_0/clk_out1 (100 MHz)"} [get_bd_cells microblaze_0]

# Expand interconnect masters: M00 auto-wired to intc; add M01-M04 for periphs
set_property -dict [list CONFIG.NUM_MI {5}] [get_bd_cells microblaze_0_axi_periph]

# ---- AXI GPIO: LED (output) ----
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_0
set_property -dict [list CONFIG.C_GPIO_WIDTH {4} CONFIG.C_IS_DUAL {0} CONFIG.C_ALL_OUTPUTS {1}] [get_bd_cells axi_gpio_0]

# ---- AXI GPIO: buttons (input) ----
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_1
set_property -dict [list CONFIG.C_GPIO_WIDTH {4} CONFIG.C_IS_DUAL {0} CONFIG.C_ALL_INPUTS {1} CONFIG.C_INTERRUPT_PRESENT {1}] [get_bd_cells axi_gpio_1]

# ---- AXI GPIO: switches (input) ----
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_2
set_property -dict [list CONFIG.C_GPIO_WIDTH {2} CONFIG.C_IS_DUAL {0} CONFIG.C_ALL_INPUTS {1}] [get_bd_cells axi_gpio_2]

# ---- AXI Timer ----
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_timer:2.0 axi_timer_0

# ---- Connect to MicroBlaze AXI peripheral interconnect (automation wired M00 to intc AXI) ----
connect_bd_intf_net [get_bd_intf_pins axi_gpio_0/S_AXI] [get_bd_intf_pins microblaze_0_axi_periph/M01_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_gpio_1/S_AXI] [get_bd_intf_pins microblaze_0_axi_periph/M02_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_gpio_2/S_AXI] [get_bd_intf_pins microblaze_0_axi_periph/M03_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_timer_0/S_AXI] [get_bd_intf_pins microblaze_0_axi_periph/M04_AXI]

# ---- Clocks to periphs ----
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins axi_gpio_0/s_axi_aclk]
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins axi_gpio_1/s_axi_aclk]
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins axi_gpio_2/s_axi_aclk]
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins axi_timer_0/s_axi_aclk]
connect_bd_net [get_bd_pins rst_100M/peripheral_aresetn] [get_bd_pins axi_gpio_0/s_axi_aresetn]
connect_bd_net [get_bd_pins rst_100M/peripheral_aresetn] [get_bd_pins axi_gpio_1/s_axi_aresetn]
connect_bd_net [get_bd_pins rst_100M/peripheral_aresetn] [get_bd_pins axi_gpio_2/s_axi_aresetn]
connect_bd_net [get_bd_pins rst_100M/peripheral_aresetn] [get_bd_pins axi_timer_0/s_axi_aresetn]

# ---- Timer interrupt -> MicroBlaze via interrupt controller ----
# Automation already wired intc Interrupt/clk/rst to MicroBlaze; just hook the timer IRQ.
# Automation wired intc intr <- xlconcat; hook timer IRQ into concat input 0
connect_bd_net [get_bd_pins axi_timer_0/interrupt] [get_bd_pins microblaze_0_xlconcat/In0]

# ---- External ports ----
make_bd_pins_external [get_bd_pins axi_gpio_0/gpio_io_o] -name led
make_bd_pins_external [get_bd_pins axi_gpio_1/gpio_io_i] -name btn
make_bd_pins_external [get_bd_pins axi_gpio_2/gpio_io_i] -name sw

# ---- Address segments ----
assign_bd_address -target_address_space /microblaze_0/Data [get_bd_addr_segs {axi_gpio_0/S_AXI/Reg}] -offset 0x41210000 -range 0x10000
assign_bd_address -target_address_space /microblaze_0/Data [get_bd_addr_segs {axi_gpio_1/S_AXI/Reg}] -offset 0x41220000 -range 0x10000
assign_bd_address -target_address_space /microblaze_0/Data [get_bd_addr_segs {axi_gpio_2/S_AXI/Reg}] -offset 0x41230000 -range 0x10000
assign_bd_address -target_address_space /microblaze_0/Data [get_bd_addr_segs {axi_timer_0/S_AXI/Reg}] -offset 0x41C00000 -range 0x10000

validate_bd_design
save_bd_design
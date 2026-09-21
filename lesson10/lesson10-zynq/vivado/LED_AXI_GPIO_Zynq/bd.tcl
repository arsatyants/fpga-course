# Block design for Zynq variant: PS7 + 3x AXI GPIO + AXI Timer.
# LED running-light homework, Z7-Lite-ES1.
create_bd_design "design_1"

# ---- Zynq PS ----
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {make_external "Fix External" apply_board_preset "1" Master "Disable" Slave "Disable"} [get_bd_cells processing_system7_0]
set_property -dict [list CONFIG.PCW_USE_S_AXI_HP0 {0}] [get_bd_cells processing_system7_0]

# PS7 presets for Z7-Lite (DDR + UART via MIO, standard MicroPhase config)
set_property -dict [list \
    CONFIG.PCW_UART0_PERIPHERAL_ENABLE {1} \
    CONFIG.PCW_UART0_UART0_IO {MIO} \
    CONFIG.PCW_SD0_PERIPHERAL_ENABLE {1} \
    CONFIG.PCW_SD0_SD0_IO {MIO} \
    CONFIG.PCW_USB0_PERIPHERAL_ENABLE {1} \
    CONFIG.PCW_USB0_USB0_IO {MIO 28 .. 39} \
    CONFIG.PCW_ENET0_PERIPHERAL_ENABLE {1} \
    CONFIG.PCW_ENET0_ENET0_IO {MIO 16 .. 27} \
    CONFIG.PCW_ENET0_GRP_MDIO_IO {EMIO} \
    CONFIG.PCW_GPIO_PERIPHERAL_ENABLE {1} \
    CONFIG.PCW_I2C0_PERIPHERAL_ENABLE {0} \
    CONFIG.PCW_IRQ_F2P_INTR {1} \
    CONFIG.PCW_USE_FABRIC_INTERRUPT {1} \
] [get_bd_cells processing_system7_0]

# ---- AXI GPIO: LED (output) ----
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_0
set_property -dict [list CONFIG.C_GPIO_WIDTH {4} CONFIG.C_IS_DUAL {0} CONFIG.C_ALL_OUTPUTS {1}] [get_bd_cells axi_gpio_0]

# ---- AXI GPIO: buttons (input) ----
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_1
set_property -dict [list CONFIG.C_GPIO_WIDTH {4} CONFIG.C_IS_DUAL {0} CONFIG.C_ALL_INPUTS {1}] [get_bd_cells axi_gpio_1]

# ---- AXI GPIO: switches (input) ----
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_2
set_property -dict [list CONFIG.C_GPIO_WIDTH {2} CONFIG.C_IS_DUAL {0} CONFIG.C_ALL_INPUTS {1}] [get_bd_cells axi_gpio_2]

# ---- AXI Timer ----
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_timer:2.0 axi_timer_0

# ---- Smartconnect + reset ----
create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_smc
set_property -dict [list CONFIG.NUM_SI {1} CONFIG.NUM_MI {4}] [get_bd_cells axi_smc]

create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_ps7_0_50M

# ---- Connections ----
connect_bd_intf_net [get_bd_intf_pins processing_system7_0/M_AXI_GP0] [get_bd_intf_pins axi_smc/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_smc/M00_AXI] [get_bd_intf_pins axi_gpio_0/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_smc/M01_AXI] [get_bd_intf_pins axi_gpio_1/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_smc/M02_AXI] [get_bd_intf_pins axi_gpio_2/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_smc/M03_AXI] [get_bd_intf_pins axi_timer_0/S_AXI]

connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins processing_system7_0/M_AXI_GP0_ACLK]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins axi_smc/aclk]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins axi_gpio_0/s_axi_aclk]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins axi_gpio_1/s_axi_aclk]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins axi_gpio_2/s_axi_aclk]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins axi_timer_0/s_axi_aclk]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins rst_ps7_0_50M/slowest_sync_clk]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_RESET0_N] [get_bd_pins rst_ps7_0_50M/ext_reset_in]
connect_bd_net [get_bd_pins rst_ps7_0_50M/peripheral_aresetn] [get_bd_pins axi_smc/aresetn]
connect_bd_net [get_bd_pins rst_ps7_0_50M/peripheral_aresetn] [get_bd_pins axi_gpio_0/s_axi_aresetn]
connect_bd_net [get_bd_pins rst_ps7_0_50M/peripheral_aresetn] [get_bd_pins axi_gpio_1/s_axi_aresetn]
connect_bd_net [get_bd_pins rst_ps7_0_50M/peripheral_aresetn] [get_bd_pins axi_gpio_2/s_axi_aresetn]
connect_bd_net [get_bd_pins rst_ps7_0_50M/peripheral_aresetn] [get_bd_pins axi_timer_0/s_axi_aresetn]

# ---- External ports ----
make_bd_pins_external [get_bd_pins axi_gpio_0/gpio_io_o] -name led
make_bd_pins_external [get_bd_pins axi_gpio_1/gpio_io_i] -name btn
make_bd_pins_external [get_bd_pins axi_gpio_2/gpio_io_i] -name sw

# Timer interrupt -> PS IRQ (via IRQ_F2P)
connect_bd_net [get_bd_pins axi_timer_0/interrupt] [get_bd_pins processing_system7_0/IRQ_F2P]

# ---- Address segments ----
assign_bd_address -target_address_space /processing_system7_0/Data [get_bd_addr_segs {axi_gpio_0/S_AXI/Reg}] -offset 0x41200000 -range 0x10000
assign_bd_address -target_address_space /processing_system7_0/Data [get_bd_addr_segs {axi_gpio_1/S_AXI/Reg}] -offset 0x41210000 -range 0x10000
assign_bd_address -target_address_space /processing_system7_0/Data [get_bd_addr_segs {axi_gpio_2/S_AXI/Reg}] -offset 0x41220000 -range 0x10000
assign_bd_address -target_address_space /processing_system7_0/Data [get_bd_addr_segs {axi_timer_0/S_AXI/Reg}] -offset 0x41C00000 -range 0x10000

validate_bd_design
save_bd_design
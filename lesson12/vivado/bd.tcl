# Block design, lesson 12 homework (based on Example "Project 3" DMA_MB_3):
#   MicroBlaze + AXI GPIO (button/start, LED/status) + frame_rx_axis (own module)
#   + AXI DMA (S2MM only, simple mode) + axi4_full_ram (64 KB = 320x200 frame).
# Board: MicroPhase Z7-Lite-ES1, 50 MHz PL clock -> clk_wiz -> 100 MHz.
create_bd_design "design_1"

# ---- Clocking + reset (50 MHz PL clock, active-low reset) ----
create_bd_port -dir I -type clk -freq_hz 50000000 clk_50m
create_bd_port -dir I -type rst rst_n
set_property CONFIG.POLARITY ACTIVE_LOW [get_bd_ports rst_n]

create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_0
set_property -dict [list CONFIG.PRIM_IN_FREQ {50.000} CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {100.000} CONFIG.RESET_TYPE {ACTIVE_LOW}] [get_bd_cells clk_wiz_0]
connect_bd_net [get_bd_ports clk_50m] [get_bd_pins clk_wiz_0/clk_in1]

create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_100M
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1] [get_bd_pins rst_100M/slowest_sync_clk]
connect_bd_net [get_bd_ports rst_n] [get_bd_pins rst_100M/ext_reset_in]
connect_bd_net [get_bd_ports rst_n] [get_bd_pins clk_wiz_0/resetn]
connect_bd_net [get_bd_pins clk_wiz_0/locked] [get_bd_pins rst_100M/dcm_locked]

set clk  [get_bd_pins clk_wiz_0/clk_out1]
set rstn [get_bd_pins rst_100M/peripheral_aresetn]

# ---- MicroBlaze + 64 KB local memory + MDM (JTAG debug / ELF download) ----
create_bd_cell -type ip -vlnv xilinx.com:ip:microblaze:11.0 microblaze_0
apply_bd_automation -rule xilinx.com:bd_rule:microblaze -config {local_mem "64KB" ecc "None" cache "None" debug_module "Debug Only" axi_periph "Disabled" axi_intc "0" clk "/clk_wiz_0/clk_out1 (100 MHz)"} [get_bd_cells microblaze_0]
set_property -dict [list \
    CONFIG.C_D_AXI {1} \
    CONFIG.C_USE_BARREL {1} \
    CONFIG.C_USE_HW_MUL {1} \
    CONFIG.C_USE_DIV {1} \
] [get_bd_cells microblaze_0]

# ---- SmartConnect: 2 masters (MicroBlaze data, DMA S2MM) -> 4 slaves ----
create_bd_cell -type ip -vlnv xilinx.com:ip:smartconnect:1.0 axi_smc
set_property -dict [list CONFIG.NUM_SI {2} CONFIG.NUM_MI {4}] [get_bd_cells axi_smc]
connect_bd_net $clk  [get_bd_pins axi_smc/aclk]
connect_bd_net $rstn [get_bd_pins axi_smc/aresetn]

# ---- AXI DMA: S2MM only, Simple (no Scatter Gather), 16-bit length (64000 B) ----
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 axi_dma_0
set_property -dict [list \
    CONFIG.c_include_sg {0} \
    CONFIG.c_sg_length_width {16} \
    CONFIG.c_include_mm2s {0} \
    CONFIG.c_include_s2mm {1} \
    CONFIG.c_m_axi_s2mm_data_width {32} \
    CONFIG.c_s_axis_s2mm_tdata_width {32} \
    CONFIG.c_s2mm_burst_size {16} \
    CONFIG.c_addr_width {32} \
] [get_bd_cells axi_dma_0]
connect_bd_net $clk  [get_bd_pins axi_dma_0/s_axi_lite_aclk] [get_bd_pins axi_dma_0/m_axi_s2mm_aclk]
connect_bd_net $rstn [get_bd_pins axi_dma_0/axi_resetn]

# ---- axi4_full_ram: 320*200 B = 64000 B = 16000 x 32-bit words ----
#      ADDR_WIDTH 16 -> 64 KB address window (>= 64000), MEM_DEPTH 16000 words
create_bd_cell -type ip -vlnv xilinx.com:user:axi4_full_ram:1.0 axi4_full_ram_0
set_property -dict [list CONFIG.DATA_WIDTH {32} CONFIG.ADDR_WIDTH {16} CONFIG.MEM_DEPTH {16000}] [get_bd_cells axi4_full_ram_0]
connect_bd_net $clk  [get_bd_pins axi4_full_ram_0/s_axi_aclk]
connect_bd_net $rstn [get_bd_pins axi4_full_ram_0/s_axi_aresetn]

# ---- Own module: frame receiver -> M_AXIS ----
create_bd_cell -type module -reference frame_rx_axis frame_rx_0
connect_bd_net $clk  [get_bd_pins frame_rx_0/aclk]
connect_bd_net $rstn [get_bd_pins frame_rx_0/aresetn]
connect_bd_intf_net [get_bd_intf_pins frame_rx_0/m_axis] [get_bd_intf_pins axi_dma_0/S_AXIS_S2MM]

# external pixel bus (the "data from outside" ports)
create_bd_port -dir I -type clk -freq_hz 40000000 pix_clk
create_bd_port -dir I -from 7 -to 0 pix_data
create_bd_port -dir I pix_valid
create_bd_port -dir I pix_fsync
connect_bd_net [get_bd_ports pix_clk]   [get_bd_pins frame_rx_0/pix_clk]
connect_bd_net [get_bd_ports pix_data]  [get_bd_pins frame_rx_0/pix_data]
connect_bd_net [get_bd_ports pix_valid] [get_bd_pins frame_rx_0/pix_valid]
connect_bd_net [get_bd_ports pix_fsync] [get_bd_pins frame_rx_0/pix_fsync]

# ---- AXI GPIO 0: ch1 = button (in, 1 bit, active-low), ch2 = start (out, 1 bit) ----
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_0
set_property -dict [list \
    CONFIG.C_GPIO_WIDTH {1}  CONFIG.C_ALL_INPUTS {1} \
    CONFIG.C_IS_DUAL {1} \
    CONFIG.C_GPIO2_WIDTH {1} CONFIG.C_ALL_OUTPUTS_2 {1} \
] [get_bd_cells axi_gpio_0]
connect_bd_net $clk  [get_bd_pins axi_gpio_0/s_axi_aclk]
connect_bd_net $rstn [get_bd_pins axi_gpio_0/s_axi_aresetn]
make_bd_pins_external [get_bd_pins axi_gpio_0/gpio_io_i] -name btn
connect_bd_net [get_bd_pins axi_gpio_0/gpio2_io_o] [get_bd_pins frame_rx_0/start]

# ---- AXI GPIO 1: ch1 = LEDs (out, 2 bit), ch2 = frame_rx status {overflow, busy} (in) ----
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_1
set_property -dict [list \
    CONFIG.C_GPIO_WIDTH {2}  CONFIG.C_ALL_OUTPUTS {1} CONFIG.C_DOUT_DEFAULT {0x00000003} \
    CONFIG.C_IS_DUAL {1} \
    CONFIG.C_GPIO2_WIDTH {2} CONFIG.C_ALL_INPUTS_2 {1} \
] [get_bd_cells axi_gpio_1]
connect_bd_net $clk  [get_bd_pins axi_gpio_1/s_axi_aclk]
connect_bd_net $rstn [get_bd_pins axi_gpio_1/s_axi_aresetn]
make_bd_pins_external [get_bd_pins axi_gpio_1/gpio_io_o] -name led
connect_bd_net [get_bd_pins frame_rx_0/status] [get_bd_pins axi_gpio_1/gpio2_io_i]

# ---- AXI connections ----
connect_bd_intf_net [get_bd_intf_pins microblaze_0/M_AXI_DP]   [get_bd_intf_pins axi_smc/S00_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_dma_0/M_AXI_S2MM]    [get_bd_intf_pins axi_smc/S01_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_smc/M00_AXI] [get_bd_intf_pins axi_dma_0/S_AXI_LITE]
connect_bd_intf_net [get_bd_intf_pins axi_smc/M01_AXI] [get_bd_intf_pins axi4_full_ram_0/s_axi]
connect_bd_intf_net [get_bd_intf_pins axi_smc/M02_AXI] [get_bd_intf_pins axi_gpio_0/S_AXI]
connect_bd_intf_net [get_bd_intf_pins axi_smc/M03_AXI] [get_bd_intf_pins axi_gpio_1/S_AXI]

# ---- Address map ----
assign_bd_address -target_address_space /microblaze_0/Data [get_bd_addr_segs {axi_gpio_0/S_AXI/Reg}]        -offset 0x40000000 -range 64K
assign_bd_address -target_address_space /microblaze_0/Data [get_bd_addr_segs {axi_gpio_1/S_AXI/Reg}]        -offset 0x40010000 -range 64K
assign_bd_address -target_address_space /microblaze_0/Data [get_bd_addr_segs {axi_dma_0/S_AXI_LITE/Reg}]    -offset 0x41E00000 -range 64K
assign_bd_address -target_address_space /microblaze_0/Data [get_bd_addr_segs {axi4_full_ram_0/s_axi/reg0}]  -offset 0xC0000000 -range 64K
# DMA sees only the frame RAM. axi4_full_ram is packaged with usage "register",
# so Vivado auto-excludes it from the DMA's "memory" space -> include explicitly.
assign_bd_address -target_address_space /axi_dma_0/Data_S2MM [get_bd_addr_segs {axi4_full_ram_0/s_axi/reg0}] -offset 0xC0000000 -range 64K
foreach seg [get_bd_addr_segs -excluded axi_dma_0/Data_S2MM/*axi4_full_ram*] { include_bd_addr_seg $seg }
foreach s {axi_gpio_0/S_AXI/Reg axi_gpio_1/S_AXI/Reg axi_dma_0/S_AXI_LITE/Reg} {
    catch { exclude_bd_addr_seg -target_address_space [get_bd_addr_spaces axi_dma_0/Data_S2MM] [get_bd_addr_segs $s] }
}

validate_bd_design
save_bd_design

# Lesson 14, крок 1: проєкт = lesson12 (BD, RTL, IP, ELF) + генератор кадрів + ILA (HDL Instantiation).
# Run:   cd vivado && vivado -mode batch -source create_project.tcl
set script_dir [file normalize [file dirname [info script]]]
cd $script_dir

set proj_name "ILA_FRAME_DMA"
set part "xc7z010clg400-1"
set l12 [file normalize ../../lesson12]

create_project -force $proj_name ./$proj_name -part $part

set_property ip_repo_paths [file normalize $l12/ip_repo] [current_project]
update_ip_catalog

# ---- RTL: frame_rx_axis + async_fifo з lesson12 без змін, власні top + генератор ----
add_files -norecurse [list $l12/rtl/frame_rx_axis.v $l12/rtl/async_fifo.v]
update_compile_order -fileset sources_1

# ---- BD lesson12 + виводи для top/ILA ----
source ./bd_lesson14.tcl
set bd_file [get_files design_1.bd]
make_wrapper -files $bd_file -top
add_files -norecurse ./$proj_name/$proj_name.gen/sources_1/bd/design_1/hdl/design_1_wrapper.v
generate_target all $bd_file

add_files -norecurse [list [file normalize ../rtl/top.v] [file normalize ../rtl/pix_pattern_gen.v]]

# ---- ILA з IP Catalog (Debug & Verification -> Debug -> ILA), 5 проб ----
create_ip -name ila -vendor xilinx.com -library ip -module_name ila_0
set_property -dict [list \
    CONFIG.C_NUM_OF_PROBES     {5} \
    CONFIG.C_PROBE0_WIDTH      {8} \
    CONFIG.C_PROBE1_WIDTH      {1} \
    CONFIG.C_PROBE2_WIDTH      {1} \
    CONFIG.C_PROBE3_WIDTH      {1} \
    CONFIG.C_PROBE4_WIDTH      {4} \
    CONFIG.C_DATA_DEPTH        {32768} \
    CONFIG.C_ADV_TRIGGER       {true} \
    CONFIG.C_EN_STRG_QUAL      {1} \
    CONFIG.ALL_PROBE_SAME_MU_CNT {2} \
    CONFIG.C_INPUT_PIPE_STAGES {0} \
] [get_ips ila_0]
generate_target all [get_ips ila_0]
create_ip_run [get_ips ila_0]

set_property top top [get_filesets sources_1]
update_compile_order -fileset sources_1

add_files -fileset constrs_1 -norecurse ./top.xdc

# ELF lesson12 (та сама карта адрес) -> LMB MicroBlaze у bitstream
set elf $l12/vitis/frame_dma_mb.elf
add_files -fileset sources_1 -norecurse $elf
set_property SCOPED_TO_REF   design_1     [get_files -of [get_filesets sources_1] $elf]
set_property SCOPED_TO_CELLS microblaze_0 [get_files -of [get_filesets sources_1] $elf]

puts "=== PROJECT CREATED ==="

#!/bin/bash
# Build Vitis platform + app for Zynq lesson10 (LED running light).
# Run with: xsct build_zynq.tcl
set script_dir [file dirname [info script]]
cd $script_dir

set XSA ../../vivado/LED_AXI_GPIO_Zynq/design_1_wrapper.xsa
set PLATFORM_NAME "LED_AXI_GPIO_Zynq_plat"
set APP_NAME "LED_AXI_GPIO_Zynq_app"

# ---- Platform ----
platform create -name $PLATFORM_NAME -hw $XSA -out ./export -fsbl-target fsbl
platform config -updatehw $XSA
domain create -name standalone -proc ps7_cortexa9_0 -os standalone
platform generate
puts "=== Platform generated ==="

# ---- App ----
setws ./ws
platform read ./export/LED_AXI_GPIO_Zynq_plat/platform.spr
platform active $PLATFORM_NAME
config platform_repo ./export
config platform_repo -add ./export
puts "repo: [config platform_repo]"
app create -name $APP_NAME -platform $PLATFORM_NAME -domain standalone -template "Hello World"
# Replace src with our app
file delete -force $APP_NAME/src/helloworld.c
file mkdir $APP_NAME/src
file copy -force ./main.c $APP_NAME/src/main.c
app build -name $APP_NAME
puts "=== App built ==="
puts "ELF: [file normalize $APP_NAME/build/$APP_NAME.elf]"
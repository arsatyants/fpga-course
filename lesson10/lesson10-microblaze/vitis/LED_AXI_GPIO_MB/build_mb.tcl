#!/bin/bash
# Build Vitis platform + app for MicroBlaze lesson10 (2026.1 xsct).
# Run with: xsct build_mb.tcl
set script_dir [file dirname [info script]]
cd $script_dir

set XSA ../../vivado/LED_AXI_GPIO_MB/design_1_wrapper.xsa
set PLATFORM_NAME "LED_AXI_GPIO_MB_plat"
set APP_NAME "LED_AXI_GPIO_MB_app"

# ---- Platform ----
platform create -name $PLATFORM_NAME -hw $XSA -out ./export
platform generate
puts "=== Platform generated ==="

# ---- App ----
setws ./ws
platform read ./export/$PLATFORM_NAME/platform.spr
platform active $PLATFORM_NAME
app create -name $APP_NAME -platform $PLATFORM_NAME -domain standalone -template "Hello World"
file delete -force $APP_NAME/src/helloworld.c
file mkdir $APP_NAME/src
file copy -force ./main.c $APP_NAME/src/main.c
app build -name $APP_NAME
puts "=== App built ==="
puts "ELF: [file normalize $APP_NAME/build/$APP_NAME.elf]"
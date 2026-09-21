#!/bin/bash
# Manual BSP + app build for LED_AXI_GPIO_Zynq using HSI (bypasses Vitis repo).
set -e
export RDI_TOOL=/media/arsatyants/62ed41ca-3b8b-450e-8a0d-83de627e2f24/Vitis/2021.1/scripts/rtcl/../../bin/loader
source /media/arsatyants/62ed41ca-3b8b-450e-8a0d-83de627e2f24/Vitis/2021.1/settings64.sh

cd /home/arsatyants/code/lesson10-zynq/vitis/LED_AXI_GPIO_Zynq
mkdir -p manual/standalone_domain manual/app/src
cp main.c manual/app/src/main.c

cat > manual/hsi_build.tcl <<'TCLEOF'
set XSA /home/arsatyants/code/lesson10-zynq/vivado/LED_AXI_GPIO_Zynq/design_1_wrapper.xsa
set BUILDDIR /home/arsatyants/code/lesson10-zynq/vitis/LED_AXI_GPIO_Zynq/manual/standalone_domain
file mkdir $BUILDDIR

hsi::open_hw_design $XSA
hsi::set_repo_path /media/arsatyants/62ed41ca-3b8b-450e-8a0d-83de627e2f24/Vitis/2021.1/data/embeddedsw
hsi::generate_app -os standalone -proc ps7_cortexa9_0 -app empty_application -dir $BUILDDIR -compile
puts "HSI generate_app done"
exit
TCLEOF

xsct manual/hsi_build.tcl 2>&1 | tail -8

# Build with make
cd manual/standalone_domain
make -j4 2>&1 | tail -10
echo "=== ELF ==="
ls -la *.elf 2>/dev/null || find . -name "*.elf" | head
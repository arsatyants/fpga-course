#!/bin/bash
# Manual BSP + app build for LED_AXI_GPIO_MB (MicroBlaze) using xsdb HSI (Vitis 2026.1).
# XSCT is disabled in 2026.1; xsdb exposes hsi:: commands.
set -e
source /media/arsatyants/62ed41ca-3b8b-450e-8a0d-83de627e2f24/2026.1/Vivado/settings64.sh

BASE=/home/arsatyants/code/lesson10-microblaze/vitis/LED_AXI_GPIO_MB
cd $BASE
rm -rf manual
mkdir -p manual/mb_domain
cp main.c manual/mb_domain/main.c

cat > manual/hsi_build.tcl <<'TCLEOF'
set XSA /home/arsatyants/code/lesson10-microblaze/vivado/LED_AXI_GPIO_MB/design_1_wrapper.xsa
set BUILDDIR /home/arsatyants/code/lesson10-microblaze/vitis/LED_AXI_GPIO_MB/manual/mb_domain

hsi::set_repo_path /media/arsatyants/62ed41ca-3b8b-450e-8a0d-83de627e2f24/2026.1/data/embeddedsw
hsi::open_hw_design $XSA
puts "PROC: [hsi::get_processors]"
catch {hsi::generate_app -os standalone -proc microblaze_0 -app "Empty Application" -dir $BUILDDIR} e1
if {$e1 ne ""} {
    puts "Empty Application failed: $e1; trying empty_application"
    hsi::generate_app -os standalone -proc microblaze_0 -app empty_application -dir $BUILDDIR
}
puts "HSI generate_app done"
exit
TCLEOF

xsdb manual/hsi_build.tcl 2>&1 | tail -12

# Compile the app with our main.c
cd manual/mb_domain
ls -la
make 2>&1 | tail -8
if [ -f executable.elf ]; then
  cp executable.elf $BASE/LED_AXI_GPIO_MB_app.elf
  echo "ELF ready: $BASE/LED_AXI_GPIO_MB_app.elf"
fi
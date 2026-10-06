#!/bin/bash
# BSP + app build for lesson12 FRAME_DMA_MB (MicroBlaze) via xsdb HSI (Vitis 2026.1,
# XSCT is disabled there; xsdb exposes hsi:: commands). Same flow as lesson10.
# Result: vitis/frame_dma_mb.elf (used by vivado/sim.tcl and vivado/impl.tcl).
set -e
source /media/arsatyants/62ed41ca-3b8b-450e-8a0d-83de627e2f24/2026.1/Vivado/settings64.sh

BASE=$(cd "$(dirname "$0")" && pwd)
XSA=$BASE/../vivado/design_1_wrapper.xsa
BUILD=$BASE/build/mb_domain

rm -rf "$BASE/build"
mkdir -p "$BUILD"

cat > "$BASE/build/hsi_build.tcl" <<TCLEOF
hsi::set_repo_path /media/arsatyants/62ed41ca-3b8b-450e-8a0d-83de627e2f24/2026.1/data/embeddedsw
hsi::open_hw_design $XSA
catch {hsi::generate_app -os standalone -proc microblaze_0 -app "Empty Application" -dir $BUILD} e1
if {\$e1 ne ""} {
    puts "Empty Application failed: \$e1; trying empty_application"
    hsi::generate_app -os standalone -proc microblaze_0 -app empty_application -dir $BUILD
}
puts "HSI generate_app done"
exit
TCLEOF

xsdb "$BASE/build/hsi_build.tcl" 2>&1 | tail -12

cp "$BASE/main.c" "$BUILD/main.c"
cd "$BUILD"
make 2>&1 | grep -E "warning|error|mb-gcc -o" || true
cp executable.elf "$BASE/frame_dma_mb.elf"
mb-size "$BASE/frame_dma_mb.elf" 2>/dev/null || true
echo "ELF ready: $BASE/frame_dma_mb.elf"

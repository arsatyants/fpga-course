#!/bin/bash
# Модульна симуляція frame_rx_axis у XSim (без Vivado-проєкту).
set -e
source /media/arsatyants/62ed41ca-3b8b-450e-8a0d-83de627e2f24/2026.1/Vivado/settings64.sh
cd "$(dirname "$0")"
mkdir -p unit_sim && cd unit_sim
xvlog -i .. ../../rtl/async_fifo.v ../../rtl/frame_rx_axis.v ../tb_frame_rx_axis.v
xelab -debug typical tb_frame_rx_axis -s tb_unit
xsim tb_unit -R

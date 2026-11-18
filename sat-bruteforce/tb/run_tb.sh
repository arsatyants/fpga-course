#!/usr/bin/env bash
# Icarus Verilog: юнит-тесты sat_bruteforce (SAT при LOGP=0/2/4, UNSAT) и тест top с UART.
#   ./run_tb.sh
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
rtl=$here/../rtl
gen=$here/../tools/gen_cnf.py
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cd "$work"

unit() {   # $1 = LOGP
    iverilog -g2005 -DLOGP_TB="$1" -I. -o unit.vvp "$here/tb_sat_bruteforce.v" "$rtl/sat_bruteforce.v"
    vvp -n unit.vvp | tee unit.log
    grep -q '^PASS' unit.log
}

echo "== SAT, n=14 =="
python3 "$gen" --n 14 --seed 7 --ref --out .
for p in 0 2 4; do unit "$p"; done

echo "== UNSAT, n=12 =="
python3 "$gen" --n 12 --seed 3 --unsat --ref --out .
unit 3

echo "== top + UART, n=14 =="
python3 "$gen" --n 14 --seed 7 --out .
iverilog -g2005 -I. -o top.vvp "$here/tb_top.v" "$rtl/top.v" "$rtl/sat_bruteforce.v" "$rtl/uart_tx.v"
vvp -n top.vvp | tee top.log
grep -q '^PASS' top.log

echo "ALL PASS"

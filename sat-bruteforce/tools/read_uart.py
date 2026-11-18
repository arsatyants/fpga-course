#!/usr/bin/env python3
"""Читает отчёт sat-bruteforce из UART, проверяет решение по formula.cnf, считает время.

  pip install pyserial
  python3 read_uart.py /dev/ttyUSB0 ../vivado/formula.cnf --logp 6
"""
import argparse
import re

import serial


def load_cnf(path):
    n, clauses = 0, []
    for line in open(path):
        t = line.split()
        if not t or t[0] == "c":
            continue
        if t[0] == "p":
            n = int(t[2])
            continue
        clauses.append([int(x) for x in t[:-1]])
    return n, clauses


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("port")
    ap.add_argument("cnf")
    ap.add_argument("--logp", type=int, default=6)
    ap.add_argument("--baud", type=int, default=115200)
    ap.add_argument("--fclk", type=float, default=50e6)
    a = ap.parse_args()

    n, clauses = load_cnf(a.cnf)
    p = 1 << a.logp
    print(f"n={n} m={len(clauses)} P={p}, жду строку (нажми btn[0] или reset)...")
    with serial.Serial(a.port, a.baud, timeout=None) as s:
        while True:
            line = s.readline().decode(errors="replace").strip()
            m = re.match(r"(SAT|UNSAT)\s+x=([0-9A-F]+)\s+cyc=([0-9A-F]+)", line)
            if not m:
                continue
            print(line)
            status, x, cyc = m.group(1), int(m.group(2), 16), int(m.group(3), 16)
            t = cyc / a.fclk
            checked = cyc * p
            print(f"  FPGA: {t * 1e3:.3f} мс, проверено ~{checked:,} назначений "
                  f"({checked / t / 1e9:.2f} млрд/с)")
            print(f"  CPU-перебор при 1e8 назначений/с: ~{checked / 1e8:.3f} с")
            if status == "SAT":
                ok = all(any(((x >> (abs(l) - 1)) & 1) == (l > 0) for l in cl) for cl in clauses)
                print(f"  решение {'выполняет' if ok else 'НЕ выполняет'} все {len(clauses)} клауз")
            else:
                print(f"  пространство 2^{n} исчерпано: {2 ** n:,} назначений")


if __name__ == "__main__":
    main()

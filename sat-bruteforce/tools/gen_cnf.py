#!/usr/bin/env python3
"""Генератор случайной 3-SAT для sat_bruteforce.

Пишет в --out:
  formula.cnf          DIMACS (для проверки решения и для обычных SAT-солверов)
  formula.mem          M строк hex {neg[N-1:0], pos[N-1:0]} для $readmemh
  formula_params.vh    localparam N, M (+ эталон для тестбенча при --ref)

По умолчанию формула с «посаженным» решением (гарантированно выполнима),
m = round(4.27 * n) — порог фазового перехода, где случайные формулы труднее всего.
--unsat добавляет 8 клауз на x1..x3 со всеми знаками -> формула невыполнима.
--ref считает эталон перебором (только для малых n): минимальное выполняющее
назначение — именно его находит железо, т.к. обходит назначения по возрастанию.

  python3 gen_cnf.py --n 32 --seed 1 --out ../vivado
  python3 gen_cnf.py --n 14 --seed 7 --ref --out /tmp/t
"""
import argparse
import os
import random


def gen(n, m, seed, unsat):
    rnd = random.Random(seed)
    planted = rnd.getrandbits(n)
    clauses = []
    while len(clauses) < m:
        vs = rnd.sample(range(n), 3)
        cl = [v + 1 if rnd.random() < 0.5 else -(v + 1) for v in vs]
        if unsat or satisfies(cl, planted):
            clauses.append(cl)
    if unsat:
        for s in range(8):
            clauses.append([(i + 1) * (1 if (s >> i) & 1 else -1) for i in range(3)])
    return clauses, planted


def satisfies(cl, a):
    return any(((a >> (abs(l) - 1)) & 1) == (l > 0) for l in cl)


def masks(cl):
    pos = neg = 0
    for l in cl:
        if l > 0:
            pos |= 1 << (l - 1)
        else:
            neg |= 1 << (-l - 1)
    return pos, neg


def min_solution(n, clauses):
    """Минимальное выполняющее назначение перебором (numpy, n <= ~26)."""
    import numpy as np
    chunk = 1 << min(n, 22)
    for base in range(0, 1 << n, chunk):
        a = np.arange(base, base + chunk, dtype=np.uint64)
        ok = np.ones(chunk, dtype=bool)
        for cl in clauses:
            c = np.zeros(chunk, dtype=bool)
            for l in cl:
                bit = ((a >> np.uint64(abs(l) - 1)) & np.uint64(1)).astype(bool)
                c |= bit if l > 0 else ~bit
            ok &= c
            if not ok.any():
                break
        idx = np.flatnonzero(ok)
        if idx.size:
            return base + int(idx[0])
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--n", type=int, default=32)
    ap.add_argument("--m", type=int, default=None)
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--unsat", action="store_true")
    ap.add_argument("--ref", action="store_true")
    ap.add_argument("--out", default=".")
    a = ap.parse_args()

    n = a.n
    m = a.m if a.m is not None else round(4.27 * n)
    clauses, planted = gen(n, m, a.seed, a.unsat)
    M = len(clauses)
    os.makedirs(a.out, exist_ok=True)

    with open(os.path.join(a.out, "formula.cnf"), "w") as f:
        f.write(f"c random 3-SAT n={n} seed={a.seed} unsat={a.unsat}\n")
        if not a.unsat:
            f.write(f"c planted 0x{planted:x}\n")
        f.write(f"p cnf {n} {M}\n")
        for cl in clauses:
            f.write(" ".join(map(str, cl)) + " 0\n")

    hexw = (2 * n + 3) // 4
    with open(os.path.join(a.out, "formula.mem"), "w") as f:
        for cl in clauses:
            pos, neg = masks(cl)
            f.write(f"{(neg << n) | pos:0{hexw}x}\n")

    with open(os.path.join(a.out, "formula_params.vh"), "w") as f:
        f.write(f"// gen_cnf.py --n {n} --m {m} --seed {a.seed}{' --unsat' if a.unsat else ''}\n")
        f.write(f"localparam N = {n};\nlocalparam M = {M};\n")
        if a.ref:
            sol = min_solution(n, clauses)
            f.write(f"localparam REF_FOUND = {0 if sol is None else 1};\n")
            f.write(f"localparam [N-1:0] REF_SOL = {n}'h{(sol or 0):x};\n")
            print(f"ref: {'UNSAT' if sol is None else f'min solution 0x{sol:x}'}")

    print(f"n={n} m={M} -> {a.out}/formula.{{cnf,mem}}, formula_params.vh"
          + ("" if a.unsat else f", planted 0x{planted:x}"))


if __name__ == "__main__":
    main()

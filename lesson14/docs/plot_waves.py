#!/usr/bin/env python3
"""Lesson 14: однакові waveform-картинки з симуляції (VCD з tb_top) і з ILA (CSV з плати).

    plot_waves.py <sim_probes.vcd> <ila.csv> <start|end> <out.png>

Час -- мкс відносно точки тригера. Для симуляції "тригер" шукається за тією ж умовою,
що й в ILA:  start -- перший pix_fsync&pix_valid після фронту start;
             end   -- перший спад busy.
Вікно = вікно ILA (32768 семплів по 10 нс, позиція тригера з CSV)."""
import csv, sys
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

LANES = ["pix_data", "pix_valid", "pix_fsync", "start", "busy", "overflow", "led_ok (led[0])", "btn"]

def flags(v):  # probe4 = {led_ok, overflow, busy, btn}
    return {"led_ok (led[0])": (v >> 3) & 1, "overflow": (v >> 2) & 1, "busy": (v >> 1) & 1, "btn": v & 1}

def read_vcd(path):
    """-> (times_ns, dict lane -> values), семпли по фронту aclk, як в ILA."""
    ids, cur = {}, {}
    t, out_t, out = 0, [], {k: [] for k in LANES}
    with open(path) as f:
        for line in f:
            if line.startswith("$var"):
                p = line.split(); ids[p[3]] = p[4]
            elif line.startswith("$enddefinitions"):
                break
        prev_clk = 0
        for line in f:
            line = line.strip()
            if not line: continue
            if line[0] == "#":
                t = int(line[1:]); continue
            if line[0] in "b":
                val, ident = line[1:].split()
            elif line[0] in "01xz":
                val, ident = line[0], line[1:]
            else:
                continue
            name = ids.get(ident)
            if name is None: continue
            try: iv = int(val.replace("x", "0").replace("z", "0"), 2)
            except ValueError: iv = 0
            if name == "aclk":
                if iv == 1 and prev_clk == 0:
                    out_t.append(t / 1000.0)
                    out["pix_data"].append(cur.get("probe0", 0))
                    out["pix_valid"].append(cur.get("probe1", 0))
                    out["pix_fsync"].append(cur.get("probe2", 0))
                    out["start"].append(cur.get("probe3", 0))
                    for k, v in flags(cur.get("probe4", 0)).items(): out[k].append(v)
                prev_clk = iv
            else:
                cur[name] = iv
    return out_t, out

def read_ila(path):
    with open(path) as f:
        rows = list(csv.reader(f))
    hdr, radix, data = rows[0], rows[1], rows[2:]
    def col(pat):
        for i, h in enumerate(hdr):
            if pat in h: return i
        raise KeyError(pat)
    def num(s, i):
        return int(s, 16) if "HEX" in radix[i].upper() else int(s, 2) if "BIN" in radix[i].upper() else int(s)
    iw, itr = col("Sample in Window"), col("TRIGGER")
    ip = {"pix_data": col("pix_data"), "pix_valid": col("pix_valid"), "pix_fsync": col("pix_fsync"), "start": col("dbg_start")}
    trig = next(int(r[iw]) for r in data if r[itr].strip() == "1")
    t = [(int(r[iw]) - trig) * 10.0 for r in data]
    out = {k: [num(r[i], i) for r in data] for k, i in ip.items()}
    if any("dbg_status" in h for h in hdr):
        ifl = None   # .ltx розбив probe4 на нети
    else:        # probe4 одним стовпцем {led_ok, overflow, busy, btn}
        ifl = [i for i, h in enumerate(hdr) if i not in (0, 1, itr) and i not in ip.values()][0]
    if ifl is not None:
        fl = [flags(num(r[ifl], ifl)) for r in data]
        for k in ("busy", "overflow", "led_ok (led[0])", "btn"): out[k] = [x[k] for x in fl]
    else:  # .ltx розбив probe4 на нети: dbg_status[1:0], led_OBUF, btn_IBUF
        ist, iled, ibtn = col("dbg_status"), col("led"), col("btn")
        st = [num(r[ist], ist) for r in data]
        out["busy"] = [v & 1 for v in st]
        out["overflow"] = [(v >> 1) & 1 for v in st]
        out["led_ok (led[0])"] = [num(r[iled], iled) & 1 for r in data]
        out["btn"] = [num(r[ibtn], ibtn) & 1 for r in data]
    return t, out, trig, hdr

def sim_trigger(t, s, mode):
    armed = False
    for i in range(1, len(t)):
        if mode == "start":
            if s["start"][i] and not s["start"][i-1]: armed = True
            if armed and s["pix_fsync"][i] and s["pix_valid"][i]: return t[i]
        else:
            if s["busy"][i-1] and not s["busy"][i]: return t[i]
    raise SystemExit("sim trigger not found")

def draw(ax_list, t_us, s, title, color):
    for ax, k in zip(ax_list, LANES):
        if k == "pix_data":
            ax.step(t_us, s[k], where="post", lw=0.6, color=color); ax.set_ylim(-10, 265)
        else:
            ax.fill_between(t_us, 0, s[k], step="post", color=color, alpha=0.35, lw=0)
            ax.step(t_us, s[k], where="post", lw=0.9, color=color); ax.set_ylim(-0.2, 1.3); ax.set_yticks([])
        ax.set_ylabel(k, rotation=0, ha="right", va="center", fontsize=8)
        ax.axvline(0, color="red", lw=0.8, ls="--")
        ax.grid(axis="x", alpha=0.3)
    ax_list[0].set_title(title, fontsize=9)

def window(t, s, lo, hi):
    idx = [i for i, x in enumerate(t) if lo <= x <= hi]
    return [t[i] for i in idx], {k: [v[i] for i in idx] for k, v in s.items()}

def main():
    vcd, ila_csv, mode, png = sys.argv[1:5]
    zoom = (-3.0, 12.0) if mode == "start" else (-12.0, 8.0)
    ti, si, trig, _ = read_ila(ila_csv)
    lo, hi = ti[0], ti[-1]
    ts, ss = read_vcd(vcd)
    t0 = sim_trigger(ts, ss, mode)
    ts = [x - t0 for x in ts]
    sims = window(ts, ss, lo, hi)
    fig, axes = plt.subplots(len(LANES), 4, figsize=(22, 9), sharex="col",
                             gridspec_kw={"width_ratios": [3, 1.3, 3, 1.3], "hspace": 0.08, "wspace": 0.25})
    us = lambda tt: [x / 1000.0 for x in tt]
    names = {"start": "Advanced Trigger: фронт start, потім pix_fsync & pix_valid (перший піксель захопленого кадру)",
             "end": "Basic trigger: спад busy (frame_rx_axis віддав останнє слово кадру)"}
    draw(axes[:, 0], us(sims[0]), sims[1], f"СИМУЛЯЦІЯ (XSim, тригер на {t0/1000:.3f} мкс від старту)", "tab:blue")
    z = window(*sims, zoom[0]*1000, zoom[1]*1000)
    draw(axes[:, 1], us(z[0]), z[1], "симуляція, zoom", "tab:blue")
    draw(axes[:, 2], us(ti), si, "ILA НА ПЛАТІ (32768 семплів @ 100 МГц)", "tab:green")
    z = window(ti, si, zoom[0]*1000, zoom[1]*1000)
    draw(axes[:, 3], us(z[0]), z[1], "ILA, zoom", "tab:green")
    for c in range(4): axes[-1, c].set_xlabel("мкс відносно тригера")
    fig.suptitle(f"Lesson 14 -- {names[mode]}", fontsize=11)
    fig.savefig(png, dpi=110, bbox_inches="tight")
    print("saved", png)

if __name__ == "__main__":
    main()

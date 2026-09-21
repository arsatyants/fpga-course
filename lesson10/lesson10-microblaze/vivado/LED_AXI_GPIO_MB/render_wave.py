#!/usr/bin/env python3
"""Render simulation log into waveform PNG (screenshot substitute for homework)."""
import re
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches

LOG = '/home/arsatyants/code/lesson10-microblaze/vivado/LED_AXI_GPIO_MB/LED_AXI_GPIO_MB.sim/sim_1/behav/xsim/simulate.log'
OUT = '/home/arsatyants/code/lesson10-microblaze/vivado/LED_AXI_GPIO_MB/waveform_sim.png'

events = []  # (time_ns, kind, data)
for line in open(LOG):
    m = re.match(r'\[(\d+)\] (LED change #\d+): (\S+) -> (\S+)', line.strip())
    if m:
        t = int(m.group(1)) / 1e6  # ps->ns... timescale 1ns, so t is ns
        events.append((t, 'led', m.group(4)))
        continue
    m = re.match(r'\[(\d+)\] (TEST\d+.*)', line.strip())
    if m:
        t = int(m.group(1)) / 1e6
        events.append((t, 'test', m.group(2)))
        continue
    m = re.match(r'\[(\d+)\] (Reset released)', line.strip())
    if m:
        events.append((int(m.group(1)) / 1e6, 'rst', m.group(2)))

if not events:
    raise SystemExit("no events parsed")

T_END = max(e[0] for e in events) * 1.05 + 10

fig, ax = plt.subplots(figsize=(16, 6))
ax.set_title('LED_AXI_GPIO_MB — MicroBlaze LED running light: simulation waveform (real ELF, XSim 2026.1)\n'
             'btn: 1111=idle, low=pressed; led active-low (0001=LED0 lit... 1000=LED3 lit)', fontsize=10)

# LED waveform: draw as digital bus value
led_events = [(t, v) for (t, k, v) in [(e[0], e[1], e[2]) for e in events if e[1] == 'led']]
led_events.sort()
# build step waveform of the 4-bit LED value
times = [0] + [t for t, v in led_events]
vals = [0b1111] + [int(v.replace('_', ''), 2) for t, v in led_events]
if times[-1] < T_END:
    times.append(T_END); vals.append(vals[-1])
ax.step(times, vals, where='post', linewidth=2, color='tab:blue', label='led[3:0] (hex)')

# annotate each led value
for t, v in led_events:
    iv = int(v.replace('_', ''), 2)
    ax.annotate(f'{iv:04b}', (t, iv), textcoords='offset points', xytext=(0, 8), fontsize=7, rotation=45, color='tab:blue')

# test markers
colors = {'TEST1': 'green', 'TEST2': 'orange', 'TEST3': 'red', 'TEST4': 'purple', 'TEST5': 'brown'}
for (t, k, d) in events:
    if k == 'test':
        key = d.split(':')[0]
        c = colors.get(key, 'gray')
        ax.axvline(t, color=c, linestyle='--', alpha=0.7)
        ax.text(t, 15.5, d.split('->')[0].strip(), rotation=90, fontsize=7, color=c, va='top')
    if k == 'rst':
        ax.axvline(t, color='black', linestyle=':', alpha=0.5)
        ax.text(t, 15.8, 'rst released', fontsize=7, va='top')

ax.set_xlabel('time, ns')
ax.set_ylabel('led[3:0] (binary value)')
ax.set_ylim(-0.5, 17)
ax.set_yticks([0, 1, 2, 4, 8, 15])
ax.legend(loc='upper right')
ax.grid(alpha=0.3)
plt.tight_layout()
plt.savefig(OUT, dpi=130)
print('saved:', OUT)
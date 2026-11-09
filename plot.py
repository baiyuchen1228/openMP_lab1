#!/usr/bin/env python3
"""Draw experiment charts from results_20261021/summary.md into figures/.

Usage: python3 plot.py   (needs matplotlib: pip install matplotlib)
"""
import re
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

ROOT = Path(__file__).parent
OUT = ROOT / "figures"
PHYSICAL_CORES = 6  # i5-12400

# rows like: | 12 | 19.43 ± 0.21 | 5.77 ± 0.18 | 6.43 ± 0.18 |
rows = re.findall(r"^\|\s*(\d+)\s*\|(.+)\|\s*$", (ROOT / "results_20261021/summary.md").read_text(), re.M)
threads = [int(t) for t, _ in rows]
cells = [[tuple(map(float, c.split("±"))) for c in rest.split("|")] for _, rest in rows]
names = ["lab_v0 (sequential)", "lab_v1 (reduction)", "lab_v1_atomic (atomic)"]
colors = dict(zip(names, ["C0", "C1", "C2"]))  # same color per version in every chart
mean = {n: [r[i][0] for r in cells] for i, n in enumerate(names)}
std = {n: [r[i][1] for r in cells] for i, n in enumerate(names)}
assert threads and all(len(r) == 3 for r in cells), "summary.md table not parsed"

baseline = sum(mean[names[0]]) / len(threads)  # lab_v0 averaged over all runs
OUT.mkdir(exist_ok=True)

# 1. execution time
fig, ax = plt.subplots(figsize=(7, 4.5))
for n, m in zip(names, ["s", "o", "^"]):
    ax.errorbar(threads, mean[n], yerr=std[n], marker=m, capsize=3, label=n, color=colors[n])
ax.axvline(PHYSICAL_CORES, color="gray", ls=":", lw=1)
ax.text(PHYSICAL_CORES + 0.1, 1, "6 physical cores", color="gray")
ax.set(xlabel="OMP_NUM_THREADS", ylabel="real time (s)", xticks=threads, ylim=(0, None),
       title="Execution time (mean ± std of 5 runs)")
ax.grid(alpha=0.3)
ax.legend()
fig.tight_layout()
fig.savefig(OUT / "time.png", dpi=150)

# 2. speedup vs ideal
fig, ax = plt.subplots(figsize=(7, 4.5))
ax.plot(threads, threads, "k--", lw=1, label="ideal (linear)")
for n, m, dy in zip(names[1:], ["o", "^"], [8, -16]):
    sp = [baseline / t for t in mean[n]]
    ax.plot(threads, sp, marker=m, label=n, color=colors[n])
    ax.annotate(f"{sp[-1]:.2f}x", (threads[-1], sp[-1]), textcoords="offset points", xytext=(0, dy), ha="center", color=colors[n])
ax.axvline(PHYSICAL_CORES, color="gray", ls=":", lw=1)
ax.text(PHYSICAL_CORES + 0.1, 0.3, "6 physical cores", color="gray")
ax.set(xlabel="OMP_NUM_THREADS", ylabel=f"speedup (vs lab_v0 {baseline:.2f} s)", xticks=threads,
       ylim=(0, max(threads) + 0.5), title="Speedup")
ax.grid(alpha=0.3)
ax.legend()
fig.tight_layout()
fig.savefig(OUT / "speedup.png", dpi=150)

print("wrote", *sorted(p.name for p in OUT.glob("*.png")))

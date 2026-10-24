"""Draw the README charts and pipeline diagram from demo/*.txt and results/sweep.json.

    uv run --with matplotlib scripts/charts.py
"""
import json
import re
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyArrowPatch, FancyBboxPatch

ROOT = Path(__file__).resolve().parent.parent
BG, INK, MUTED, BORDER = "#09090B", "#F4F4F5", "#A1A1AA", "#27272A"
GREEN, RED, AMBER = "#00D46A", "#F87171", "#FCD34D"
LABELS = ["violation", "supported", "insufficient_information", "inconsistent_context"]
plt.rcParams.update({
    "figure.facecolor": BG, "axes.facecolor": BG, "savefig.facecolor": BG, "text.color": INK,
    "axes.labelcolor": MUTED, "xtick.color": MUTED, "ytick.color": INK, "axes.edgecolor": BORDER,
    "font.family": "DejaVu Sans", "font.size": 11,
})
OUT = ROOT / "docs"
OUT.mkdir(exist_ok=True)


def demo_probs(name: str) -> dict:
    line = next(l for l in (ROOT / "demo" / f"{name}.txt").read_text().splitlines() if l.startswith("SAPLING"))
    return {k: float(v) for k, v in re.findall(r"([a-z_]+) (\d\.\d\d)", line.split("|")[1])}


def style(ax):
    for s in ("top", "right"):
        ax.spines[s].set_visible(False)
    ax.grid(axis="x", color=BORDER, linewidth=0.8)
    ax.set_axisbelow(True)


def chart_demo():
    bug, ref = demo_probs("bug"), demo_probs("refactor")
    fig, ax = plt.subplots(figsize=(9, 4.2))
    y = range(len(LABELS))
    h = 0.36
    ax.barh([i - h / 2 for i in y], [bug[l] for l in LABELS], h, color=RED, label="Edit 1: hidden bug (Z3 counterexample)")
    ax.barh([i + h / 2 for i in y], [ref[l] for l in LABELS], h, color=GREEN, label="Edit 2: real refactor (Z3 proved equivalent)")
    for i, l in enumerate(LABELS):
        ax.text(bug[l] + 0.01, i - h / 2, f"{bug[l]:.2f}", va="center", color=INK, fontsize=10)
        ax.text(ref[l] + 0.01, i + h / 2, f"{ref[l]:.2f}", va="center", color=INK, fontsize=10)
    ax.axvline(0.90, color=AMBER, linestyle="--", linewidth=1.2)
    ax.text(0.895, -0.6, "BLOCK at 0.90", color=AMBER, ha="right", fontsize=10)
    ax.set_yticks(list(y), LABELS)
    ax.invert_yaxis()
    ax.set_xlim(0, 1.05)
    ax.set_xlabel("Sapling probability")
    ax.set_title("Same claimed refactor, two edits: Sapling's four labels", loc="left", color=INK, pad=12)
    ax.legend(frameon=True, facecolor=BG, edgecolor=BORDER, framealpha=1, loc="lower right", labelcolor=INK, fontsize=10)
    style(ax)
    fig.tight_layout()
    fig.savefig(OUT / "demo_probabilities.png", dpi=160)


def chart_sweep():
    rows = json.loads((ROOT / "results" / "sweep.json").read_text())
    cases = list(dict.fromkeys(r["case"] for r in rows))
    fig, axes = plt.subplots(1, 2, figsize=(11, 4.6), sharey=True)
    for ax, ev, title in zip(axes, ("bug", "refactor"), ("Bug edit (Z3 counterexample)", "Refactor edit (Z3 proved equivalent)")):
        sub = {r["case"]: r for r in rows if r["evidence"] == ev}
        for i, c in enumerate(cases):
            p = sub[c]["probabilities"]
            ax.plot([p["violation"], p["supported"]], [i, i], color=BORDER, linewidth=2, zorder=1)
            ax.scatter(p["violation"], i, color=RED, s=60, zorder=2, label="violation" if i == 0 else None)
            ax.scatter(p["supported"], i, color=GREEN, s=60, zorder=2, label="supported" if i == 0 else None)
            g = sub[c]["gate"]
            ax.text(1.04, i, g, va="center", fontsize=10, fontweight="bold",
                    color={"BLOCK": RED, "PASS": GREEN, "HOLD": AMBER}[g])
        ax.axvline(0.90, color=AMBER, linestyle="--", linewidth=1)
        ax.set_xlim(0, 1.15)
        ax.set_xticks([0, 0.25, 0.5, 0.75, 1.0])
        ax.set_title(title, loc="left", color=INK, fontsize=11)
        ax.set_xlabel("Sapling probability")
        style(ax)
    axes[0].set_yticks(range(len(cases)), [f'"{c}"' for c in cases])
    axes[0].invert_yaxis()
    fig.legend(*axes[0].get_legend_handles_labels(), frameon=False, loc="upper right", ncol=2, labelcolor=INK, fontsize=10)
    fig.suptitle("Six AI change descriptions x two Refinery verdicts (gate decision at right)", x=0.01, ha="left", color=INK)
    fig.tight_layout()
    fig.savefig(OUT / "sweep.png", dpi=160)


def diagram():
    fig, ax = plt.subplots(figsize=(12, 4.4))
    ax.set_xlim(0, 12)
    ax.set_ylim(0, 4.4)
    ax.axis("off")

    def box(x, y, w, h, title, body, edge=BORDER, tcolor=INK):
        ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.02,rounding_size=0.12",
                                    facecolor="#18181B", edgecolor=edge, linewidth=1.4))
        ax.text(x + w / 2, y + h - 0.28, title, ha="center", va="top", fontsize=11.5, fontweight="bold", color=tcolor)
        ax.text(x + w / 2, y + h - 0.68, body, ha="center", va="top", fontsize=9, color=MUTED, linespacing=1.5)

    def arrow(x1, y1, x2, y2, color=MUTED):
        ax.add_patch(FancyArrowPatch((x1, y1), (x2, y2), arrowstyle="-|>", mutation_scale=14, color=color, linewidth=1.3))

    mid = 2.2
    box(0.1, 1.2, 1.9, 2.0, "AI tool edit", "COBOL change +\nits own description\n\"just a refactor\"")
    box(2.5, 1.2, 2.3, 2.0, "Refinery", "diff\n11 deterministic checks\nZ3 proof or\ncounterexample", edge=GREEN)
    box(5.3, 1.2, 2.3, 2.0, "Banyan Sapling", "policy\n+ evidence\n+ claim\n-> 4 label probabilities")
    arrow(2.0, mid, 2.5, mid)
    arrow(4.8, mid, 5.3, mid)
    gates = [(3.35, "BLOCK", "violation >= 0.90", RED), (2.0, "PASS", "calibrated supported", GREEN), (0.65, "HOLD", "anything else", AMBER)]
    for y, name, rule, c in gates:
        box(8.2, y - 0.5, 1.6, 1.0, name, rule, edge=c, tcolor=c)
        arrow(7.6, mid, 8.2, y)
    box(10.3, 1.2, 1.6, 2.0, "Named human", "sign-off\n(PASS forwards,\nHOLD routes\nwith the lean)")
    arrow(9.8, 2.0, 10.3, 2.0)
    arrow(9.8, 0.65, 10.3, 1.5)
    ax.text(9.0, 4.1, "merge refused", ha="center", fontsize=8.5, color=RED)
    fig.savefig(OUT / "pipeline.png", dpi=160, bbox_inches="tight")


if __name__ == "__main__":
    assert demo_probs("bug")["violation"] == 0.92  # parser self-check against the committed transcript
    chart_demo()
    chart_sweep()
    diagram()

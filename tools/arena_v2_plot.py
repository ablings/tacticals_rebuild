"""Draw the Arena v2 plan (top-down) from notes/maps/arena_v2_layout.json + arena_v2_checks.json.
    python -I tools/arena_v2_plot.py   -> notes/maps/arena_v2_plan.png, notes/maps/arena_v2_exposure.png
"""
import json, os, math
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle, Polygon, FancyArrowPatch
from matplotlib.lines import Line2D

HERE = os.path.dirname(os.path.abspath(__file__))
MAPS = os.path.join(os.path.dirname(HERE), "notes", "maps")
D = json.load(open(os.path.join(MAPS, "arena_v2_layout.json")))
C = json.load(open(os.path.join(MAPS, "arena_v2_checks.json")))
B = D["box"]

COL = {  # by height (darker = taller), windows in slate, decks in olive (Tacticals' accent) for the plan only
    "low": "#c9c6bb", "sill": "#c9c6bb", "wall": "#8f8c84", "pillar": "#55534e", "post": "#3d4a5c",
    "lintel": "#3d4a5c", "deck": "#a9b77a", "parapet": "#c9c6bb", "ramp": "#d6dfb4",
}
TEAM = {"A": "#3a78c2", "B": "#c2463a"}


def draw_plan(ax, pieces, labels=True):
    ax.add_patch(Rectangle((B["x0"] - 2, B["y0"] - 2), B["x1"] - B["x0"] + 4, B["y1"] - B["y0"] + 4, fc="#6b6b6b", ec="none"))
    ax.add_patch(Rectangle((B["x0"], B["y0"]), B["x1"] - B["x0"], B["y1"] - B["y0"], fc="#f2f1ec", ec="none"))
    for x in range(B["x0"], B["x1"] + 1, 5):
        ax.plot([x, x], [B["y0"], B["y1"]], color="#e2e0d8", lw=0.4 if x % 25 else 0.9, zorder=0.5)
    for y in range(B["y0"], B["y1"] + 1, 5):
        ax.plot([B["x0"], B["x1"]], [y, y], color="#e2e0d8", lw=0.4 if y % 25 else 0.9, zorder=0.5)
    for p in pieces:
        if p["kind"] == "deck":
            rp = p["ramp"]; (fx, fy), (tx, ty), w = rp["foot"], rp["top"], rp["width"]
            if fy == ty:
                ax.add_patch(Rectangle((min(fx, tx), fy - w / 2), abs(tx - fx), w, fc=COL["ramp"], ec="#6f7a45", lw=0.8, zorder=2))
            else:
                ax.add_patch(Rectangle((fx - w / 2, min(fy, ty)), w, abs(ty - fy), fc=COL["ramp"], ec="#6f7a45", lw=0.8, zorder=2))
            # rungs + arrow (up the slope)
            n = int(rp["run"] // 2)
            for k in range(1, n):
                t = k / n
                x, y = fx + (tx - fx) * t, fy + (ty - fy) * t
                if fy == ty: ax.plot([x, x], [fy - w / 2 + 0.4, fy + w / 2 - 0.4], color="#8c9763", lw=0.6, zorder=2.1)
                else: ax.plot([fx - w / 2 + 0.4, fx + w / 2 - 0.4], [y, y], color="#8c9763", lw=0.6, zorder=2.1)
            ax.add_patch(FancyArrowPatch((fx, fy), (tx, ty), arrowstyle="-|>", mutation_scale=16, lw=2, color="#4d5a22", zorder=6))
            if labels:
                ax.text((fx + tx) / 2, (fy + ty) / 2 + (w / 2 + 1.2 if fy == ty else 0), f"ramp {rp['slope_deg']}°",
                        ha="center", va="bottom", fontsize=6.5, color="#4d5a22", zorder=7)
        for q in p["parts"]:
            r = q["role"]
            if r == "lintel": continue
            if p["kind"] == "window":
                c = COL["post"] if r == "solid" else COL["sill"]
            elif p["kind"] == "deck":
                if r == "curb":
                    ax.add_patch(Rectangle((q["x0"], q["y0"]), q["x1"] - q["x0"], q["y1"] - q["y0"], fc="#2b2b2b", ec="none", zorder=3.5))
                    continue
                c = {"deck": COL["deck"], "parapet": COL["parapet"]}.get(r) or (COL["pillar"] if q["z1"] - q["z0"] >= 10 else COL["wall"])
            else:
                c = COL[p["kind"]]
            ax.add_patch(Rectangle((q["x0"], q["y0"]), q["x1"] - q["x0"], q["y1"] - q["y0"], fc=c, ec="#2b2b2b", lw=0.6,
                                   zorder=3 if r != "deck" else 2.5))
            if p["kind"] == "window" and r == "sill":   # the opening: hatched sill + lintel outline
                ax.add_patch(Rectangle((q["x0"], q["y0"]), q["x1"] - q["x0"], q["y1"] - q["y0"], fc="none", ec="#3d4a5c",
                                       lw=1.2, ls=(0, (2, 1.2)), hatch="////", zorder=3.2))
        if p["kind"] == "deck" and labels:
            d = p["parts"][0]
            ax.text((d["x0"] + d["x1"]) / 2, (d["y0"] + d["y1"]) / 2, f"{p['id'].replace('_', ' ')}\n+{d['z1']:g}",
                    ha="center", va="center", fontsize=7, weight="bold", color="#33401a", zorder=8)


fig, ax = plt.subplots(figsize=(17, 13), dpi=110)
draw_plan(ax, D["pieces"])
# spawns
for t, s in D["spawns"].items():
    x0, x1, y0, y1 = s["pocket"]
    ax.add_patch(Rectangle((x0, y0), x1 - x0, y1 - y0, fc=TEAM[t], alpha=0.18, ec=TEAM[t], lw=1.5, zorder=1))
    for k, (x, y) in enumerate(s["spots"]):
        ax.plot(x, y, marker="o", ms=9 if k == 0 else 6, color=TEAM[t], mec="white", mew=1.2, zorder=9)
    ax.text((x0 + x1) / 2, y1 + 1, f"SPAWN {t}", ha="center", va="bottom", fontsize=10, weight="bold", color=TEAM[t], zorder=9)
# sight lines
spots = D["spots"]
for sl in D["sightlines"]:
    a, b = spots[sl["a"]]["pos"], spots[sl["b"]]["pos"]
    col = TEAM.get(spots[sl["a"]]["side"], "#7a3ab0")
    ax.plot([a[0], b[0]], [a[1], b[1]], ls=(0, (5, 3)), lw=1.4, color=col, alpha=0.85, zorder=5)
# gaps
gmap = {g["id"]: g for g in C["info"]["gaps"]}
for g in D["gaps"]:
    (ax_, ay), (bx, by) = g["a"], g["b"]
    info = gmap[g["id"]]
    ax.add_patch(FancyArrowPatch((ax_, ay), (bx, by), arrowstyle="<|-|>", mutation_scale=10, lw=1.3, color="#d08a00", zorder=6))
    dash = f"dash {info['dash_s']}s" if info["dash_s"] else "NO dash"
    ax.text((ax_ + bx) / 2, (ay + by) / 2 - 1.6, f"{info['length']:g} st · {info['sprint_s']}s run · {dash}", ha="center",
            va="top", fontsize=6.2, color="#8a5a00", zorder=7,
            bbox=dict(boxstyle="round,pad=0.15", fc="#fff6dd", ec="none", alpha=0.85))
# advantage spots
KIND = {"height": "^", "window": "s", "middle": "D", "gap": "o"}
for name, s in spots.items():
    if s["kind"] == "ramp": continue
    x, y, _ = s["pos"]
    col = TEAM.get(s["side"], "#7a3ab0")
    ax.plot(x, y, marker=KIND.get(s["kind"], "o"), ms=8, color=col, mec="black", mew=0.8, zorder=10)
    if s["kind"] in ("height", "window"):
        ax.text(x, y - 2.2, name.replace("_", " "), ha="center", va="top", fontsize=7.5, weight="bold", color=col, zorder=10,
                bbox=dict(boxstyle="round,pad=0.15", fc="white", ec="none", alpha=0.8))
# lane labels
for txt, x, y in (("NORTH LANE", 0, 52.3), ("SOUTH LANE", 0, -53.6), ("CENTRE", -48, -1)):
    ax.text(x, y, txt, ha="center", va="center", fontsize=9, color="#9a978c", weight="bold", zorder=1.5)
for txt, x, y in (("CENTRE TWIN WINDOWS", 0, -19.5), ("B NORTH GATE\n(twin window)", 23, 18), ("A SOUTH GATE\n(twin window)", -23, -18),
                  ("N island", 0, 45), ("S island", 2, -44)):
    ax.text(x, y, txt, ha="center", va="top" if y < 0 else "bottom", fontsize=7, color="#3d4a5c", weight="bold", zorder=8,
            bbox=dict(boxstyle="round,pad=0.12", fc="white", ec="none", alpha=0.7))
ax.set_xlim(B["x0"] - 4, B["x1"] + 4); ax.set_ylim(B["y0"] - 9, B["y1"] + 4)
ax.set_aspect("equal"); ax.set_xticks(range(B["x0"], B["x1"] + 1, 25)); ax.set_yticks(range(B["y0"], B["y1"] + 1, 25))
ax.tick_params(labelsize=7)
I = C["info"]
ax.set_title(f"{D['name']} (Tacticals) - plan, studs. Box 150 x 110, open roof, walls 16. "
             f"Exposure mean {I['exposure']['mean']}% (max {I['exposure']['max']}), spawn-to-spawn LOS "
             f"{I['spawn_los']['eye_to_eye']}/{I['spawn_los']['pairs']}, footprint {I['footprint_pct']}%", fontsize=10)
legend = [
    Rectangle((0, 0), 1, 1, fc=COL["pillar"], ec="k", label="pillar 5x5, 10 high"),
    Rectangle((0, 0), 1, 1, fc=COL["wall"], ec="k", label="wall 10x3, 7 high"),
    Rectangle((0, 0), 1, 1, fc=COL["low"], ec="k", label="low wall 6x2, 3.4 (crouch, vault)"),
    Rectangle((0, 0), 1, 1, fc=COL["post"], ec="k", label="window post, 12 high"),
    Rectangle((0, 0), 1, 1, fc=COL["sill"], ec=COL["post"], hatch="////", label="window opening: sill 3.4, open to 10, lintel 10-12"),
    Rectangle((0, 0), 1, 1, fc=COL["deck"], ec="k", label=f"deck +{D['heights']['deck']:g} (pale edge = 3.4 parapet, black edge = 1-high kick-curb)"),
    Rectangle((0, 0), 1, 1, fc=COL["ramp"], ec="#6f7a45", label=f"ramp 0 -> {D['heights']['deck']:g} (arrow = up)"),
    Line2D([0], [0], color="#d08a00", lw=1.5, label="open gap: length, sprint time, cover dash (max 26)"),
    Line2D([0], [0], color="#555", ls=(0, (5, 3)), label="key sight line (eye height)"),
    Line2D([0], [0], marker="^", color="w", mfc="#888", mec="k", ms=8, label="high ground"),
    Line2D([0], [0], marker="s", color="w", mfc="#888", mec="k", ms=8, label="window position"),
    Line2D([0], [0], marker="D", color="w", mfc="#888", mec="k", ms=7, label="middle (twin-window sills)"),
]
ax.legend(handles=legend, loc="lower center", bbox_to_anchor=(0.5, -0.115), ncol=4, fontsize=7.5, frameon=False)
# scale bar + north
ax.plot([B["x1"] - 22, B["x1"] - 2], [B["y0"] - 5.5] * 2, color="k", lw=2)
ax.text(B["x1"] - 12, B["y0"] - 5, "20 studs = 1 s sprint", ha="center", va="bottom", fontsize=7)
ax.annotate("N", xy=(B["x0"] - 1, B["y1"] + 3), xytext=(B["x0"] - 1, B["y1"] - 3), ha="center",
            arrowprops=dict(arrowstyle="-|>", color="k"), fontsize=9, weight="bold", annotation_clip=False)
fig.tight_layout()
fig.savefig(os.path.join(MAPS, "arena_v2_plan.png"))
print("plan written")

# exposure map
cache = np.load(os.path.join(MAPS, "_arena_v2_cache.npy"))
fig, ax = plt.subplots(figsize=(13, 9.6), dpi=100)
draw_plan(ax, D["pieces"], labels=False)
sc = ax.scatter(cache[:, 0], cache[:, 1], c=cache[:, 3], cmap="magma_r", s=22, marker="s", vmin=0, vmax=60, zorder=4, alpha=0.75)
plt.colorbar(sc, ax=ax, shrink=0.7, label="% of the floor this spot sees at eye height")
for t, s in D["spawns"].items():
    for x, y in s["spots"]: ax.plot(x, y, "o", color=TEAM[t], mec="white", ms=7, zorder=9)
ax.set_xlim(B["x0"] - 3, B["x1"] + 3); ax.set_ylim(B["y0"] - 3, B["y1"] + 3); ax.set_aspect("equal")
ax.set_title(f"Exposure (eye 4.6 -> chest 4.0): min {I['exposure']['min']} / mean {I['exposure']['mean']} / max {I['exposure']['max']}%, "
             f"10-stud band spread {I['exposure']['band_spread']}", fontsize=10)
fig.tight_layout()
fig.savefig(os.path.join(MAPS, "arena_v2_exposure.png"))
print("exposure written")

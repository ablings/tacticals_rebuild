"""Plan images of the House layout: notes/maps/house_plan.png (ground + upper side by side, rooms, cover, doors, windows,
stairs, spawns) and house_exposure.png (exposure + who-gets-there-first per storey, from _house_cache.npz).
    python tools/house_plot.py [layout.json] [tag]"""
import json, math, os, sys
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle, Polygon, FancyArrowPatch

HERE = os.path.dirname(os.path.abspath(__file__))
MAPS = os.path.join(os.path.dirname(HERE), "notes", "maps")
LAYOUT_IN = sys.argv[1] if len(sys.argv) > 1 else os.path.join(MAPS, "house_layout.json")
TAG = ("_" + sys.argv[2]) if len(sys.argv) > 2 else ""
D = json.load(open(LAYOUT_IN))
ST = D["storeys"]
COL = dict(wall="#2b2b2b", sill="#8a8a8a", low="#c9b27c", tall="#7a5a3a", step="#e3dcc8", door="#3a6ea5", rail="#5a5a5a",
           barrier="#d04040", stair="#9fb3c8", floor="#f4f1ea")


def storey_of_z(z0, z1, s):
    f, c = ST[s]["floor"], ST[s]["ceiling"]
    return z0 < c - 0.01 and z1 > f + 0.01


def draw_storey(ax, s, title):
    f = ST[s]["floor"]
    sh = D["shell"]
    ax.add_patch(Rectangle((sh["x0"], sh["y0"]), sh["x1"] - sh["x0"], sh["y1"] - sh["y0"], fc=COL["floor"], ec="none", zorder=0))
    for v in D["voids"]:
        if s == "U":
            ax.add_patch(Rectangle((v["x0"], v["y0"]), v["x1"] - v["x0"], v["y1"] - v["y0"], fc="#dfe8f0", ec="#9fb3c8",
                                   hatch="//", lw=0.5, zorder=0.5))
    if s == "U":   # flat roof (outside)
        ax.add_patch(Rectangle((9.5, 4.5), 30.5, 25.5, fc="#d9d9d9", ec="none", zorder=0.4))
        ax.text(25, 17, "flat roof\n(kitchen below)", ha="center", va="center", fontsize=7, color="#777")
    for r in D["rooms"]:
        if r["storey"] != s: continue
        q = max(r["rects"], key=lambda q: (q["x1"] - q["x0"]) * (q["y1"] - q["y0"]))
        ax.text((q["x0"] + q["x1"]) / 2, (q["y0"] + q["y1"]) / 2 + (6 if r["id"] in ("LR", "KT", "MB") else 0), r["name"],
                ha="center", va="center", fontsize=7.5, color="#444", zorder=6, weight="bold",
                bbox=dict(fc="white", ec="none", alpha=0.6, pad=0.5))
    for p in D["parts"]:
        if p["shape"] == "box":
            if not storey_of_z(p["z0"], p["z1"], s): continue
            if p["role"] in ("floor", "ceiling"): continue
            if p["role"] == "wall" and p["z0"] >= f + 9.5 and p["z0"] > f: continue     # door heads
            if p["role"] == "wall" and p["z1"] <= f + 0.01: continue
            c = COL["wall"] if p["role"] == "wall" else COL.get(p["cover"], "#999") if p["role"] == "furniture" else \
                COL["sill"] if p["role"] == "sill" else COL.get(p["role"], "#999")
            if p["role"] == "wall" and p["z1"] - p["z0"] < 6 and "Sill" in p["id"]: c = COL["sill"]
            al = 0.35 if p["role"] == "barrier" else 1
            ax.add_patch(Rectangle((p["x0"], p["y0"]), p["x1"] - p["x0"], p["y1"] - p["y0"], fc=c, ec="none", alpha=al, zorder=2))
            if p["role"] == "furniture":
                ax.text((p["x0"] + p["x1"]) / 2, (p["y0"] + p["y1"]) / 2, p["model"], fontsize=4.2, ha="center", va="center",
                        color="white" if p["cover"] == "tall" else "#333", zorder=3, rotation=90 if (p["y1"] - p["y0"]) > 2.2 * (p["x1"] - p["x0"]) else 0)
        elif p["shape"] == "ramp":
            if s == "G" or True:
                ax.add_patch(Rectangle((p["x0"], p["y0"]), p["x1"] - p["x0"], p["y1"] - p["y0"], fc=COL["stair"], ec="#55708c",
                                       lw=0.6, zorder=1.5))
                n = 16
                for k in range(1, n):
                    yy = p["y0"] + (p["y1"] - p["y0"]) * k / n
                    ax.plot([p["x0"], p["x1"]], [yy, yy], color="#55708c", lw=0.3, zorder=1.6)
                ax.add_patch(FancyArrowPatch(((p["x0"] + p["x1"]) / 2, p["foot_y"]), ((p["x0"] + p["x1"]) / 2, p["top_y"]),
                                             arrowstyle="-|>", mutation_scale=8, color="#1d3557", zorder=4))
                ax.text(p["x1"] + 0.3, (p["foot_y"] + p["top_y"]) / 2, "UP" if s == "G" else "DOWN", fontsize=5, color="#1d3557", zorder=4,
                        rotation=90)
        elif p["shape"] == "obox":
            if not storey_of_z(p["z0"], p["z1"], s): continue
            c, sn = math.cos(math.radians(p["yaw"])), math.sin(math.radians(p["yaw"]))
            w, d = p["w"] / 2, max(p["d"], 0.35) / 2
            pts = [(p["cx"] + u * c - v * sn, p["cy"] + u * sn + v * c) for u, v in ((-w, -d), (w, -d), (w, d), (-w, d))]
            ax.add_patch(Polygon(pts, fc=COL["door"], ec="none", zorder=3))
    for d in D["doors"]:
        if not storey_of_z(d["z0"], d["z0"] + 1, s): continue
        hx, hy = d["hinge"]
        r = d["leaf"]["w"]
        ax.plot([hx], [hy], "o", ms=2, color=COL["door"], zorder=4)
        lab = {"Ajar": "ajar", "Closed": "CLOSED", "Locked": "LOCKED"}[d["state"]]
        ax.text(d["centre"][0], d["centre"][1], lab, fontsize=4.5, color=COL["door"], zorder=5, ha="center", va="bottom")
    for o in D["openings"]:
        if o["kind"] != "window": continue
        if not storey_of_z(o["z0"], o["z1"], s): continue
        if o["axis"] == "x":
            ax.add_patch(Rectangle((o["a"], o["t0"] - 0.2), o["b"] - o["a"], o["t1"] - o["t0"] + 0.4, fc="#8ecae6", ec="#219ebc", lw=0.4, zorder=2.5))
        else:
            ax.add_patch(Rectangle((o["t0"] - 0.2, o["a"]), o["t1"] - o["t0"] + 0.4, o["b"] - o["a"], fc="#8ecae6", ec="#219ebc", lw=0.4, zorder=2.5))
    for t, c in (("A", "#d62828"), ("B", "#1d4ed8")):
        sp = D["spawns"][t]
        if abs(sp["z"] - f) > 1: continue
        for k, (x, y) in enumerate(sp["slots"]):
            ax.add_patch(plt.Circle((x, y), 1.0, fc=c, ec="white", lw=0.6, zorder=7))
            ax.text(x, y, str(k + 1), fontsize=5, color="white", ha="center", va="center", zorder=8)
        lx, ly = sp["look"]
        ax.add_patch(FancyArrowPatch((sp["x"], sp["y"]), (sp["x"] + lx * 5, sp["y"] + ly * 5), arrowstyle="-|>", mutation_scale=8,
                                     color=c, zorder=7))
        ax.text(sp["x"], sp["y"] - 3.2, f"SPAWN {t}", fontsize=6, color=c, ha="center", zorder=8, weight="bold")
    ax.set_xlim(-46, 46); ax.set_ylim(-36, 36); ax.set_aspect("equal")
    ax.set_title(title, fontsize=10)
    ax.set_xticks(range(-40, 41, 10)); ax.set_yticks(range(-30, 31, 10)); ax.tick_params(labelsize=6)
    ax.grid(alpha=0.15)
    ax.text(0, -34.5, "STREET (front, south)", ha="center", fontsize=7, color="#666")
    ax.text(0, 33.5, "BACKYARD (north)", ha="center", fontsize=7, color="#666")


fig, axs = plt.subplots(1, 2, figsize=(17, 7.2))
draw_storey(axs[0], "G", "Ground floor (floor 0, ceiling 13)")
draw_storey(axs[1], "U", "Upper floor (floor 14, ceiling 26)")
from matplotlib.patches import Patch
hand = [Patch(fc=COL["wall"], label="wall"), Patch(fc=COL["low"], label="low cover 3.4"), Patch(fc=COL["tall"], label="tall cover 7-8"),
        Patch(fc=COL["step"], label="step (walk over)"), Patch(fc=COL["sill"], label="sill / pass-through"), Patch(fc=COL["door"], label="door leaf"),
        Patch(fc=COL["barrier"], alpha=0.35, label="player barrier (bullets pass)"), Patch(fc="#8ecae6", label="window (breakable glass)"),
        Patch(fc=COL["stair"], label="stairs")]
fig.legend(handles=hand, loc="lower center", ncol=9, fontsize=7, frameon=False)
fig.suptitle("House (Tacticals duel map): plan v" + str(D["version"]) + "  -  x east, y north, studs", fontsize=11)
plt.tight_layout(rect=(0, 0.04, 1, 0.97))
out = os.path.join(MAPS, f"house_plan{TAG}.png")
plt.savefig(out, dpi=130); plt.close()
print(out)

cache = os.path.join(MAPS, f"_house_cache{TAG}.npz")
if os.path.exists(cache):
    C = np.load(cache)
    fig, axs = plt.subplots(2, 2, figsize=(16, 12))
    for col, s in enumerate(("G", "U")):
        f = ST[s]["floor"]
        m = np.abs(C["sz"] - f) < 1.01
        for row, (vals, cmap, lab) in enumerate(((C["expo"], "magma", "exposure % (stand)"),
                                                  (np.clip(C["tA"] - C["tB"], -3, 3), "coolwarm", "tA - tB (s): red = A first, blue = B first"))):
            ax = axs[row, col]
            draw_storey(ax, s, f"{'Ground' if s == 'G' else 'Upper'}: {lab}")
            sc = ax.scatter(C["sx"][m], C["sy"][m], c=vals[m] if row == 0 else -vals[m], cmap=cmap, s=14, marker="s", alpha=0.75, zorder=1.8,
                            vmin=None if row == 0 else -3, vmax=None if row == 0 else 3)
            plt.colorbar(sc, ax=ax, fraction=0.03)
    plt.tight_layout()
    out = os.path.join(MAPS, f"house_exposure{TAG}.png")
    plt.savefig(out, dpi=110); plt.close()
    print(out)

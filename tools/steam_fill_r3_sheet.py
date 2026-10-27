"""Round-3 result sheet for the steam fill (notes/steam_fill_r3_sheet.jpg): footstep loudness on my client over the scripted
scenario, and the AI sight / hearing results. Data = the Play-test logs of 2026-10-27 (pasted below, from out/steam_fill/lua/*.lua runs)."""
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

STEPS = ("-7.7:0.500 -7.4:0.160 -6.9:0.500 -6.6:0.500 -6.1:0.500 -5.8:0.500 -5.5:0.500 -5.0:0.500 -4.6:0.500 -4.3:0.160 -3.9:0.500 "
         "-3.5:0.500 -3.1:0.500 -2.7:0.500 -2.4:0.500 -1.9:0.500 -1.6:0.500 -1.2:0.160 -0.8:0.500 -0.5:0.500 -0.0:0.500 0.3:0.500 "
         "0.6:0.500 1.1:0.500 1.5:0.500 2.0:0.500 2.3:0.500 2.6:0.500 3.1:0.500 3.5:0.500 3.8:0.160 4.3:0.500 4.6:0.030M 5.1:0.030M "
         "5.4:0.030M 5.7:0.030M 6.2:0.030M 6.5:0.030M 7.0:0.010M 7.3:0.030M 7.6:0.030M 8.1:0.030M 8.5:0.030M 8.8:0.030M 9.3:0.030M "
         "9.6:0.030M 10.0:0.010M 10.3:0.030M 10.7:0.030M 11.6:0.030M 11.9:0.030M 12.3:0.030M 12.6:0.030M 12.9:0.030M 13.3:0.030M "
         "13.6:0.030M 13.9:0.030M 14.1:0.500 14.5:0.500 15.1:0.500 15.4:0.500 15.7:0.160 16.0:0.500 16.4:0.500 16.7:0.500 17.0:0.500 "
         "17.3:0.160 17.6:0.500 18.0:0.500 18.5:0.500 18.8:0.500 19.1:0.160")
pts = []
for tok in STEPS.split():
    t, v = tok.split(":")
    pts.append((float(t), float(v.rstrip("M")), v.endswith("M")))

INK, INK2, BLUE, SURF, BAND = "#0b0b0b", "#52514e", "#2a78d6", "#fcfcfb", "#ecebe7"
fig = plt.figure(figsize=(13, 8.2), facecolor=SURF)
fig.suptitle("Steam fill, round 3: the AI is blind in the steam, and footsteps are muffled to very faint",
             x=0.04, ha="left", fontsize=15, color=INK, fontweight="bold")
ax = fig.add_axes([0.06, 0.47, 0.9, 0.42], facecolor=SURF)
if False:
    pass
ax.axvspan(4, 11, color=BAND, lw=0)
ax.axvspan(11, 14, color="#e2e1dc", lw=0)
ax.axvline(4, color=INK2, lw=1, ls=(0, (3, 3)))
ax.text(4.1, 0.56, "valve shot", color=INK2, fontsize=10, va="bottom")
ax.text(-7.6, 0.56, "no steam: AI walks, I listen 20+ studs away", color=INK2, fontsize=10)
ax.text(4.6, 0.23, "AI walks IN the steam,\nI stand outside", color=INK, fontsize=10)
ax.text(11.15, 0.23, "AI outside,\nI stand IN the steam\n(hiss over, fading)", color=INK, fontsize=10)
ax.text(14.3, 0.56, "steam gone", color=INK2, fontsize=10)
open_ = [(t, v) for t, v, m in pts if not m]
muff = [(t, v) for t, v, m in pts if m]
ax.vlines([p[0] for p in pts], 0, [v for _, v, _ in pts], color=BLUE, lw=2)
ax.scatter([t for t, _ in open_], [v for _, v in open_], s=36, color=BLUE, zorder=3)
ax.scatter([t for t, _ in muff], [v for _, v in muff], s=36, color=SURF, edgecolor=BLUE, linewidth=2, zorder=3)
ax.set_xlim(-8, 19.5); ax.set_ylim(0, 0.62)
ax.set_xlabel("seconds into the scripted test (server time)", color=INK2)
ax.set_ylabel("AI footstep volume on my client", color=INK2)
ax.set_title("Every AI footstep my client played (filled = clear: walk 0.50, sneak 0.16; hollow = muffled: highs cut 40 dB, volume x0.06)",
             loc="left", fontsize=11, color=INK)
for s in ("top", "right"): ax.spines[s].set_visible(False)
for s in ("left", "bottom"): ax.spines[s].set_color("#c9c8c2")
ax.tick_params(colors=INK2)
ax.grid(axis="y", color="#e6e5e0", lw=0.8); ax.set_axisbelow(True)
ax.annotate("0.03 (0.01 sneaking)", (8.1, 0.03), (6.6, 0.12), color=INK2, fontsize=9,
            arrowprops=dict(arrowstyle="-", color=INK2, lw=0.8))

tx = fig.add_axes([0.06, 0.03, 0.9, 0.34]); tx.axis("off")
tx.set_title("The AI around the valve (Warehouse 2, Play test; AI 38 studs from the cloud's centre unless noted)", loc="left",
             fontsize=11, color=INK)
cols = ["", "no steam", "full cloud", "mid-fade", "after"]
rows = [
    ["Sees me in the valve corner", "yes", "NO", "NO", "yes"],
    ["Sees me 20 studs out, mid haze", "yes", "NO", "yes (thinning)", "yes"],
    ["Sees me 3 studs inside the edge", "yes", "yes", "yes", "yes"],
    ["AI in the steam sees me outside", "yes", "NO", "yes (thinning)", "yes"],
    ["Hears my steps (me in the steam)", "yes", "NO", "NO", "yes"],
    ["Hears my steps (AI in the steam)", "yes", "NO", "NO", "yes"],
    ["Hears my real reload (me / AI in steam)", "yes", "NO / NO", "-", "yes"],
    ["Tutorial 3, old Warehouse (classic jet)", "-", "steps + reload masked in 22 studs, sight NOT blocked, no cloud, no muffle", "", ""],
]
t = tx.table(cellText=rows, colLabels=cols, loc="upper left", cellLoc="left", colWidths=[0.3, 0.12, 0.2, 0.2, 0.12])
t.auto_set_font_size(False); t.set_fontsize(10); t.scale(1, 1.55)
for (r, c), cell in t.get_celld().items():
    cell.set_edgecolor("#e0dfda"); cell.set_facecolor(SURF)
    cell.get_text().set_color(INK if r else INK2)
    if r == 0: cell.get_text().set_fontweight("bold")
    if cell.get_text().get_text().startswith("NO"): cell.get_text().set_fontweight("bold")
last = len(rows)
t[(last, 2)].visible_edges = "TBL"; t[(last, 3)].visible_edges = "TB"; t[(last, 4)].visible_edges = "TBR"
t[(last, 1)].get_text().set_text("")
fig.savefig("notes/steam_fill_r3_sheet.jpg", dpi=110, facecolor=SURF)
print("notes/steam_fill_r3_sheet.jpg")

"""Side sections that explain the Arena v2 ramp and window rules (Tacticals movement numbers).
    python -I tools/arena_v2_section.py -> notes/maps/arena_v2_sections.png
"""
import os
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle, Ellipse

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(HERE), "notes", "maps", "arena_v2_sections.png")
EYE, STAND, CROUCH = 4.6, 5.2, 3.2
G = dict(low="#c9c6bb", wall="#8f8c84", pillar="#55534e", post="#3d4a5c", deck="#a9b77a", ramp="#d6dfb4")
NOTE = dict(fontsize=8)


def person(ax, x, base, crouch=False, col="#3a78c2", face=1):
    top = base + (CROUCH if crouch else STAND)
    ax.add_patch(Rectangle((x - 0.5, base), 1.0, top - base - 1.1, fc=col, ec="none", alpha=0.85, zorder=5))
    ax.add_patch(Ellipse((x + 0.1 * face, top - 0.55), 1.0, 1.1, fc=col, ec="none", zorder=5))
    return top


fig, axs = plt.subplots(2, 2, figsize=(16, 10.5), dpi=105)

# 1. the height ladder ---------------------------------------------------------------------------------------------------
ax = axs[0, 0]
ax.set_title("1. Height ladder: what each deck height's eye clears", fontsize=10, loc="left")
for x, h, c, lab in ((2, 3.4, G["low"], "low wall / sill 3.4"), (6, 7, G["wall"], "wall 7"), (10, 10, G["pillar"], "pillar 10"),
                     (14, 12, G["post"], "window 12")):
    ax.add_patch(Rectangle((x, 0), 2.5, h, fc=c, ec="k", lw=0.6))
    ax.text(x + 1.25, h + 0.3, lab, ha="center", fontsize=7.5)
for h, lab in ((0, "floor: eye 4.6"), (4, "deck 4: eye 8.6"), (5, "deck 5 (this plan): eye 9.6"),
               (5.4, "deck 5.4: eye 10 = pillar top"), (6, "deck 6 (old map): eye 10.6")):
    e = h + EYE
    col = "#4d5a22" if h == 5 else ("#c2463a" if h >= 5.4 else "#777")
    ax.plot([0, 17.5], [e, e], color=col, lw=1.6 if h == 5 else 1, ls="-" if h == 5 else "--")
    ax.text(17.7, e - (0.35 if h == 5 else 0), lab, va="center", fontsize=7.5, color=col)
ax.set_xlabel("Eye below 7: sees over nothing tall. 7 to 10: over walls (weakly), never over pillars or windows.\n"
              "Eye above 10 (deck 5.4 or more): over every piece; the old 6-high perches did this. Deck 5 is the ceiling:\n"
              "its eye (9.6) stays under the pillar tops; at level pitch the third-person camera (10.1) only grazes them.", **NOTE)
ax.set_xlim(0, 28); ax.set_ylim(0, 13.5); ax.set_aspect("equal"); ax.set_xticks([])

# 2. hugged low wall vs height --------------------------------------------------------------------------------------------
ax = axs[0, 1]
ax.set_title("2. A hugged low wall holds against height (crouched 0.85 behind a 2-deep wall)", fontsize=10, loc="left")
ax.add_patch(Rectangle((20, 0), 2, 3.4, fc=G["low"], ec="k", lw=0.6))
top = person(ax, 22.85, 0, crouch=True, col="#c2463a", face=-1)
ax.add_patch(Rectangle((-2, 0), 3, 6, fc=G["deck"], ec="k", lw=0.5, alpha=0.3))
ax.add_patch(Rectangle((-2, 0), 3, 5, fc=G["deck"], ec="k", lw=0.5, alpha=0.6))
for base, lab, col in ((0, "floor eye 4.6, 22 away", "#777"), (5, "deck-5 eye 9.6", "#4d5a22"), (6, "deck-6 eye 10.6", "#c2463a")):
    e = base + EYE
    ax.plot([0, 22.85], [e, top - 1.0], color=col, lw=1.2)
    ax.text(1.3, e + 0.25, lab, fontsize=7.5, color=col)
ax.annotate("every line to 1 stud below the crouched head\nhits the wall's far top edge", xy=(21.9, 3.4), xytext=(8, 0.6), fontsize=7.5,
            arrowprops=dict(arrowstyle="->", lw=0.7))
ax.set_xlabel("1 stud of a hugging crouched player shows only within 0.85 x (eye - 2.2) / 1.2 studs: 5.2 from a deck-5 eye,\n"
              "6.0 from a deck-6 eye. Height doesn't break hugged low cover. It sees the floor BETWEEN cover:\n"
              "crouch-walkers, gap crossers, vaulters.", **NOTE)
ax.set_xlim(-2, 26); ax.set_ylim(0, 11.5); ax.set_aspect("equal"); ax.set_xticks([])

# 3. parapet shadow vs kick-curb ----------------------------------------------------------------------------------------------
ax = axs[1, 0]
ax.set_title("3. Watch edge: a 3.4 parapet hides the deck's own foot; a 1-high kick-curb does not", fontsize=10, loc="left")
for ox, kind in ((0, "parapet"), (30, "curb")):
    ax.add_patch(Rectangle((ox, 0), 6, 5, fc=G["deck"], ec="k", lw=0.6))
    ph, pw = (3.4, 2) if kind == "parapet" else (1.0, 0.5)
    ax.add_patch(Rectangle((ox + 6 - pw, 5), pw, ph, fc=G["low"] if kind == "parapet" else "#2b2b2b", ec="k", lw=0.6))
    ex, e = ox + 6 - pw - 0.85, 5 + EYE
    person(ax, ex, 5)
    tx, ty = ox + 6, 5 + ph
    slope = (e - ty) / (tx - ex)
    reach = min(tx + (ty - 2.6) / slope, ox + 28)
    ax.plot([ex, reach], [e, max(2.6, e - slope * (reach - ex))], color="#4d5a22", lw=1.2)
    ax.add_patch(Rectangle((ox + 6, 0), reach - (ox + 6), 0.25, fc="#c2463a", alpha=0.5, ec="none"))
    ax.text(ox + 6.3, -1.4, f"blind to crouched heads for {reach - (ox + 6):.0f} studs in front", fontsize=7.5, color="#c2463a")
    ax.text(ox + 0.2, 10.8, "parapet: A's perch DUEL edge (faces B's gate)" if kind == "parapet"
            else "kick-curb: the WATCH edges (A's south edge, B's ledge front)", fontsize=7.5)
ax.set_xlabel("Decks up to 5.6 high can be CLIMBED from the floor (climb reach 2.6 above the root). Every deck edge needs a parapet,\n"
              "a kick-curb, the box wall or a tall piece against it, so the ramp is the only way up.\n"
              "Ways down: the ramp, hop the curb, or vault the parapet and drop.", **NOTE)
ax.set_xlim(0, 58); ax.set_ylim(-2.5, 12); ax.set_aspect("equal"); ax.set_xticks([])

# 4. the window -----------------------------------------------------------------------------------------------------------
ax = axs[1, 1]
ax.set_title("4. Window, cut through the opening, with the vault arc", fontsize=10, loc="left")
ax.add_patch(Rectangle((10, 0), 3, 3.4, fc=G["low"], ec="k", lw=0.6))
ax.add_patch(Rectangle((10, 10), 3, 2, fc=G["post"], ec="k", lw=0.6))
ax.add_patch(Rectangle((10, 3.4), 3, 6.6, fc="none", ec=G["post"], lw=1, ls=(0, (2, 1.2))))
ax.text(11.5, 6.7, "opening\n10 wide\n6.6 high", ha="center", fontsize=7, color=G["post"])
person(ax, 9.15, 0, crouch=True)
person(ax, 15.6, 0, col="#c2463a", face=-1)
t = np.linspace(0, 1, 40)
x0, x1, apex = 9.15, 15.0, 3.4 + 1.8
cy = 2 * apex - 3
xs = (1 - t) ** 2 * x0 + 2 * (1 - t) * t * 11.5 + t ** 2 * x1
ys = (1 - t) ** 2 * 3 + 2 * (1 - t) * t * cy + t ** 2 * 3
ax.plot(xs, ys, color="#3a78c2", lw=1.2, ls="--")
ax.plot(xs, ys + 2.2, color="#3a78c2", lw=0.8, ls=":")
ax.text(0.5, 8.4, "vault: root apex 5.2 (sill + 1.8),\nhead apex about 7.4-7.8: 2.2+ under the lintel", fontsize=7.5, color="#3a78c2")
ax.plot([15.6, 9.15], [4.6, 3.2], color="#c2463a", lw=1)
ax.text(16.6, 4.9, "standing eye 4.6 sees through the opening;\nthe line to a hugging crouched head (3.2)\nstill touches the 3.4 sill",
        fontsize=7.5, color="#c2463a")
ax.set_xlabel("Frame 20 long x 3 deep x 12 high: posts 5 wide (tall cover: peek their edges), opening 10 x 6.6 over a 3.4 sill, lintel 10-12.\n"
              "Twin window = 35 long. Keep 3.5 of clear floor on both sides of every sill so Space vaults and never climbs.", **NOTE)
ax.set_xlim(0, 30); ax.set_ylim(0, 13); ax.set_aspect("equal"); ax.set_xticks([])

fig.suptitle("Arena v2: ramp and window rules in section (studs; Tacticals: eye 4.6, stand 5.2, crouch 3.2, climb reach 5.6, hop 2.2)",
             fontsize=11)
fig.tight_layout()
fig.savefig(OUT)
print("wrote", OUT)

"""Arena v2 layout (Tacticals' second match map "Arena", was "Practice Range"), generated as data. PLAN ONLY: nothing here touches a place.

    python -I tools/arena_v2_layout.py            -> notes/maps/arena_v2_layout.json
    python -I tools/arena_v2_check.py             -> checks + notes/maps/arena_v2_plan.png (+ _exposure.png, _checks.json)

Plan coordinates, in studs: x east (A spawn west, B spawn east), y north, z up; floor top = 0. The box is 150 x 110 inside
(x -75..75, y -55..55), open roof, no doors (Edward's calls on the Practice Range). To build: world = ORIGIN + (x, z, -y)
(plan north = world -Z, as fix/map_arena.lua, was fix/map_practice_range.lua).

Pieces are Tacticals' own cover at the tutorial sizes plus the two new collidable pieces Edward asked for:
    pillar  5 x 5,  10 high          (tall cover: peek the edges)
    wall    10 x 3,  7 high          (tall cover)
    low     6 x 2,   3.4 high        (crouch cover, vaultable)
    window  20 x 3 frame, 12 high: two 5-wide posts, a 10-wide x 6.6-high opening over a 3.4 sill (= low-wall height,
            vault + shoot through), a 2-high lintel (10..12). A twin window is 35 long (post, opening, post, opening, post).
    deck    raised floor, 4 high, with 3.4 parapets on its open edges (= a low wall on top)
    ramp    wedge 0 -> 4 over a 12 run (18.4 deg), 8 wide; the only way up a deck
Every part is axis-aligned (CoverController measures cover from the part's box) and sits on a 0.5 grid.
"""
import json, math, os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(HERE), "notes", "maps", "arena_v2_layout.json")

BOX = dict(x0=-75, x1=75, y0=-55, y1=55, wall_h=16, wall_t=2)
H = dict(pillar=10, wall=7, low=3.4, sill=3.4, lintel_lo=10, window=12, deck=4, parapet=3.4, curb=1)

pieces = []   # each: id, kind, side ('A'/'B'/'C'), parts: [{x0,x1,y0,y1,z0,z1, role}] or ramp dict


def box(x0, x1, y0, y1, z0, z1, role):
    return dict(x0=x0, x1=x1, y0=y0, y1=y1, z0=z0, z1=z1, role=role)


def add(pid, kind, side, parts, **kw):
    p = dict(id=pid, kind=kind, side=side, parts=parts)
    p.update(kw)
    pieces.append(p)
    return p


def pillar(pid, cx, cy, side):
    return add(pid, "pillar", side, [box(cx - 2.5, cx + 2.5, cy - 2.5, cy + 2.5, 0, H["pillar"], "solid")])


def wall(pid, cx, cy, along, side):  # along = 'x' (10 long east-west) or 'y' (10 long north-south)
    hx, hy = (5, 1.5) if along == "x" else (1.5, 5)
    return add(pid, "wall", side, [box(cx - hx, cx + hx, cy - hy, cy + hy, 0, H["wall"], "solid")], along=along)


def low(pid, cx, cy, along, side, length=6):
    hx, hy = (length / 2, 1) if along == "x" else (1, length / 2)
    return add(pid, "low", side, [box(cx - hx, cx + hx, cy - hy, cy + hy, 0, H["low"], "low")], along=along)


def window(pid, cx, cy, along, side, openings=1, faces=None, looks=None):
    """A window wall centred on (cx, cy), 3 thick. Openings 10 wide, posts 5 wide, sill 3.4, lintel 10..12."""
    L = 5 + openings * 15
    parts, s = [], -L / 2
    segs = []
    for i in range(openings):
        segs.append(("post", s, s + 5)); s += 5
        segs.append(("open", s, s + 10)); s += 10
    segs.append(("post", s, s + 5))
    for kind, a, b in segs:
        if along == "x":
            x0, x1, y0, y1 = cx + a, cx + b, cy - 1.5, cy + 1.5
        else:
            x0, x1, y0, y1 = cx - 1.5, cx + 1.5, cy + a, cy + b
        if kind == "post":
            parts.append(box(x0, x1, y0, y1, 0, H["window"], "solid"))
        else:
            parts.append(box(x0, x1, y0, y1, 0, H["sill"], "sill"))
            parts.append(box(x0, x1, y0, y1, H["lintel_lo"], H["window"], "lintel"))
    return add(pid, "window", side, parts, along=along, openings=openings, faces=faces, looks=looks)


def deck(pid, x0, x1, y0, y1, side, parapets, ramp_spec, h=H["deck"], curbs=(), on_deck=(), **kw):
    """Raised floor h high.
    parapets: (edge, a, b) - a 2-thick, 3.4-high low wall along that edge from a to b (plan coords along it).
    curbs:    (edge, a, b) - a 0.5-thick, 1-high kick-curb on the edge: stops the CLIMB from the floor (the climb's edge ray at
              deck + 0.6 hits it) but hardly shades the floor below (a parapet hides the first ~12 studs in front of it).
    on_deck:  (kind, cx, cy, along) - tall cover standing on the deck ('pillar' 5 x 5 x 10, 'wall' 10 x 3 x 7).
    ramp_spec: (foot_x, foot_y, top_x, top_y, width): the wedge rises from foot to top (top = on the deck edge)."""
    parts = [box(x0, x1, y0, y1, 0, h, "deck")]
    def edge_box(edge, a, b, t, z1, role):
        if edge == "N": return box(a, b, y1 - t, y1, h, z1, role)
        if edge == "S": return box(a, b, y0, y0 + t, h, z1, role)
        if edge == "E": return box(x1 - t, x1, a, b, h, z1, role)
        return box(x0, x0 + t, a, b, h, z1, role)
    for edge, a, b in parapets:
        parts.append(edge_box(edge, a, b, 2, h + H["parapet"], "parapet"))
    for edge, a, b in curbs:
        parts.append(edge_box(edge, a, b, 0.5, h + H["curb"], "curb"))
    for kind, cx, cy, along in on_deck:
        if kind == "pillar":
            parts.append(box(cx - 2.5, cx + 2.5, cy - 2.5, cy + 2.5, h, h + H["pillar"], "solid"))
        else:
            hx, hy = (5, 1.5) if along == "x" else (1.5, 5)
            parts.append(box(cx - hx, cx + hx, cy - hy, cy + hy, h, h + H["wall"], "solid"))
    fx, fy, tx, ty, w = ramp_spec
    run = math.hypot(tx - fx, ty - fy)
    ramp = dict(foot=[fx, fy], top=[tx, ty], width=w, rise=h, run=run, slope_deg=round(math.degrees(math.atan2(h, run)), 1))
    return add(pid, "deck", side, parts, ramp=ramp, h=h, **kw)


# ---------------------------------------------------------------------------------------------------------------------------
# THE LAYOUT. Three lanes between two spawn pockets: NORTH (y 20..55), CENTRE (y -18..18), SOUTH (y -55..-20).
# Centre: one twin window wall across the middle (the landmark; same for both sides).
# A (west) owns the HIGH GROUND in the north (a square perch) and an ANGLE in the south (a corner window).
# B (east) owns an ANGLE in the north (a corner window) and the HIGH GROUND in the south (a long ledge).
# The halves are not a mirror or a turn of each other: the perches, windows, spawn shields and cover chains have different
# shapes and distances; fairness is checked by timing (arena_v2_check.py) instead of by symmetry.
# ---------------------------------------------------------------------------------------------------------------------------

# --- centre landmark: the twin windows (north-south wall across the middle, 35 long, 2 openings)
window("CentreWindows", 0, 0, "y", "C", openings=2, faces="both",
       looks="each sill looks straight down the centre at the other side's fallback cover")
# A centre fallback: two pillar + low-wall chains, 10 behind the sills
pillar("A_C_P", -12.5, 10, "A"); low("A_C_L", -12.5, 4.5, "y", "A")
low("A_C_L2", -12.5, -6, "y", "A"); pillar("A_C_P2", -12.5, -11.5, "A")
# B centre fallback: a wall, then a low wall + pillar chain
wall("B_C_W", 12, -8, "y", "B"); low("B_C_L", 12, 6, "y", "B"); pillar("B_C_P", 12, 12, "B")

# --- the lane gates: one big twin window closes each lane on one side. B holds the north gate, A the south gate.
window("B_NorthGate", 23, 37.5, "y", "B", openings=2, faces="west",
       looks="west down the north lane: the mid island, the north gap and A's perch")
window("A_SouthGate", -23, -37.5, "y", "A", openings=2, faces="east",
       looks="east down the south lane: the mid island, the south gap and B's ledge")

# --- A spawn (west): pocket behind a 20-long solid shield of two walls
wall("A_Shield_N", -61.5, 5, "y", "A"); wall("A_Shield_S", -61.5, -5, "y", "A")
# --- A north: THE PERCH (square, 12 x 10, against the north wall). Ramp from A's staging, rising east along the north wall.
deck("A_Perch", -40, -28, 45, 55, "A",
     parapets=[("E", 45, 55)], curbs=[("S", -40, -30), ("W", 45, 47)],
     ramp_spec=(-52, 51, -40, 51, 8),
     job="TOWER: a watch edge (curb) over the north lane + a crouch parapet facing B's gate 50 away", style="curb+parapet")
pillar("A_NStage_P", -50, 25, "A"); low("A_NStage_L", -44.5, 25, "x", "A")      # pocket exit -> ramp foot
wall("A_NW_W", -66, 32, "x", "A")                                                 # NW corner breaker
wall("A_NW_W2", -66, 46, "x", "A")
pillar("A_N_P", -18, 32.5, "A"); low("A_N_L", -18, 26.5, "y", "A")              # last A cover before the north gap
low("A_PerchFront_L", -31, 37.5, "x", "A")                                       # in the perch's own radius: a trap for B
pillar("A_PerchFoot_P", -45, 38, "A")                                            # tall cover under the perch (B's counter)
# --- A centre / south staging
wall("A_Mid_W", -40, 7, "y", "A"); pillar("A_Mid_P", -40, -6, "A")             # in front of the pocket
pillar("A_Fwd_P", -27, 12, "A"); low("A_Fwd_L", -27, 6.5, "y", "A"); wall("A_Fwd_W", -27, -10, "x", "A")
low("A_S_L", -32, -22, "x", "A"); pillar("A_S_P", -37.5, -22, "A")              # behind the south gate's north end
wall("A_SW_W", -55, -36, "y", "A")                                              # SW corner breaker
pillar("A_SW_P", -67.5, -46, "A"); low("A_SW_L", -67.5, -40.5, "y", "A")
low("A_SStage_L", -46, -46, "y", "A")
pillar("A_SExit_P", -68, -24, "A")
pillar("A_PocketN_P", -45, 15, "A")                                            # closes a 100-stud line from B's gate to the pocket's north edge
low("A_NWall_L", -12, 50, "x", "A")                                             # along the north wall, inside the perch's band

# --- B spawn (east): pocket behind a pillar - wall - pillar shield (20 long), set 2.5 north of A's
pillar("B_Shield_S", 61.5, -5, "B"); wall("B_Shield_W", 61.5, 2.5, "y", "B"); pillar("B_Shield_N", 61.5, 10, "B")
# --- B south: THE LEDGE (long and shallow, 20 x 6, against the south wall). Ramp from B's staging, rising west.
deck("B_Ledge", 26, 46, -55, -47, "B",
     parapets=[], curbs=[("N", 26, 46), ("W", -55, -47.5)], on_deck=[("wall", 36, -49, "x")],
     ramp_spec=(58, -51, 46, -51, 8),
     job="BALCONY: open front with a kick-curb, a wall on the deck to peek; sees its own foot, no crouch cover", style="open")
pillar("B_SStage_P", 50, -25, "B"); low("B_SStage_L", 50, -31, "y", "B")        # pocket exit -> ramp foot
wall("B_SE_W", 66, -32, "x", "B")                                                 # SE corner breaker
wall("B_SE_W2", 68, -44, "y", "B")
pillar("B_S_P", 17, -31, "B"); low("B_S_L", 17, -25, "y", "B")                  # last B cover before the south gap
low("B_LedgeFront_L", 36, -40, "x", "B")                                          # in the ledge's own radius
wall("B_LedgeFoot_W", 15, -47, "x", "B")                                          # tall cover for attackers under the ledge (out of its view line)
# --- B centre / north staging
pillar("B_Mid_P", 40, 8, "B"); wall("B_Mid_W", 40, -5, "y", "B")
wall("B_Fwd_W", 27, 10, "x", "B"); low("B_Fwd_L", 27, -7, "y", "B"); pillar("B_Fwd_P", 27, -12.5, "B")
low("B_N_L", 32, 22, "x", "B"); pillar("B_N_P", 37.5, 22, "B")                  # behind the north gate's south end
wall("B_NE_W", 55, 38, "y", "B")
pillar("B_NE_P", 67.5, 47, "B"); low("B_NE_L", 67.5, 41.5, "y", "B")
low("B_NStage_L", 46, 47, "y", "B")
low("B_NExit_L", 68, 21, "x", "B"); pillar("B_SExit_P", 68, -20, "B")
pillar("B_PocketS_P", 44, -12.5, "B")                                          # closes the line from A's gate to the pocket's south edge

# --- mid-lane islands (the decision points in each lane), different shapes north and south
pillar("N_Mid_P", 0, 40, "C"); low("N_Mid_L", 0, 34.5, "y", "C")
pillar("S_Mid_P1", -6.5, -40, "C"); low("S_Mid_L", -1, -40, "x", "C")   # free east end is safe: the pillar top is 6.6 above it

# --- spawns (1v1 = the middle spot; 2v2 / 3v3 = the spots 4 apart)
spawns = {
    "A": dict(pocket=[-75, -63, -10, 10], spots=[[-70, 0], [-70, 4], [-70, -4]], face=[1, 0]),
    "B": dict(pocket=[63, 75, -7.5, 12.5], spots=[[70, 2.5], [70, 6.5], [70, -1.5]], face=[-1, 0]),
}

# --- named places used by the timing checks and the walkthrough
spots = {
    "Mid_A": dict(pos=[-3.5, 7.5, 0], side="A", kind="middle", note="A's sill of the twin windows (north opening)"),
    "Mid_B": dict(pos=[3.5, 7.5, 0], side="B", kind="middle", note="B's sill of the twin windows (north opening)"),
    "Mid_A_S": dict(pos=[-3.5, -7.5, 0], side="A", kind="middle", note="A's sill, south opening"),
    "Mid_B_S": dict(pos=[3.5, -7.5, 0], side="B", kind="middle", note="B's sill, south opening"),
    "A_Perch": dict(pos=[-34, 46.5, 4], side="A", kind="height", note="A's perch: the watch edge (kick-curb) over the north lane", ref=[-34, 41]),
    "A_PerchDuel": dict(pos=[-31.2, 51, 4], side="A", kind="height", note="A's perch: crouched behind the east parapet (the long duel with B's gate)", ref=[-26, 51]),
    "B_Ledge": dict(pos=[29.5, -48, 4], side="B", kind="height", note="B's ledge: the west end, peeking the deck wall", ref=[29, -43]),
    "B_Ledge_E": dict(pos=[43.5, -48, 4], side="B", kind="height", note="B's ledge: the east end of the deck wall", ref=[43.5, -43]),
    "A_PerchTop": dict(pos=[-38.5, 51, 4], side="A", kind="ramp", note="top of A's ramp"),
    "B_LedgeTop": dict(pos=[44.5, -51, 4], side="B", kind="ramp", note="top of B's ramp"),
    "A_SouthGate": dict(pos=[-26, -32.5, 0], side="A", kind="window", note="A's side of the south gate (north opening)"),
    "B_NorthGate": dict(pos=[26, 32.5, 0], side="B", kind="window", note="B's side of the north gate (south opening)"),
    "N_Island": dict(pos=[-2.5, 34.5, 0], side="C", kind="gap", note="the north mid island (west face of its low wall)"),
    "S_Island": dict(pos=[-1, -37.5, 0], side="C", kind="gap", note="the south mid island (north face of its low wall, between the pillars)"),
}

# --- deliberate open crossings: from the last cover on one side to the next cover (edge to edge, along the walking line)
gaps = [
    dict(id="NorthGap_A", crosser="A", a=[-15.5, 30], b=[-1, 33], note="A's north chain -> mid island"),
    dict(id="NorthGap_B", crosser="B", a=[21.5, 30], b=[1, 33], note="B's north gate -> mid island"),
    dict(id="SouthGap_B", crosser="B", a=[14.5, -31], b=[2.5, -38], note="B's south chain -> mid island"),
    dict(id="SouthGap_A", crosser="A", a=[-21.5, -30], b=[-9, -38], note="A's south gate -> mid island"),
    dict(id="Centre_A", crosser="A", a=[-11.5, 1.5], b=[-1.5, 2.5], note="A's centre chain -> the centre post (sill)"),
    dict(id="Centre_B", crosser="B", a=[10.5, -3], b=[1.5, -2.5], note="B's centre wall -> the centre post (sill)"),
    dict(id="Rot_A_NtoC", crosser="A", a=[-18, 23.5], b=[-12.5, 12.5], note="A rotation: north chain -> centre pillar"),
    dict(id="Rot_B_StoC", crosser="B", a=[17, -22], b=[12, -13], note="B rotation: south chain -> centre wall"),
]

# --- timing pairs that must be within 10 % (A's target, B's target); the gaps are reported, not judged
balance = [
    dict(what="middle (nearest sill)", A=["Mid_A", "Mid_A_S"], B=["Mid_B", "Mid_B_S"]),
    dict(what="own high ground (first peek)", A=["A_Perch"], B=["B_Ledge", "B_Ledge_E"]),
    dict(what="own high ground (ramp top)", A=["A_PerchTop"], B=["B_LedgeTop"]),
    dict(what="own gate", A=["A_SouthGate"], B=["B_NorthGate"]),
    dict(what="enemy high ground (contest: ramp top)", A=["B_LedgeTop"], B=["A_PerchTop"]),
    dict(what="enemy gate (contest)", A=["B_NorthGate"], B=["A_SouthGate"]),
    dict(what="north island", A=["N_Island"], B=["N_Island"]),
    dict(what="south island", A=["S_Island"], B=["S_Island"]),
]

# --- key sight lines to draw (from -> to, both at eye height over their floors)
sightlines = [
    dict(a="A_Perch", b="N_Island", note="perch watches the north island and gap"),
    dict(a="B_NorthGate", b="N_Island", note="north gate watches the island"),
    dict(a="B_Ledge", b="S_Island", note="ledge watches the south island and gap"),
    dict(a="A_SouthGate", b="S_Island", note="south gate watches the island"),
    dict(a="B_NorthGate", b="A_Perch", note="counter: the gate duels the perch"),
    dict(a="A_SouthGate", b="B_Ledge", note="counter: the gate duels the ledge"),
    dict(a="Mid_A", b="Mid_B", note="the centre duel through the twin windows"),
]

data = dict(
    name="Arena v2", version=1, units="studs", plan_axes="x east, y north, z up; world = ORIGIN + (x, z, -y)",
    box=BOX, heights=H, pieces=pieces, spawns=spawns, spots=spots, gaps=gaps, sightlines=sightlines, balance=balance,
    movement=dict(walk=10, sprint=20, crouch=4.8, cover_dash=24, cover_dash_max=26, cover_sneak=8, vault_s=0.34375,
                  silent_vault_s=0.584, vault_clearance=1.8, climb_s="0.62 + 0.06/stud", climb_max_above_feet=5.6,
                  climb_min_depth=5, hop=2.2, jump=0, eye=4.6, camera=5.1, stand_top=5.2, crouch_top=3.2,
                  source="CoverConfig + MovementConfig in match_place_ref.rbxl (2026-10-26), fix/movement_spec.lua"),
)

if __name__ == "__main__":
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    json.dump(data, open(OUT, "w"), indent=1)
    print(f"wrote {OUT}: {len(pieces)} pieces, {sum(len(p['parts']) for p in pieces)} parts")

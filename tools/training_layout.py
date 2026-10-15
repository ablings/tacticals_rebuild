"""Training v2 layout (Parts-first build data), refined from out/training_spec/plan_new.json.
Writes fix/training_layout.lua (data module, pasted into fix/place_training.lua between the --@LAYOUT markers)
and out/training/layout_plan.png. Checks overlaps between solid pieces and spot / arrival clearances in plan.
Usage (from tacticals_rebuild): python tools/training_layout.py
Coordinates: Studio x (east), z (north-up in the plan); floor top y 600 (FLOOR), roof level +24, ceiling bottom +48."""
import json, math, os, re, sys
FLOOR, ROOF, CEIL = 600, 24, 48

items = []   # dict(kind, x0, z0, x1, z1, h, y0 (offset of bottom above floor), ...)
def add(kind, x0, z0, x1, z1, h, y0=0.0, **kw):
    x0, x1 = sorted((x0, x1)); z0, z1 = sorted((z0, z1))
    d = dict(kind=kind, x0=x0, z0=z0, x1=x1, z1=z1, h=h, y0=y0); d.update(kw); items.append(d); return d

# ---------------------------------------------------------------- shell: floor, perimeter, gallery, ceiling
add("floor", -130, -130, 130, 130, 2, -2)                       # arena slab, top 600
add("gfloor", 130, -36, 136, 36, 2, -2, tone=2)                 # firing strip
for i in range(8):                                              # 25-stud bands 136..336 (sage / warm grey)
    add("gfloor", 136 + 25 * i, -36, 161 + 25 * i, 36, 2, -2, tone=i % 2)
add("gfloor", 336, -36, 352, 36, 2, -2, tone=2)
W = 48
add("wall", -130, 128, 130, 130, W); add("wall", -130, -130, 130, -128, W)
add("wall", -130, -128, -128, 128, W)
add("wall", 128, 36, 130, 128, W); add("wall", 128, -128, 130, -36, W)
add("wall", 130, 36, 354, 38, W); add("wall", 130, -38, 354, -36, W); add("wall", 352, -36, 354, 36, W)
add("ceiling", -130, -130, 130, 130, 2, CEIL); add("ceiling", 130, -38, 354, 38, 2, CEIL)

# ---------------------------------------------------------------- spawn plaza (inlay 0.1 proud), boulevards
add("plaza", -20, -20, 20, 20, 0.2, -0.1)

# ---------------------------------------------------------------- NW block maze, roofs at +24 (one connected deck)
B = {
    "b1": (-122, 32, -102, 56), "b2": (-92, 32, -76, 48), "b3": (-72, 36, -48, 56), "b4": (-42, 32, -22, 48),
    "b5": (-120, 68, -96, 84), "b6": (-84, 68, -68, 92), "b7": (-58, 66, -38, 86),
    "b9": (-92, 104, -68, 120), "b10": (-58, 98, -42, 118), "b11": (-36, 96, -24, 108),
    "o1": (76, 90, 102, 114), "o2": (54, 34, 74, 46),
}
BAST = {"bNW": (-128, 104, -104, 128), "bNE": (104, 104, 128, 128), "bSW": (-128, -128, -104, -104), "bSE": (104, -128, 128, -104)}
for k, (x0, z0, x1, z1) in B.items(): add("block", x0, z0, x1, z1, ROOF, id=k)
for k, (x0, z0, x1, z1) in BAST.items(): add("bastion", x0, z0, x1, z1, ROOF, id=k)
ALL = dict(B); ALL.update(BAST)

def bridge(a, b, w=6):
    ax0, az0, ax1, az1 = ALL[a]; bx0, bz0, bx1, bz1 = ALL[b]
    if ax1 <= bx0 or bx1 <= ax0:   # separated along x: span the x gap, centre on the z overlap
        lo, hi = max(az0, bz0), min(az1, bz1); assert hi - lo >= w, (a, b)
        c = (lo + hi) / 2; x0, x1 = (ax1, bx0) if ax1 <= bx0 else (bx1, ax0)
        return add("bridge", x0 - 0.5, c - w / 2, x1 + 0.5, c + w / 2, 1, ROOF - 1, link=a + "-" + b)
    lo, hi = max(ax0, bx0), min(ax1, bx1); assert hi - lo >= w, (a, b)
    c = (lo + hi) / 2; z0, z1 = (az1, bz0) if az1 <= bz0 else (bz1, az0)
    return add("bridge", c - w / 2, z0 - 0.5, c + w / 2, z1 + 0.5, 1, ROOF - 1, link=a + "-" + b)
for a, b in [("b1", "b2"), ("b2", "b3"), ("b3", "b4"), ("b1", "b5"), ("b5", "b6"), ("b6", "b7"), ("b3", "b7"), ("b5", "bNW"),
             ("bNW", "b9"), ("b6", "b9"), ("b9", "b10"), ("b7", "b10"), ("b10", "b11"), ("o1", "bNE")]:
    bridge(a, b)

# ramps (WedgePart; 'rise' = direction the slope climbs toward; top meets a block face at +24)
add("ramp", -30, 48, -22, 88, ROOF, rise="S", to="b4")     # 40 run: 31 deg; maze deck from the north boulevard
add("ramp", 36, 102, 76, 110, ROOF, rise="E", to="o1")     # 40 run: overwatch deck from the NE towers
# truss ladders 2x2 against a block face, floor to +24 (TrussPart sizes are multiples of 2)
for x0, z0, to in [(-113, 30, "b1"), (-61, 34, "b3"), (-81, 120, "b9"), (-24, 101, "b11"), (63, 32, "o2"), (-104, -112, "bSW"),
                   (102, -112, "bSE"), (115, 102, "bNE"), (-104, 122, "bNW"), (-86, 86, "b6")]:
    add("truss", x0, z0, x0 + 2, z0 + 2, ROOF, to=to)

# ---------------------------------------------------------------- NE towers (floor to ceiling landmarks) + tall cover
for x0, z0 in [(52, 92), (96, 56), (36, 48)]: add("tower", x0, z0, x0 + 8, z0 + 8, 36)   # capped at +36 (ceiling 648; tightrope/pad headroom)
for r in [(26, 79, 38, 81), (79, 74, 81, 86), (104, 29, 116, 31), (28, 112, 30, 124), (70, 63, 82, 65)]: add("tall", *r, 10)

# ---------------------------------------------------------------- SW cover / peek course (plan_new rows, snapped to 0.5)
sw = [("low", -38.06, -43.79, -36.06, -33.79, 3.5), ("pillar", -37.09, -65.42, -33.09, -61.42, 12), ("block4", -38.28, -87.57, -33.28, -82.57, 4),
      ("low", -39.65, -112.94, -37.65, -102.94, 3.5), ("low", -59.78, -41.53, -57.78, -31.53, 3.5), ("low", -59.58, -68.27, -57.58, -58.27, 3.5),
      ("tall", -57.45, -87.39, -55.45, -75.39, 10), ("low", -59.26, -115.21, -57.26, -105.21, 3.5), ("pillar", -77.24, -34.42, -73.24, -30.42, 12),
      ("block4", -78.04, -63.33, -73.04, -58.33, 4), ("low", -74.14, -92.63, -72.14, -82.63, 3.5), ("pillar", -75.85, -111.68, -71.85, -107.68, 12),
      ("low", -99.13, -44.06, -97.13, -34.06, 3.5), ("tall", -98.15, -63.47, -96.15, -51.47, 10), ("low", -98.92, -88.35, -96.92, -78.35, 3.5),
      ("low", -96.17, -114.02, -94.17, -104.02, 3.5), ("tall", -117, -92, -115, -52, 10)]
snap = lambda v: round(v * 2) / 2
for k, x0, z0, x1, z1, h in sw: add(k, snap(x0), snap(z0), snap(x1), snap(z1), h)
# extra SW cover (crates beside the rows: the spec's ~90 low pieces need more than the plan's)
for x, z in [(-48, -52), (-66, -100), (-86, -48), (-108, -70), (-86, -122), (-48, -122)]: add("crate", x - 2, z - 2, x + 2, z + 2, 4)

# ---------------------------------------------------------------- SE free-fire field: lines + low cover / crates
for z in (-45, -70, -95, -120): add("line", 20, z - 0.25, 124, z + 0.25, 0.2, -0.12, tone="olive")
for r in [(35, -41, 45, -39), (71, -39, 81, -37), (103, -49, 113, -47), (47, -65, 57, -63), (29, -91, 39, -89), (65, -97, 75, -95),
          (107, -101, 117, -99), (45, -117, 55, -115)]: add("low", *r, 3.5)
for x, z in [(92, -70), (24, -60), (116, -76), (84, -108)]: add("crate", x - 2.5, z - 2.5, x + 2.5, z + 2.5, 5)
for r in [(58, -85, 70, -83), (88, -119, 100, -117)]: add("tall", *r, 10)

# ---------------------------------------------------------------- boulevard low cover (keeps sight lines open)
for r in [(-61, 3, -59, 13), (-93, -15, -91, -5), (3, 59, 13, 61), (-15, 95, -5, 97), (5, -61, 15, -59), (-13, -101, -3, -99),
          (59, -11, 61, -1), (95, 3, 97, 13)]: add("low", *r, 3.5)
# NE floor cover between the towers
for x, z in [(70, 80), (112, 44), (44, 70), (90, 76)]: add("crate", x - 2, z - 2, x + 2, z + 2, 4)
# maze street crates
for x, z in [(-97, 92), (-30, 62), (-86, 58), (-112, 92)]: add("crate", x - 2, z - 2, x + 2, z + 2, 4)

# ---------------------------------------------------------------- gallery: firing-line counters, lane divider line, firing line
add("counter", 131, 16, 133, 36, 3.5); add("counter", 131, -36, 133, -16, 3.5)
add("line", 135.75, -36, 136.25, 36, 0.2, -0.12, tone="olive")      # firing line
add("line", 136, -0.25, 352, 0.25, 0.2, -0.12, tone="cream")         # lane divider
add("line", -20, -20.25, 20, -19.75, 0.2, 0.0, tone="olive"); add("line", -20, 19.75, 20, 20.25, 0.2, 0.0, tone="olive")   # plaza edge
add("line", -20.25, -20, -19.75, 20, 0.2, 0.0, tone="olive"); add("line", 19.75, -20, 20.25, 20, 0.2, 0.0, tone="olive")

# ---------------------------------------------------------------- density fill (step 2, 2026-10-15): bare areas -> spec counts
# mid = RIVALS' 10-35 mid blocks (unreachable tops, grid tiles); more low / tall cover, pillars and crates where the plan was bare.
FILL = [
    # NE towers zone
    ("mid", 98, 70, 110, 80, 12), ("mid", 56, 68, 64, 76, 8), ("low", 22, 96, 32, 98, 3.5), ("low", 110, 92, 120, 94, 3.5),
    ("pillar", 118, 60, 122, 64, 12), ("pillar", 84, 40, 88, 44, 12), ("tall", 40, 84, 42, 96, 10), ("low", 86, 120, 96, 122, 3.5),
    ("low", 24, 30, 34, 32, 3.5), ("mid", 108, 8, 116, 16, 10),
    # SE field
    ("mid", 36, -32, 48, -26, 8), ("mid", 96, -60, 104, -52, 10), ("pillar", 60, -110, 64, -106, 12), ("pillar", 116, -60, 120, -56, 12),
    ("low", 24, -108, 34, -106, 3.5), ("crate", 52, -82, 56, -78, 4), ("crate", 78, -86, 82, -82, 4),
    # SW cover course
    ("mid", -49, -80, -43, -70, 8), ("mid", -90, -76, -82, -66, 12), ("tall", -30, -60, -28, -48, 10), ("pillar", -30, -84, -26, -80, 12),
    ("mid", -108, -100, -100, -92, 10), ("low", -112, -30, -102, -28, 3.5), ("crate", -68, -40, -64, -36, 4), ("low", -88, -100, -86, -90, 3.5),
    ("crate", -30, -120, -26, -116, 4), ("low", -100, -126, -90, -124, 3.5),
    # band between the west boulevard and the maze, west boulevard
    ("low", -80, 24, -70, 26, 3.5), ("low", -100, 22, -90, 24, 3.5), ("pillar", -118, -4, -114, 0, 12), ("crate", -42, 22, -38, 26, 4),
    ("low", -124, 10, -122, 20, 3.5),
    # north boulevard / north wall
    ("crate", 8, 108, 12, 112, 4), ("low", -14, 120, -4, 122, 3.5),
]
for k, x0, z0, x1, z1, h in FILL:
    if h <= 0: continue
    add(k, x0, z0, x1, z1, h)

# ---------------------------------------------------------------- Training extras geometry (step 2; built into Training.Extras.<Feature>)
TOWER_TOP = 36
PADS = [  # (x, z, surface offset above floor, land x, land surface offset, land z)  4x4 olive pads, NotCover
    (68, 96, 0, 56, TOWER_TOP, 96), (88, 60, 0, 100, TOWER_TOP, 60), (30, 52, 0, 40, TOWER_TOP, 52), (-32, 24, 0, -32, ROOF, 42),
    (-99, -122, 0, -110, ROOF, -110), (96, -108, 0, 114, ROOF, -114), (84, 98, ROOF, 56, TOWER_TOP, 96), (-64, 27, 0, -66, ROOF, 40),
]
ROPES = [  # (x0, z0, x1, z1, surface offset): walk box from edge to edge
    (60, 96, 96, 60, TOWER_TOP), (96, 60, 44, 52, TOWER_TOP), (40, 56, 56, 92, TOWER_TOP), (-22, 40, 54, 40, ROOF),
]
BINS = [  # (x, z, surface offset)
    (17, -17, 0), (-17, 17, 0), (126, 0, 0), (-40, -24, 0), (110, -30, 0), (-12, 116, 0),
    (-76, 84, ROOF), (120, -120, ROOF), (98, 110, ROOF),
]
DPS = [  # (x, z, facing): gallery second positions + south boulevard
    (173, 6, "-x"), (223, -6, "-x"), (273, 6, "-x"), (323, -6, "-x"),
    (-6, -40, "plaza"), (8, -70, "plaza"), (-8, -88, "plaza"), (6, -118, "plaza"),
]
for x, z, y, *_ in PADS: add("pad", x - 2, z - 2, x + 2, z + 2, 0.4, y)
for x, z, y in BINS: add("bin", x - 1.5, z - 1.5, x + 1.5, z + 1.5, 3, y)

# ---------------------------------------------------------------- EnemySpots (44) and Arrivals (16)
spots = []
def spot(x, z, roof, zone, gallery=None):
    spots.append(dict(x=x, z=z, roof=roof, zone=zone, gallery=gallery))
for d in range(8):
    x = 161 + 25 * d
    for lane, z in (("N", 20), ("S", -20)): spot(x, z, 0, "gallery", dict(dist=25 * (d + 1), lane=lane))
for x, z in [(-100, 60), (-60, 62), (-90, 96), (-64, 94), (-38, 60)]: spot(x, z, 0, "maze")
for x, z in [(-112, 44), (-60, 46), (-80, 112), (-48, 76)]: spot(x, z, ROOF, "maze roof")
for x, z in [(90, 102), (64, 40)]: spot(x, z, ROOF, "overwatch roof")
for x, z in [(-116, 116), (116, 116), (-116, -116)]: spot(x, z, ROOF, "bastion roof")
for x, z in [(84, 52), (46, 118), (112, 84)]: spot(x, z, 0, "towers")
for x, z in [(-46, -40), (-66, -64), (-86, -86), (-106, -40), (-122, -72)]: spot(x, z, 0, "cover")
for x, z in [(44, -45), (84, -46), (60, -70), (100, -96), (40, -120), (76, -122)]: spot(x, z, 0, "field")
assert len(spots) == 44, len(spots)
arrivals = [dict(x=round(14 * math.cos(math.radians(a)), 2), z=round(14 * math.sin(math.radians(a)), 2), deg=a) for a in [22.5 * i for i in range(16)]]

# ---------------------------------------------------------------- signs (CanCollide/CanQuery off) and lights
signs = []
for d in range(8):
    x = 161 + 25 * d
    for z in (20, -20): signs.append(dict(kind="hang", x=x, z=z, y=16, text=str(25 * (d + 1)), face="-x"))
for z, t in [(-45, "25"), (-70, "50"), (-95, "75"), (-120, "100")]: signs.append(dict(kind="wall", x=128, z=z, y=6, text=t, face="-x"))
signs.append(dict(kind="floor", x=0, z=-12, y=0, text="[M] LEAVE", face="up"))
lights = [dict(x=x, z=z) for x in (-96, -32, 32, 96) for z in (-96, -32, 32, 96)] + [dict(x=x, z=0) for x in (180, 244, 308)]

# ---------------------------------------------------------------- floating bullseyes (1 HP): seeded scatter with clearances
import random
rng = random.Random(4417)
BR = 1.5
SOLID3 = {"block", "bastion", "tower", "tall", "low", "pillar", "block4", "crate", "counter", "truss", "ramp", "mid", "bridge", "pad", "bin"}
def near_box(x, y, z, b, pad):
    yb0, yb1 = FLOOR + b["y0"], FLOOR + b["y0"] + b["h"]
    return b["x0"] - pad < x < b["x1"] + pad and b["z0"] - pad < z < b["z1"] + pad and yb0 - pad < y < yb1 + pad
def seg_d(px, pz, ax, az, bx, bz):
    vx, vz = bx - ax, bz - az; L = vx * vx + vz * vz
    t = max(0, min(1, ((px - ax) * vx + (pz - az) * vz) / L)) if L else 0
    return math.hypot(px - (ax + vx * t), pz - (az + vz * t))
bulls = []
tries = 0
while len(bulls) < 120 and tries < 50000:
    tries += 1
    x, z = rng.uniform(-122, 122), rng.uniform(-122, 122)
    # the walkable surface under the point (roof decks / tower tops count): keep >= 10 above it (camera / heads)
    top = 0
    for b in items:
        if b["kind"] in ("block", "bastion", "tower", "mid", "tall", "pillar", "bridge") and b["x0"] - 3 < x < b["x1"] + 3 and b["z0"] - 3 < z < b["z1"] + 3:
            top = max(top, b["y0"] + b["h"])
    lo = top + 10
    if lo > CEIL - 8: continue
    y = FLOOR + rng.uniform(lo, min(CEIL - 8, lo + 30))
    if any(near_box(x, y, z, b, BR + 2) for b in items if b["kind"] in SOLID3): continue
    if any(math.dist((x, y, z), (q["x"], q["y"], q["z"])) < 9 for q in bulls): continue
    if any(seg_d(x, z, px, pz, lx, lz) < 6 for px, pz, py, lx, ly, lz in PADS): continue      # pad arcs
    if any(seg_d(x, z, a, b2, c, d) < 5 and y < FLOOR + yy + 12 for a, b2, c, d, yy in ROPES): continue   # rope walkers
    if math.hypot(x, z) < 22: continue                                                      # spawn plaza column
    bulls.append(dict(x=round(x, 1), y=round(y - FLOOR, 1), z=round(z, 1)))
print("bullseyes", len(bulls), "tries", tries)

# ---------------------------------------------------------------- checks in plan
SOLID = {"block", "bastion", "tower", "tall", "low", "pillar", "block4", "crate", "counter", "truss", "ramp", "mid", "bin", "pad"}
def ov(a, b, pad=0.0):
    return a["x0"] < b["x1"] + pad and b["x0"] < a["x1"] + pad and a["z0"] < b["z1"] + pad and b["z0"] < a["z1"] + pad
errs = []
sol = [i for i in items if i["kind"] in SOLID]
for i, a in enumerate(sol):
    for b in sol[i + 1:]:
        if ov(a, b, -0.01) and a["y0"] < b["y0"] + b["h"] and b["y0"] < a["y0"] + a["h"] and not ({a["kind"], b["kind"]} <= {"truss", "block", "bastion"}) and not (a["kind"] == "ramp" or b["kind"] == "ramp"):
            errs.append(f"overlap {a['kind']} {a.get('id','')} {a['x0'],a['z0'],a['x1'],a['z1']} x {b['kind']} {b.get('id','')} {b['x0'],b['z0'],b['x1'],b['z1']}")
    if a["x0"] < -128 or a["x1"] > 352 or a["z0"] < -128 or a["z1"] > 128: errs.append(f"outside {a}")
for s in spots:
    box = dict(x0=s["x"] - 2.5, x1=s["x"] + 2.5, z0=s["z"] - 2.5, z1=s["z"] + 2.5)
    for b in sol:
        top = b["y0"] + b["h"]
        if ov(box, b) and (s["roof"] < top and s["roof"] + 6 > b["y0"]):
            errs.append(f"spot {s['zone']} ({s['x']},{s['z']}) hits {b['kind']} {b['x0'],b['z0'],b['x1'],b['z1']}")
    if s["roof"]:
        on = [b for b in sol if b["kind"] in ("block", "bastion") and b["x0"] + 2 <= s["x"] <= b["x1"] - 2 and b["z0"] + 2 <= s["z"] <= b["z1"] - 2]
        if not on: errs.append(f"roof spot not on a roof {s}")
for a in arrivals:
    box = dict(x0=a["x"] - 2, x1=a["x"] + 2, z0=a["z"] - 2, z1=a["z"] + 2)
    for b in sol:
        if ov(box, b): errs.append(f"arrival {a} hits {b['kind']}")
print("items", len(items), "spots", len(spots), "arrivals", len(arrivals), "signs", len(signs), "lights", len(lights))
from collections import Counter; print(Counter(i["kind"] for i in items))
for e in errs: print("ERR", e)

# ---------------------------------------------------------------- Lua data
def lua(v):
    if isinstance(v, dict): return "{" + ", ".join(f"{k}={lua(x)}" for k, x in v.items() if x is not None) + "}"
    if isinstance(v, (list, tuple)): return "{" + ", ".join(lua(x) for x in v) + "}"
    if isinstance(v, str): return json.dumps(v)
    if isinstance(v, bool): return "true" if v else "false"
    if isinstance(v, float): return ("%.3f" % v).rstrip("0").rstrip(".")
    return str(v)
body = ("local LAYOUT = {\n" + ",\n".join("\t" + lua(i) for i in items) + "\n}\n"
        "local SPOTS = {\n" + ",\n".join("\t" + lua(s) for s in spots) + "\n}\n"
        "local ARRIVALS = " + lua(arrivals) + "\n"
        "local SIGNS = {\n" + ",\n".join("\t" + lua(s) for s in signs) + "\n}\n"
        "local LIGHTS = " + lua(lights) + "\n"
        "local EXTRAS = {\n"
        "\tpads = " + lua([dict(x=a, z=b, y=c, lx=d, ly=e, lz=f) for a, b, c, d, e, f in PADS]) + ",\n"
        "\tropes = " + lua([dict(x0=a, z0=b, x1=c, z1=d, y=e) for a, b, c, d, e in ROPES]) + ",\n"
        "\tbins = " + lua([dict(x=a, z=b, y=c) for a, b, c in BINS]) + ",\n"
        "\tdps = " + lua([dict(x=a, z=b, face=c) for a, b, c in DPS]) + ",\n"
        "\tbulls = " + lua(bulls) + ",\n}\n")
os.makedirs("out/training", exist_ok=True)
open("fix/training_layout.lua", "w", encoding="utf-8").write("-- generated by tools/training_layout.py; do not edit by hand\n" + body)
p = "fix/place_training.lua"
if os.path.exists(p):
    s = open(p, encoding="utf-8").read()
    s2 = re.sub(r"(--@LAYOUT_BEGIN\n).*?(--@LAYOUT_END)", lambda m: m.group(1) + body + m.group(2), s, flags=re.S)
    open(p, "w", encoding="utf-8").write(s2); print("layout pasted into", p, s != s2)

# ---------------------------------------------------------------- plan png
try:
    from PIL import Image, ImageDraw
    S, OX, OZ = 2.4, 140, 140
    img = Image.new("RGB", (int(500 * S), int(290 * S)), (24, 26, 24)); dr = ImageDraw.Draw(img)
    P = lambda x, z: (int((x + OX) * S), int((OZ - z) * S))
    col = {"floor": (200, 196, 186), "gfloor": (175, 180, 160), "wall": (40, 40, 40), "ceiling": None, "plaza": (138, 156, 74),
           "block": (120, 126, 110), "bastion": (90, 96, 80), "tower": (50, 54, 46), "tall": (100, 100, 96), "low": (150, 150, 146),
           "pillar": (90, 90, 88), "block4": (140, 140, 136), "crate": (65, 94, 56), "bridge": (170, 160, 120), "ramp": (230, 220, 180),
           "truss": (250, 250, 250), "line": (138, 156, 74), "counter": (110, 110, 100), "mid": (130, 130, 126), "pad": (138, 156, 74), "bin": (200, 120, 40)}
    order = ["floor", "gfloor", "plaza", "line", "wall", "block", "bastion", "bridge", "ramp", "truss", "tower", "tall", "low", "pillar", "block4", "crate", "counter", "mid", "pad", "bin"]
    for k in order:
        for i in items:
            if i["kind"] == k and col.get(k):
                a, b = P(i["x0"], i["z1"]), P(i["x1"], i["z0"]); dr.rectangle([a, b], fill=col[k], outline=(0, 0, 0) if k not in ("floor", "gfloor", "line") else None)
    for s in spots:
        c = (255, 120, 90) if s["roof"] else (200, 40, 40); x, y = P(s["x"], s["z"]); dr.ellipse([x - 5, y - 5, x + 5, y + 5], fill=c, outline=(0, 0, 0))
    for a in arrivals:
        x, y = P(a["x"], a["z"]); dr.polygon([(x, y - 4), (x - 4, y + 3), (x + 4, y + 3)], fill=(255, 255, 255))
    for b in bulls:
        x, y = P(b["x"], b["z"]); dr.ellipse([x - 2, y - 2, x + 2, y + 2], outline=(255, 80, 80))
    for a, b2, c, d, yy in ROPES: dr.line([P(a, b2), P(c, d)], fill=(255, 255, 0), width=2)
    for a, b2, *_ in DPS:
        x, y = P(a, b2); dr.rectangle([x - 4, y - 4, x + 4, y + 4], fill=(107, 122, 58), outline=(255, 255, 255))
    for l in lights:
        x, y = P(l["x"], l["z"]); dr.rectangle([x - 3, y - 3, x + 3, y + 3], outline=(255, 230, 120))
    dr.text((10, 10), "Training v2 build layout (tools/training_layout.py): red = floor spot, salmon = roof spot (+24), white = truss/ramp, yellow squares = lights", fill=(230, 230, 220))
    img.save("out/training/layout_plan.png"); print("plan out/training/layout_plan.png")
except ImportError:
    print("no PIL: plan skipped")
sys.exit(1 if errs else 0)

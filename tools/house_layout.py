"""House: a two-storey modern suburban house duel map (Tacticals), layout and feel inspired by a classic suburban test-site
shooter map; own models and wording. Generated as data. PLAN ONLY: nothing here touches a place.

    python -I tools/house_layout.py     -> notes/maps/house_layout.json
    python -I tools/house_check.py      -> notes/maps/house_checks.json / .txt + _house_cache.npz
    python -I tools/house_plot.py       -> notes/maps/house_plan.png (+ house_plan_upper.png, house_exposure.png)

Plan coordinates, in studs: x east, y north (the street and the front door are south, the backyard north), z up; ground
floor top = 0, upper floor top = 14. To build: world = ORIGIN + (x, z, -y) (plan north = world -Z, as the Arena).

Every collision part is an axis-aligned box, a ramp (stairs) or a door leaf (a box turned about its hinge). The modeler's
meshes are art only (CanCollide off); the builder makes one invisible COLP_<id> proxy per collision part below.
Cover roles (the game's own heights): low = 3.4 (crouch, vault), tall = 7+ (peek the edges), step = <= 1.6 (walked over,
NotCover), wall / floor / stair / rail / door = NotCover. Barriers are player-only (CanCollide on, CanQuery off: bullets,
cover rays and cameras pass), in every window opening, along the gallery and the main stair's open side.
"""
import json, math, os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(HERE), "notes", "maps", "house_layout.json")

# ------------------------------------------------------------------------------------------------ fixed numbers
XI, YI = 40.0, 30.0             # inside faces of the outer walls: x -40..40, y -30..30 (80 x 60)
T_EXT, T_INT = 1.0, 1.0         # wall thickness (exterior outside the inside face, interior centred on its line)
G0, GC = 0.0, 13.0              # ground floor top, ground ceiling (slab underside)
U0, UC = 14.0, 26.0             # upper floor top, upper ceiling
LOW, TALL, STEP = 3.4, 8.0, 1.5
DOOR_H, FRONT_H = 9.0, 10.0     # interior door / front + back door opening heights
WIN = dict(G=(3.0, 10.0), U=(17.0, 24.0))      # window sill / head (z) per storey
AJAR_DEG = 70.0                 # every interior room door held open this far (passable: ~3.9 clear in a 6-wide frame)

parts = []      # collision parts (become COLP_<id>)
rooms = []
openings = []   # doors, archways, pass-throughs, windows (for the art + the barriers)
doors = []
furniture = []
art_only = []   # visible-only notes for the modeler (e.g. railing balusters), no collision
notes = []


def box(pid, x0, x1, y0, y1, z0, z1, role, cover="none", **kw):
    assert x1 > x0 and y1 > y0 and z1 > z0, pid
    p = dict(id=pid, shape="box", x0=round(x0, 3), x1=round(x1, 3), y0=round(y0, 3), y1=round(y1, 3),
             z0=round(z0, 3), z1=round(z1, 3), role=role, cover=cover)
    p.update(kw)
    parts.append(p)
    return p


def room(rid, name, storey, rects, job, feel, ceiling):
    rooms.append(dict(id=rid, name=name, storey=storey, rects=[dict(x0=a, x1=b, y0=c, y1=d) for a, b, c, d in rects],
                      job=job, feel=feel, ceiling=ceiling))


# ------------------------------------------------------------------------------------------------ walls with openings
def wall(wid, axis, line, a, b, z0, z1, ops=(), ext=None, room_sides=None):
    """axis 'x' = the wall runs along x at y = line; 'y' = runs along y at x = line.
    ext: None = centred interior wall; '+' / '-' = exterior wall lying on the + / - side of the line (outside).
    ops: list of dicts (id, kind, a, b, z0, z1, ...) cut out of [a, b] x [z0, z1]."""
    if ext is None:
        t0, t1 = line - T_INT / 2, line + T_INT / 2
    elif ext == "+":
        t0, t1 = line, line + T_EXT
    else:
        t0, t1 = line - T_EXT, line
    ops = sorted(ops, key=lambda o: o["a"])

    def mk(pid, s0, s1, zz0, zz1, role="wall"):
        if s1 - s0 < 1e-6 or zz1 - zz0 < 1e-6:
            return
        if axis == "x":
            box(pid, s0, s1, t0, t1, zz0, zz1, role, wall=wid)
        else:
            box(pid, t0, t1, s0, s1, zz0, zz1, role, wall=wid)

    # 2D cut: split the run at every opening edge; in each segment keep the z intervals no opening covers
    for o in ops:
        assert a - 1e-6 <= o["a"] < o["b"] <= b + 1e-6, (wid, o["id"])
        rec = dict(o)
        rec.update(wall=wid, axis=axis, line=line, t0=t0, t1=t1)
        openings.append(rec)
    cuts = sorted(set([a, b] + [o["a"] for o in ops] + [o["b"] for o in ops]))
    k = 0
    for s0, s1 in zip(cuts[:-1], cuts[1:]):
        here = sorted([o for o in ops if o["a"] < s1 - 1e-6 and o["b"] > s0 + 1e-6], key=lambda o: o["z0"])
        z = z0
        tag = "_".join(o["id"] for o in here)
        for o in here:
            if o["z0"] > z + 1e-6:
                k += 1
                role = "sill" if (o["kind"] in ("window", "pass") and abs(o["z0"] - (z0 if z == z0 else z)) >= 0 and o["z0"] - z < 6) else "wall"
                mk(f"{wid}_{k}" + (f"_{o['id']}_Below" if tag else ""), s0, s1, z, o["z0"], role)
            z = max(z, o["z1"])
        if z1 > z + 1e-6:
            k += 1
            mk(f"{wid}_{k}" + ("_Above" if tag else ""), s0, s1, z, z1)


def W(oid, a, b, storey="G", kind="window", **kw):
    z0, z1 = WIN[storey]
    d = dict(id=oid, kind=kind, a=a, b=b, z0=kw.pop("z0", z0), z1=kw.pop("z1", z1), storey=storey)
    d.update(kw)
    return d


def D(oid, a, b, z0, h, kind="door", **kw):
    d = dict(id=oid, kind=kind, a=a, b=b, z0=z0, z1=z0 + h)
    d.update(kw)
    return d


# ---- floors, slab, roof (the slab is cut for the two stair voids)
box("Floor_G", -XI - T_EXT, XI + T_EXT, -YI - T_EXT, YI + T_EXT, -1, G0, "floor")
box("Slab_W", -XI, -9.5, -YI, YI, GC, U0, "floor")                 # under MB / BR3 (to the x=-9 wall's west face)
box("Slab_LD", -9.5, 9.5, -4, 4, GC, U0, "floor")                  # the landing (over the cross hall)
box("Slab_UH", -9.5, 3.0, 4, YI, GC, U0, "floor")                  # upper hall + bathroom
box("Slab_ST2End", 3.0, 9.5, 23, YI, GC, U0, "floor")              # over the back stair's foot (bathroom alcove)
box("Slab_E", 9.5, XI, -YI, YI, GC, U0, "floor")                   # BR2 floor + the kitchen's flat roof
box("Ceiling_U", -XI, XI, -YI, 4.5, UC, UC + 1, "ceiling")          # upper storey ceiling (pitched roof art above)
box("Ceiling_UBack", -XI, 9.5, 4.5, YI, UC, UC + 1, "ceiling")

# ---- exterior walls (outside the inside faces)
wall("W_S_G", "x", -YI, -XI - T_EXT, XI + T_EXT, G0, GC, ext="-", ops=[
    W("Win_LR_S1", -36, -28), W("Win_LR_S2", -22, -14),
    D("Door_Front", 0, 6, G0, FRONT_H),
    W("Win_DR_S1", 14, 22), W("Win_DR_S2", 28, 36),
])
wall("W_S_U", "x", -YI, -XI - T_EXT, XI + T_EXT, GC, UC + 1, ext="-", ops=[
    W("Win_EN_S", -37, -32, "U", z0=19, z1=23, frosted=True),
    W("Win_MB_S", -24, -14, "U"),
    W("Win_FY_S", -3, 7, "U", z0=GC + 1, z1=UC - 1.5, feature=True),     # tall feature window over the front door
    W("Win_BR2_S1", 16, 24, "U"), W("Win_BR2_S2", 30, 36, "U"),
])
wall("W_N_G", "x", YI, -XI - T_EXT, XI + T_EXT, G0, GC, ext="+", ops=[
    W("Win_GB_N", -36, -30, z0=6, z1=10, frosted=True),
    W("Win_BH_N", -20, -14),
    D("Door_Back", -6, 0, G0, FRONT_H),
    W("Win_KT_N1", 14, 22, z0=4.5), W("Win_KT_N2", 26, 34, z0=4.5),
])
wall("W_N_U", "x", YI, -XI - T_EXT, 9.5, GC, UC + 1, ext="+", ops=[
    W("Win_BR3_N1", -34, -26, "U"), W("Win_BR3_N2", -20, -14, "U"),
    W("Win_UB_N", -6, 0, "U", z0=19, frosted=True),
])
wall("W_W", "y", -XI, -YI, YI, G0, UC + 1, ext="-", ops=[
    W("Win_EN_W", -27, -23, "U", z0=19, z1=23, frosted=True),
    W("Win_LR_W", -6, 2),
    W("Win_BR3_W", 10, 18, "U"),
    W("Win_GB_W", 18, 24, z0=6, z1=10, frosted=True),
])
# the west wall carries windows on both storeys: the op list is sorted along y, so ground and upper cuts must not overlap
# along y (they don't). Their z ranges come from each op.
wall("W_E_G", "y", XI, -YI, YI, G0, GC, ext="+", ops=[
    W("Win_DR_E", -26, -18),
    W("Win_KT_E", 6, 18, z0=4.5),
])
wall("W_E_U", "y", XI, -YI, 4.5, GC, UC + 1, ext="+", ops=[
    W("Win_BR2_E", -24, -16, "U"),
])
# upper walls facing the kitchen's flat roof (outside): BR2's north wall and the stairwell / bathroom east wall
wall("W_U4", "x", 4, 9.5, XI, U0, UC, ops=[W("Win_BR2_N", 20, 30, "U")])
# ---- interior lines
# x = -9: living room / foyer + stair (double height up to the foyer void); upper: master / landing / BR3 / upper hall
wall("I_X-9_FY", "y", -9, -YI, -4, G0, UC, ops=[
    D("Arch_LR_FY", -29.5, -23.5, G0, 10, kind="arch"),
    W("Win_MB_FY", -20, -12, "U", interior=True, note="master bedroom gallery window onto the foyer void (breakable)"),
])
wall("I_X-9_G", "y", -9, -4, 10, G0, GC, ops=[D("Arch_LR_CH", -3.5, 3.5, G0, 10, kind="arch")])
wall("I_X-9_U", "y", -9, -4, YI, U0, UC, ops=[
    D("Door_MB", -3.5, 2.5, U0, DOOR_H),
    D("Door_BR3", 9, 14, U0, DOOR_H),
])
# x = 9: foyer / dining (double height); kitchen; upper: BR2 door, stairwell + bathroom face the flat roof (exterior)
wall("I_X9_FY", "y", 9, -YI, -4, G0, UC, ops=[
    D("Arch_DR_FY", -22, -12, G0, 10, kind="arch"),
    W("Win_BR2_FY", -28, -20, "U", interior=True, note="bedroom 2 gallery window onto the foyer void (breakable)"),
])
wall("I_X9_G", "y", 9, -4, YI, G0, GC, ops=[
    D("Arch_KT_CH", -3.5, 3.5, G0, 10, kind="arch"),
    D("Arch_KT_BH", 23.5, 29.5, G0, 10, kind="arch"),
])
wall("I_X9_U", "y", 9, -4, YI, U0, UC, ops=[
    D("Door_BR2", -2.5, 3.5, U0, DOOR_H),
    W("Win_ST2_E", 10, 18, "U", z0=18),
    W("Win_UB_E", 24.5, 28.5, "U", z0=19, frosted=True),
])
# kitchen / dining: an archway and a counter pass-through (sill 3.4 = low cover, vault and shoot through)
wall("I_Y-10_G", "x", -10, 9.5, XI, G0, GC, ops=[
    D("Arch_KT_DR", 14, 20.5, G0, 10, kind="arch"),
    dict(id="Pass_KT_DR", kind="pass", a=26.5, b=31, z0=LOW, z1=8.5),
])
wall("I_Y10_G", "x", 10, -XI, -9.5, G0, GC, ops=[
    D("Arch_LR_BH", -20.5, -14, G0, 10, kind="arch"),
])
# mudroom / back hall: separated from the stair hall by a wall with an archway (mirror of the dining room's arch to the foyer)
wall("I_X-9_BH", "y", -9, 10.5, YI, G0, GC, ops=[D("Arch_MR_BH", 12, 22, G0, 10, kind="arch")])
wall("I_X-24_G", "y", -24, 10.5, YI, G0, GC, ops=[D("Door_GB", 21, 26, G0, DOOR_H)])
# back stair: open to the back hall on its west side (banister, as the main stair to the foyer); walled upstairs
wall("I_X3.5", "y", 3.5, 4, 23, U0, UC)
wall("I_Y23_U", "x", 23, 4, 8.5, U0, UC)                               # stairwell's north end upstairs (bathroom alcove side)
# upper: master / BR3, the ensuite, the bathroom
wall("I_Y4_U", "x", 4, -XI, -9.5, U0, UC)
wall("I_X-28_U", "y", -28, -YI, -19.5, U0, UC)
wall("I_Y-19_U", "x", -19, -XI, -27.5, U0, UC, ops=[D("Door_EN", -35.5, -30.5, U0, DOOR_H)])
wall("I_Y17_U", "x", 17, -8.5, 3.0, U0, UC, ops=[D("Door_UB", -7, -2, U0, DOOR_H)])

# ---- window barriers: invisible, player-only, filling each window opening (the frame + glass are art / systems)
for o in list(openings):
    if o["kind"] != "window": continue
    if o["axis"] == "x":
        box("Bar_" + o["id"], o["a"], o["b"], o["t0"], o["t1"], o["z0"], o["z1"], "barrier", window=o["id"])
    else:
        box("Bar_" + o["id"], o["t0"], o["t1"], o["a"], o["b"], o["z0"], o["z1"], "barrier", window=o["id"])

# ---- stairs: a ramp proxy over a solid under-stair block (the art is the modeler's stepped mesh)
STAIRS = [
    dict(id="Stair_Main", x0=-8.5, x1=-3.5, foot_y=-23.0, top_y=-4.0, z0=G0, z1=U0, rises="north",
         note="near the front door; at the top: railing on the RIGHT (gallery), door on the LEFT (master bedroom)"),
    dict(id="Stair_Back", x0=4.0, x1=8.5, foot_y=23.0, top_y=4.0, z0=G0, z1=U0, rises="south",
         note="enclosed service stair, back hall -> landing; makes the loop (LAYOUT DECISION, see house_plan.md)"),
]
for s in STAIRS:
    y0, y1 = sorted((s["foot_y"], s["top_y"]))
    run = abs(s["top_y"] - s["foot_y"]); rise = s["z1"] - s["z0"]
    s.update(run=run, rise=rise, slope_deg=round(math.degrees(math.atan2(rise, run)), 1), width=s["x1"] - s["x0"],
             steps=16, step_rise=round(rise / 16, 4), step_run=round(run / 16, 4))
    parts.append(dict(id=s["id"] + "_Ramp", shape="ramp", x0=s["x0"], x1=s["x1"], y0=y0, y1=y1, z0=s["z0"], z1=s["z1"],
                      foot_y=s["foot_y"], top_y=s["top_y"], role="stair", cover="none"))

# ---- railings: handrail (solid, thin, NotCover) + a player-only barrier to the ceiling (bullets pass between balusters)
def railing(rid, x0, x1, y0, y1, zbase, sloped=None):
    art_only.append(dict(id=rid, kind="Railing", x0=x0, x1=x1, y0=y0, y1=y1, z=zbase, height=3.5, sloped=sloped,
                         note="balusters 0.25 sq every 1.2, handrail 0.35 x 0.25 at 3.5; see-through"))
    if sloped is None:
        box(rid + "_Rail", x0, x1, y0, y1, zbase + 3.25, zbase + 3.6, "rail")
    box(rid + "_Barrier", x0, x1, y0, y1, G0 if sloped else zbase, UC, "barrier")

railing("Rail_Gallery", -3.5, 8.5, -4.15, -3.85, U0)                       # along the void's north edge
railing("Rail_MainStair", -3.55, -3.35, -23.0, -4.15, G0, sloped="Stair_Main")   # the main stair's open (east) side
railing("Rail_BackStair", 3.85, 4.05, 4.15, 23.0, G0, sloped="Stair_Back")       # the back stair's open (west) side

# ------------------------------------------------------------------------------------------------ rooms
room("FY", "Foyer", "G", [(-9, 9, -30, -4)], "arrive; the double-height hall the gallery looks down on",
     "bright, tall, exposed: daylight from the feature window", "double height (26)")
room("CH", "Cross hall", "G", [(-9, 9, -4, 4)], "link living room, foyer, kitchen", "low and dim under the landing", 13)
room("BH", "Back hall", "G", [(-9, 3.5, 4, 30), (3.5, 9, 23, 30)], "back door, foot of the back stair",
     "narrow, cluttered, coat cabinets", 13)
room("LR", "Living room", "G", [(-40, -9, -30, 10)], "team A's spawn behind the shelf wall; sofa ambush on the stair foot",
     "warm, soft, lived-in", 13)
room("MR", "Mudroom", "G", [(-24, -9, 10, 30)], "coat lockers, bench; between the living room and the back hall", "cluttered", 13)
room("GB", "Bathroom (ground)", "G", [(-40, -24, 10, 30)], "side pocket off the back hall", "tiled, cool, quiet", 13)
room("DR", "Dining room", "G", [(9, 40, -30, -10)], "open to the foyer; the long table", "formal, bright windows", 13)
room("KT", "Kitchen", "G", [(9, 40, -10, 30)], "team B's spawn behind the oven wall; island + pass-through to the dining room",
     "clean modern kitchen, skylit flat roof", 13)
room("LD", "Landing", "U", [(-9, 9, -4, 4)], "the top of both stairs; gallery peek through the banisters",
     "the hinge of the map: exposed, overlooks the foyer", 12)
room("UH", "Upper hall", "U", [(-9, 3.5, 4, 17)], "to the kids' bedroom and the bathroom; bookcase ambush", "narrow", 12)
room("MB", "Master bedroom", "U", [(-40, -9, -30, 4)], "contested: first door at the top of the main stair", "calm, big bed, wardrobes", 12)
room("EN", "Master bathroom (ensuite)", "U", [(-40, -28, -30, -19)], "door held CLOSED (not playable yet)", "", 12)
room("BR2", "Bedroom 2", "U", [(9, 40, -30, 4)], "front-east bedroom: guest room with a desk", "plain, tidy", 12)
room("BR3", "Bedroom 3", "U", [(-40, -9, 4, 30)], "back-west bedroom: teen room with a bunk bed", "busy, posters", 12)
room("UB", "Bathroom (upper)", "U", [(-9, 3.5, 17, 30), (3.5, 9, 23, 30)], "family bathroom", "tiled, bright", 12)

# ------------------------------------------------------------------------------------------------ doors (real hinged doors)
# hinge = the end of the opening the leaf turns on; swing = the side of the wall the leaf opens into (+ / - along the
# wall's normal axis); state Ajar (held AJAR_DEG open, anchored, no prompt), Closed (in the frame), Locked (closed + locked
# during a duel). Attributes for the builder: OpenCF / ClosedCF (pivot CFrames), DoorState, Locked, OpenDeg.
def door(did, hinge, swing, state, model, locked=False, width=None):
    o = next(o for o in openings if o["id"] == did)
    o["door"] = dict(hinge=hinge, swing=swing, state=state, locked=locked, model=model)
    w = o["b"] - o["a"]
    leaf_w, leaf_t, leaf_h = w - 0.2, 0.25, o["z1"] - o["z0"] - 0.1
    line = o["line"]
    face = (o["t1"] if swing == "+" else o["t0"])            # leaf hangs at the wall face on the swing side
    face += (-leaf_t / 2 if swing == "+" else leaf_t / 2)
    hs = o["a"] + 0.1 if hinge == "a" else o["b"] - 0.1      # hinge position along the wall
    dirs = 1 if hinge == "a" else -1                         # closed leaf runs from the hinge this way along the wall
    ang = {"Ajar": AJAR_DEG, "Closed": 0.0, "Locked": 0.0}[state]
    # in plan: along = wall axis unit, normal = + side unit
    if o["axis"] == "x":
        hx, hy = hs, face; ax, ay = 1.0, 0.0; nx, ny = 0.0, 1.0
    else:
        hx, hy = face, hs; ax, ay = 0.0, 1.0; nx, ny = 1.0, 0.0
    sgn = 1 if swing == "+" else -1
    a = math.radians(ang)
    # leaf direction from the hinge: closed = dirs*along; opening rotates it toward sgn*normal
    ux = dirs * ax * math.cos(a) + sgn * nx * math.sin(a)
    uy = dirs * ay * math.cos(a) + sgn * ny * math.sin(a)
    cx, cy = hx + ux * leaf_w / 2, hy + uy * leaf_w / 2
    yaw = math.degrees(math.atan2(uy, ux))
    rec = dict(id=did, kind="HingedDoor", model=model, state=state, locked=locked, hinge=[round(hx, 3), round(hy, 3)],
               leaf=dict(w=round(leaf_w, 3), t=leaf_t, h=round(leaf_h, 3)), z0=o["z0"], open_deg=AJAR_DEG,
               closed_dir=[dirs * ax, dirs * ay], open_dir_side=[sgn * nx, sgn * ny], angle_deg=ang,
               centre=[round(cx, 3), round(cy, 3)], leaf_yaw_deg=round(yaw, 2), opening=[o["a"], o["b"]], wall=o["wall"])
    doors.append(rec)
    parts.append(dict(id=did + "_Leaf", shape="obox", cx=round(cx, 3), cy=round(cy, 3), w=round(leaf_w, 3), d=leaf_t,
                      z0=o["z0"], z1=round(o["z0"] + leaf_h, 3), yaw=round(yaw, 3), role="door", cover="none"))

door("Door_Front", "a", "+", "Locked", "FrontDoor", locked=True)
door("Door_Back", "b", "-", "Locked", "BackDoor", locked=True)
door("Door_GB", "b", "-", "Ajar", "InteriorDoor")
door("Door_MB", "b", "-", "Ajar", "InteriorDoor")
door("Door_BR2", "a", "+", "Ajar", "InteriorDoor")
door("Door_BR3", "b", "-", "Ajar", "InteriorDoor")
door("Door_UB", "a", "+", "Ajar", "InteriorDoor")
door("Door_EN", "b", "-", "Closed", "InteriorDoor")


# ------------------------------------------------------------------------------------------------ furniture (cover)
_FJ = json.load(open(os.path.join(os.path.dirname(HERE), "art", "house", "house_furniture.json")))
MULTI = {a["assembly"]: a["collision_boxes_studio"] for a in _FJ["assemblies"]
         if len(a.get("collision_boxes_studio") or []) > 1}


def F(fid, rm, model, cover, x0, x1, y0, y1, z0=None, h=None, face=None, note=""):
    st = next(r for r in rooms if r["id"] == rm)["storey"]
    zb = (G0 if st == "G" else U0) if z0 is None else z0
    hh = h if h is not None else {"low": LOW, "tall": TALL, "step": STEP}[cover]
    furniture.append(dict(id=fid, room=rm, model=model, cover=cover, x0=x0, x1=x1, y0=y0, y1=y1, z0=zb, z1=zb + hh,
                          face=face, note=note))
    multi = MULTI.get(model)
    if not multi:
        box("F_" + fid, x0, x1, y0, y1, zb, zb + hh, "furniture", cover=cover, room=rm, model=model)
        return
    # the modeler's accurate collision boxes (sofa back + chaise, bed headboard + body, table + chair rows): one box over the
    # whole piece gave invisible cover above the seat / mattress / table top. 3.4 boxes are low cover; lower ones are NotCover.
    fc = face or ("S" if (x1 - x0) >= (y1 - y0) else "E")
    copies = [((x0 + x1) / 2, (y0 + y1) / 2)]
    if model == "H_DiningSet":   # two sets end to end along the long side
        copies = [(x0 + (x1 - x0) * 0.25, (y0 + y1) / 2), (x0 + (x1 - x0) * 0.75, (y0 + y1) / 2)]
    k = 0
    for (cx, cy) in copies:
        for b in multi:
            (sx, sy, sz), (ox, oy, oz) = b["size"], b["centre_rel_pivot"]
            if fc == "N": dx, dy, ex, ey = ox, -oz, sx, sz
            elif fc == "S": dx, dy, ex, ey = -ox, oz, sx, sz
            elif fc == "E": dx, dy, ex, ey = -oz, -ox, sz, sx
            else: dx, dy, ex, ey = oz, ox, sz, sx
            k += 1
            c = "low" if abs(sy - LOW) < 0.05 else "none"
            box(f"F_{fid}_{k}", cx + dx - ex / 2, cx + dx + ex / 2, cy + dy - ey / 2, cy + dy + ey / 2, zb, zb + sy, "furniture",
                cover=c, room=rm, model=model)


# Sizes = the modeler's meshes (art/house/house_furniture.json, size_studio [w, h, d]) where one exists; "custom" = in the kit
# list for the modeler (briefs/kit-house.json). Plan boxes: the mesh footprint turned to its facing.
# Living room (x -40..-9, y -30..10): close to the kitchen turned 180 degrees about the centre (fair spawns)
F("LR_ShelfWall", "LR", "H_ShelfWall", "tall", -28, -26, -25, -13, note="custom: tall open bookshelf wall, both faces dressed: team A's spawn wall")
F("LR_ChairA", "LR", "H_Armchair", "low", -29.2, -25, -9, -5, face="N", note="pair of armchairs facing the fireplace wall side (mirror of the island)")
F("LR_ChairB", "LR", "H_Armchair", "low", -23, -18.8, -9, -5, face="N")
F("LR_SofaStair", "LR", "H_Sofa_Sectional", "low", -21.2, -14, -27, -15, face="W", note="turned: its back faces the foyer arch and the stair foot: the ambush sofa")
F("LR_Media", "LR", "H_TVConsole", "low", -33, -25, -29.5, -27.48, face="N", note="console only: the TV stood in front of the south window (grade round 4)")
F("LR_Bookcase1", "LR", "H_Bookcase", "tall", -11.1, -9.5, -22, -16, face="W")
F("LR_Bookcase2", "LR", "H_Bookcase", "tall", -11.1, -9.5, -16, -10, face="W")
F("LR_Chair", "LR", "H_Armchair", "low", -39.5, -35.5, -4.2, 0, face="E")
F("LR_Sideboard", "LR", "H_Dresser", "low", -38, -32, 7.2, 9.5, face="S", note="beside the half-wall opening, not under it")
F("LR_Screen", "LR", "H_SlatScreen", "tall", -17, -15, -4, 2, note="custom: tall timber slat screen inside the hall arch: breaks the long axis")
# Dining room (x 9..40, y -30..-10)
F("DR_Table", "DR", "H_DiningSet", "low", 17, 33, -22.3, -15.63, note="two dining sets end to end (one 16-long table, 12 chairs)")
F("DR_Cabinet", "DR", "H_Bookcase", "tall", 37.9, 39.5, -17, -11, face="W", note="as a china cabinet (glass-front variant welcome)")
F("DR_Sideboard", "DR", "H_TVConsole", "low", 10, 12.02, -29.5, -21.5, face="E", note="used as a sideboard")
# Kitchen (x 9..40, y -10..30)
F("KT_Island", "KT", "H_KitchenIsland", "low", 19, 29, 5, 9.68, face="S", note="seating side south (the stools mirror the living room coffee table)")
F("KT_CounterN", "KT", "KitchenRun6", "low", 12, 36, 27.04, 29.5, face="S", note="6 modules of 4: H_KitchenBase / H_KitchenSink / H_KitchenHob; uppers + hood above as dressing")
F("KT_Fridge", "KT", "H_Fridge", "tall", 9.5, 12.355, 18, 21.6, face="E")
F("KT_Pantry", "KT", "H_Pantry", "tall", 9.5, 11.96, 14, 18, face="E")
F("KT_CounterE", "KT", "KitchenRun1", "low", 37.04, 39.5, 1, 5, face="W", note="1 module (H_KitchenBase)")
F("KT_CounterPT", "KT", "KitchenRun1", "low", 32, 36, -9.5, -7.04, face="N", note="beside the pass-through, not under it (a counter under it made the vault land on the counter)")
F("KT_Screen", "KT", "H_SlatScreen", "tall", 15, 17, -2, 4, note="custom: tall timber slat screen inside the hall arch (mirror)")
F("KT_TallUnit", "KT", "H_OvenWall", "tall", 26, 28, 13, 25, note="custom: tall oven + pantry bank, both faces finished: team B's spawn wall")
F("KT_Bench", "KT", "H_KitchenBench", "low", 16.5, 20, 16, 26, face="E", note="custom: banquette (mirror of the ambush sofa)")
# Foyer, cross hall, back hall, ground bathroom
F("CH_Column", "CH", "H_DisplayColumn", "tall", -1.5, 1.5, -1.5, 1.5, note="custom: structural column wrapped in a display niche")
F("FY_Planter", "FY", "H_Planter", "low", 3, 6, -16, -13, note="custom: low planter box (cover 3.4) + H_PlantFiddle in it as art")
F("FY_Console", "FY", "H_Dresser", "low", 6.2, 8.5, -10.5, -4.5, face="W", note="as a hall console")
F("FY_Bench", "FY", "H_HallBench_3", "low", -2, 0, -29.5, -26, face="E", note="custom: beside the front door")
F("MR_Lockers", "MR", "H_Wardrobe", "tall", -23.5, -21, 11, 17, face="E", note="as coat lockers")
F("MR_Bench", "MR", "H_HallBench_8", "low", -20, -12, 27.5, 29.5, face="S", note="custom")
F("BH_CoatTree", "BH", "H_TallCabinet", "tall", -5, -2, 13, 15.12, note="freestanding coat cabinet")
F("GB_Tub", "GB", "H_Bathtub", "low", -39.5, -32.5, 26, 29.6, note="collision 3.4; the mesh's tap rises to 4.1")
F("GB_Cabinet", "GB", "H_TallCabinet", "tall", -31, -28, 10.5, 12.62)
# Landing, upper hall, bathroom
F("LD_Bookcase", "LD", "H_Bookcase", "tall", -8.5, -2.5, 2.8, 4.4, face="S", note="the bookcase by the landing (0.3 clear of the master bedroom door frame)")
F("UH_Linen", "UH", "H_TallCabinet", "tall", 0.88, 3, 10, 13, face="W")
F("UB_Tub", "UB", "H_Bathtub", "low", -8.5, -1.5, 26, 29.6)
# Master bedroom
F("MB_HeadWall", "MB", "H_HeadboardWall", "tall", -24.5, -23, -18, -4, note="custom: freestanding upholstered headboard wall, 8 tall")
F("MB_Bed", "MB", "H_Bed_Double", "low", -23, -13, -14.85, -7.15, face="E", note="head against the head wall")
F("MB_Wardrobe1", "MB", "H_Wardrobe", "tall", -39.5, -37, -16, -10, face="E")
F("MB_Wardrobe2", "MB", "H_Wardrobe", "tall", -39.5, -37, -5, 1, face="E")
F("MB_Dresser", "MB", "H_Dresser", "low", -32, -26, 1.2, 3.5, face="S")
F("MB_Chair", "MB", "H_Armchair", "low", -17, -12.8, -29, -25, face="N")
# Bedroom 2 (x 9..40, y -30..4)
F("BR2_Bed", "BR2", "H_Bed_Double", "low", 29.5, 39.5, -13.85, -6.15, face="W")
F("BR2_Wardrobe", "BR2", "H_Wardrobe", "tall", 9.5, 12, -16, -10, face="E")
F("BR2_Bookcase", "BR2", "H_Bookcase", "tall", 20, 21.6, -21, -15, face="E", note="freestanding")
F("BR2_Dresser", "BR2", "H_Dresser", "low", 31, 37, 1.2, 3.5, face="S", note="beside the north window, not under it (its top rose into the opening)")
# Bedroom 3 (x -40..-9, y 4..30)
F("BR3_Bed", "BR3", "H_Bed_Single", "low", -39.5, -34.8, 21.4, 30, face="S", note="head against the north wall")
F("BR3_Wardrobe", "BR3", "H_Wardrobe", "tall", -12, -9.5, 19, 25, face="W")
F("BR3_Dresser", "BR3", "H_Dresser", "low", -32, -26, 4.5, 6.8, face="N")
# Dressing: the modeler's art-only meshes. Placed by bottom centre (x, y, z above the storey floor) and the direction the front
# faces (S = plan -y = the mesh's own front, N, E, W). Floor pieces in walkable space get a blocker (PCOL_<id>: collides, no
# query, NotCover) the size of the mesh's footprint, so nothing is walk-through; wall / counter / ceiling pieces get none.
_FURN = json.load(open(os.path.join(os.path.dirname(HERE), "art", "house", "house_furniture.json")))
MESH = {a["assembly"]: a["size_studio"] for a in _FURN["assemblies"]}
dressing = []


def Dr(did, model, rm, x, y, z=0.0, face="S", blocker=True, hang=False, note=""):
    st = next(r for r in rooms if r["id"] == rm)["storey"]
    zf = (G0 if st == "G" else U0)
    w, h, d = MESH[model]
    fx, fy = (w, d) if face in ("S", "N") else (d, w)
    rec = dict(id=did, model=model, room=rm, x=x, y=y, z=round(zf + z, 3), face=face, size=[w, h, d], hang=hang, note=note,
               box=[round(x - fx / 2, 3), round(x + fx / 2, 3), round(y - fy / 2, 3), round(y + fy / 2, 3)])
    dressing.append(rec)
    if blocker:
        box("PCOL_" + did, x - fx / 2, x + fx / 2, y - fy / 2, y + fy / 2, zf + z, zf + z + h, "blocker", model=model, room=rm)


# living room
Dr("LR_Rug", "H_Rug_Living", "LR", -24, -1, 0.06, "S", blocker=False)
Dr("LR_Coffee", "H_CoffeeTable", "LR", -24, -2.2, 0, "S")
Dr("LR_Lamp1", "H_FloorLamp", "LR", -38.5, -8, 0, "E")
Dr("LR_Lamp2", "H_FloorLamp", "LR", -12, 8, 0, "S")
Dr("LR_Plant", "H_PlantFiddle", "LR", -38.3, 8.2, 0, "E")
Dr("LR_Side", "H_SideTable", "LR", -12.5, -27.5, 0, "N")
Dr("LR_Art1", "H_Frame_Landscape", "LR", -25, -29.92, 6.0, "N", blocker=False, hang=True)
Dr("LR_Art2", "H_Frame_Abstract", "LR", -39.92, -18, 5.5, "E", blocker=False, hang=True)
# kitchen
Dr("KT_Stool1", "H_BarStool", "KT", 21.5, 3.4, 0, "N")
Dr("KT_Stool2", "H_BarStool", "KT", 24, 3.4, 0, "N")
Dr("KT_Stool3", "H_BarStool", "KT", 26.5, 3.4, 0, "N")
Dr("KT_Bowl", "H_FruitBowl", "KT", 24, 7.3, LOW, "S", blocker=False)
Dr("KT_Coffee", "H_CoffeeMachine", "KT", 35, 28.6, LOW, "S", blocker=False)
Dr("KT_Kettle", "H_Kettle", "KT", 13.5, 28.6, LOW, "S", blocker=False)
Dr("KT_Micro", "H_Microwave", "KT", 38.3, 3.0, LOW, "W", blocker=False)
Dr("KT_Plant", "H_PlantSnake", "KT", 38.5, -8.5, 0, "W")
# dining
Dr("DR_Pend1", "H_PendantLamp", "DR", 21, -18.97, GC - G0, "S", blocker=False, hang=True, note="origin = ceiling point")
Dr("DR_Pend2", "H_PendantLamp", "DR", 29, -18.97, GC - G0, "S", blocker=False, hang=True)
Dr("DR_Art", "H_Frame_Landscape", "DR", 25, -29.92, 6.0, "N", blocker=False, hang=True)
Dr("DR_Plant", "H_PlantFiddle", "DR", 38.3, -28.3, 0, "W")
# foyer, halls, mudroom
Dr("FY_Runner", "H_Rug_Runner", "FY", 3, -21, 0.06, "S", blocker=False)
Dr("FY_Pend", "H_PendantLamp", "FY", 3, -17, UC - G0, "S", blocker=False, hang=True, note="hangs from the double-height ceiling")
Dr("CH_Art", "H_Frame_Botanical", "CH", 0, -1.6, 5.0, "S", blocker=False, hang=True, note="on the display column")
Dr("BH_Washer", "H_WashingMachine", "BH", 1.8, 28.7, 0, "S")
Dr("MR_Art", "H_Frame_Geometric", "MR", -11.5, 29.92, 5.5, "S", blocker=False, hang=True)
# ground bathroom
Dr("GB_Toilet", "H_Toilet", "GB", -38.75, 15, 0, "E")
Dr("GB_Vanity", "H_Vanity", "GB", -35, 11.46, 0.2, "N", note="floating vanity on the west wall (walk blocker: grade round 2)")
Dr("GB_Mirror", "H_Mirror", "GB", -35, 10.6, 3.9, "N", blocker=False, hang=True)
Dr("GB_ShowerGlass", "H_ShowerGlass", "GB", -26.1, 13.6, 0, "N", note="glass screen; player-only blocker (bullets pass)")
Dr("GB_ShowerSet", "H_ShowerSet", "GB", -25.0, 10.6, 4.0, "N", blocker=False, hang=True)
Dr("GB_Towel", "H_TowelRail", "GB", -32, 29.76, 3.8, "S", blocker=False, hang=True)
# upper bathroom
Dr("UB_Toilet", "H_Toilet", "UB", 1.5, 28.75, 0, "S")
Dr("UB_Vanity", "H_Vanity", "UB", -7.54, 21.5, 0.2, "E", note="on the west wall, clear of the door swing (was in the doorway: grade round 2)")
Dr("UB_Mirror", "H_Mirror", "UB", -8.4, 21.5, 3.9, "E", blocker=False, hang=True)
Dr("UB_ShowerGlass", "H_ShowerGlass", "UB", 3.9, 27.9, 0, "E", note="closes the shower alcove from the bathroom (grade round 2: it ran parallel to the stairwell wall)")
Dr("UB_ShowerSet", "H_ShowerSet", "UB", 6.25, 29.7, 4.0, "S", blocker=False, hang=True)
# master bedroom
Dr("MB_Night1", "H_Nightstand", "MB", -21.9, -16.1, 0, "E")
Dr("MB_Night2", "H_Nightstand", "MB", -21.9, -5.9, 0, "E")
Dr("MB_Lamp1", "H_TableLamp", "MB", -21.9, -16.1, 2.0, "E", blocker=False)
Dr("MB_Lamp2", "H_TableLamp", "MB", -21.9, -5.9, 2.0, "E", blocker=False)
Dr("MB_Rug", "H_Rug_Living", "MB", -16, -11, 0.06, "E", blocker=False)
Dr("MB_Art", "H_Frame_Landscape", "MB", -24.6, -11, 3.9, "W", blocker=False, hang=True, note="on the head wall's west face (dressing side), facing west")
Dr("MB_Plant", "H_PlantFiddle", "MB", -10.8, -28.4, 0, "N")
Dr("MB_FloorLamp", "H_FloorLamp", "MB", -26.5, -28.6, 0, "N")
# bedroom 2
Dr("BR2_Night1", "H_Nightstand", "BR2", 38.4, -15.1, 0, "W")
Dr("BR2_Night2", "H_Nightstand", "BR2", 38.4, -4.9, 0, "W")
Dr("BR2_Lamp", "H_TableLamp", "BR2", 38.4, -15.1, 2.0, "W", blocker=False)
Dr("BR2_Desk", "H_Desk", "BR2", 31, -28.28, 0, "N")
Dr("BR2_Chair", "H_DeskChair", "BR2", 31, -25.6, 0, "S")
Dr("BR2_Laptop", "H_Laptop", "BR2", 31, -28.3, 2.62, "N", blocker=False)
Dr("BR2_Art", "H_Frame_Botanical", "BR2", 39.92, -10, 5.4, "W", blocker=False, hang=True)
# bedroom 3
Dr("BR3_Night", "H_Nightstand", "BR3", -33.4, 28.9, 0, "S")
Dr("BR3_Desk", "H_Desk", "BR3", -21, 28.28, 0, "S")
Dr("BR3_Chair", "H_DeskChair", "BR3", -21, 25.6, 0, "N")
Dr("BR3_Blocks", "H_ToyBlocks", "BR3", -28, 16, 0, "S")
Dr("BR3_Ball", "H_ToyBall", "BR3", -30.5, 12, 0, "S")
Dr("BR3_Car", "H_ToyCar", "BR3", -25.5, 13.5, 0, "E", blocker=False)
Dr("BR3_Teddy", "H_Teddy", "BR3", -37.2, 25, 2.4, "S", blocker=False, note="on the bed")
Dr("BR3_Art", "H_Frame_Geometric", "BR3", -39.92, 22, 5.6, "E", blocker=False, hang=True)

# ------------------------------------------------------------------------------------------------ spawns
# One marker per team; teammates stand 4 apart along the marker's right vector (slots 0, -4, +4), as every Tacticals map.
SPAWNS = {
    "A": dict(x=-34, y=-19, z=G0, look=[0, 1], room="LR", note="living room, west end behind the shelf wall, facing up the room (north; Edward 2026-10-28: face into the room)"),
    "B": dict(x=34, y=19, z=G0, look=[0, -1], room="KT", note="kitchen, east end behind the oven wall, facing down the room (south; Edward 2026-10-28)"),
}
SPACING = 4.0
for t, s in SPAWNS.items():
    lx, ly = s["look"]; rx, ry = ly, -lx           # right vector in plan (x east, y north): look (1,0) -> right (0,-1)
    s["slots"] = [[s["x"] + k * rx * SPACING, s["y"] + k * ry * SPACING] for k in (0, -1, 1)]   # slot 1, 2, 3

# ------------------------------------------------------------------------------------------------ bounds and exterior
BOUNDS = dict(
    kill_below=-12, kill_above=60,
    house=dict(x0=-XI, x1=XI, y0=-YI, y1=YI),
    note="a return volume (Bounds/Return_*) around the shell: any body outside the house box (+2) or below -12 is put back "
         "on its team spawn; the windows' player barriers and the locked doors are the real enclosure")
EXTERIOR = dict(
    note="seen through the windows only; unreachable (outside the barriers). The modeler's set, placed by the installer.",
    street=dict(y=[-80, -56], note="two-lane suburban street, kerbs, a crossing line; parked cars both sides"),
    front_yard=dict(y=[-56, -31], note="lawn, a concrete driveway on the east side (x 16..30) with the family car, a path to "
                                      "the front door, a low hedge + mailbox at the kerb"),
    across=dict(y=[-150, -88], note="the house across the street: a similar modern two-storey in a different colour, its own "
                                   "lawn, car, fence; neighbours beyond, trees"),
    sides=dict(x=[[-90, -42], [42, 90]], note="side yards with timber fences 7 high, the neighbours' walls and windows"),
    back_yard=dict(y=[31, 75], note="patio, lawn, a timber fence, a shed, a trampoline-free yard; the neighbours' roofs beyond"),
    roof=dict(note="pitched roof over the upper storey, flat roof with two skylights over the kitchen (x 9..40, y 4..30)"),
    sky="a clear late-afternoon sky in the map's palette (not default blue)",
)

layout = dict(
    name="House", version=1, units="studs",
    plan_axes="x east, y north (front/street = south), z up; world = ORIGIN + (x, z, -y)",
    decisions=[
        "Edward's brief (2026-10-28 work order): two storeys; the staircase near the front door, at its top a railing on the "
        "RIGHT and a door on the LEFT into the master bedroom; ground: bathroom, kitchen, living room, dining room; upper: two "
        "bedrooms, bathroom, master bedroom with its own bathroom; real hinged doors held AJAR (ensuite CLOSED, front + back "
        "CLOSED and locked); windows shatter, frames stay, player barriers; cover = furniture at 3.4 / 7+; fair spawns 1v1-3v3",
        "Builder's call (flag for Edward): a second, enclosed BACK STAIR from the back hall to the landing. With one stair the "
        "only way between the floors is a single choke the upstairs team can hold; the back stair makes a loop "
        "(foyer - main stair - landing - back stair - back hall - kitchen) so each team has two routes.",
        "Both teams spawn on the ground floor at opposite ends (A: living room, B: kitchen), each behind a tall spawn wall; "
        "the plan is near point-symmetric (turned 180 degrees about the centre: living room <-> kitchen, main stair <-> back "
        "stair, foyer <-> back hall). The upper floor is the contested high ground each team reaches by its own stair. "
        "(Tried first: A downstairs / B upstairs. The ground rooms are open plan and the bedrooms closed boxes, so exposure "
        "differed by ~50 % and spawn sight by ~25-50 %; no furniture change closed that.)",
    ],
    storeys=dict(G=dict(floor=G0, ceiling=GC), U=dict(floor=U0, ceiling=UC)),
    shell=dict(x0=-XI, x1=XI, y0=-YI, y1=YI, t_ext=T_EXT, t_int=T_INT),
    heights=dict(low=LOW, tall=TALL, step=STEP, door=DOOR_H, front_door=FRONT_H, windows=WIN, railing=3.5),
    movement=dict(eye=4.6, chest=4.0, crouch_eye=2.6, crouch_head_top=3.85, sprint=20.0, walk=10.0, body_r=1.0,
                  step=1.6, headroom=5.0, vault_s=0.34, note="notes/warehouse_study/movement_configs.txt; crouched head "
                  "measured in Play 3.79-3.89 (arena v2)"),
    voids=[dict(id="Void_Foyer", x0=-9, x1=9, y0=-30, y1=-4, note="double-height foyer + the main stair"),
           dict(id="Void_BackStair", x0=3.5, x1=9, y0=4, y1=23, note="back stair well")],
    rooms=rooms, stairs=STAIRS, doors=doors, openings=openings, furniture=furniture, dressing=dressing, parts=parts, art_only=art_only,
    spawns=SPAWNS, spawn_spacing=SPACING, modes=["1v1", "2v2", "3v3"], bounds=BOUNDS, exterior=EXTERIOR,
)

if __name__ == "__main__":
    json.dump(layout, open(OUT, "w"), indent=1)
    print("wrote", OUT, "parts", len(parts), "furniture", len(furniture), "doors", len(doors), "openings", len(openings))

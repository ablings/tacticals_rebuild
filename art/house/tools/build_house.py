"""House map, PART B: the house itself, built EXACTLY from notes/maps/house_layout.json (version 1). One run rebuilds it:
  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python art/house/tools/build_house.py -- [--nobake]

Coordinates: Blender = layout plan coordinates (x east, y north, z up), 1 unit = 1 stud. The layout's world mapping is
ORIGIN + (x, z, -y); Import 3D's own mapping is checked with K_ScaleCube / K_Marker (Blender (0,-120,5) / (12,-120,0)).
What it makes (all art: CanCollide off; the builder's layout Parts are the collision):
  Shell_<storey>_<Material>   walls / sills / slab edges / floors / ceilings from layout parts[] + rooms[], split by tiling
                              material (tex/tile/T_*.png, UVs in studs / tile size). Faces buried in another part are dropped.
  Roof_*                      butterfly roof (metal), gable / eave infill (cladding), flat kitchen roof + parapets + skylights.
  Stair_Main / Stair_Back     16 risers each, oak treads on a white body; Rail_Gallery / Rail_MainStair / Rail_BackStair.
  Door_<id>                   the hinged leaf, ORIGIN ON THE HINGE (bottom of the hinge line), posed at the layout's angle_deg
                              (leaf_yaw_deg). Door_Back also has Door_Back_Glass + Door_Back_BrokenGlass (same origin).
  DoorFrame_<id>              lining + architraves of each door opening.
  <WindowId>_Frame / _Glass / _BrokenGlass   per window opening; origin = the opening's bottom centre on the wall mid-line.
  Skylight_*_Glow             the kitchen skylights' ceiling light panels (set Neon / white in Studio).
Writes art/house/house.blend, fbx/H_House.fbx (+ K_ScaleCube, K_Marker), house_shell.json."""
import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hcore import *          # noqa
import hcore

REPO = os.path.abspath(os.path.join(ROOT, "..", ".."))
LAY = json.load(open(os.path.join(REPO, "notes", "maps", "house_layout.json")))
TILES = json.load(open(os.path.join(TEX, "tile", "tiles.json")))
BLEND = os.path.join(ROOT, "house.blend")
hcore.ATLAS_RES.update({"Stairs": 2048, "Doors": 2048, "Windows": 2048})

for k_, v_ in {
    "oak_slat": dict(under=(178, 144, 104), wood=True, groove=True, stain=0.12, rough=0.55, mottle=0.08),
    "glass_frost": dict(paint=(196, 204, 208), rough=0.5, dirt=0.0, mottle=0.03),
}.items():
    d_ = dict(DEF); d_.update(v_); K[k_] = d_

# ----------------------------------------------------------------------------------------------------------- shell
def _inside_rect(a, b):
    return b["x0"] - 1e-6 <= a["x0"] and a["x1"] <= b["x1"] + 1e-6 and b["y0"] - 1e-6 <= a["y0"] and a["y1"] <= b["y1"] + 1e-6


def _nested(rm, rooms):
    return any(o is not rm and o["storey"] == rm["storey"] and all(any(_inside_rect(r, q) for q in o["rects"]) for r in rm["rects"])
               for o in rooms)


ROOMS = sorted(LAY["rooms"], key=lambda r: 0 if _nested(r, LAY["rooms"]) else 1)    # nested rooms first


def rect_minus(r, cut):
    """r minus cut (axis-aligned), as up to 4 rects"""
    if cut["x1"] <= r["x0"] or cut["x0"] >= r["x1"] or cut["y1"] <= r["y0"] or cut["y0"] >= r["y1"]:
        return [r]
    out = []
    if cut["y0"] > r["y0"]:
        out.append(dict(x0=r["x0"], x1=r["x1"], y0=r["y0"], y1=cut["y0"]))
    if cut["y1"] < r["y1"]:
        out.append(dict(x0=r["x0"], x1=r["x1"], y0=cut["y1"], y1=r["y1"]))
    ya, yb = max(r["y0"], cut["y0"]), min(r["y1"], cut["y1"])
    if cut["x0"] > r["x0"]:
        out.append(dict(x0=r["x0"], x1=cut["x0"], y0=ya, y1=yb))
    if cut["x1"] < r["x1"]:
        out.append(dict(x0=cut["x1"], x1=r["x1"], y0=ya, y1=yb))
    return out


def room_rects(rm):
    rects = [dict(r) for r in rm["rects"]]
    for o in ROOMS:
        if o is rm or o["storey"] != rm["storey"] or not _nested(o, [rm, o]):
            continue
        if not all(any(_inside_rect(q, r) for r in rm["rects"]) for q in o["rects"]):
            continue
        for q in o["rects"]:
            rects = [piece for r in rects for piece in rect_minus(r, q)]
    return rects
VOIDS = LAY["voids"]
SH = LAY["shell"]
WALL_MAT = {"LR": "PaintGreige", "DR": "PaintGreige", "MB": "PaintSlate", "BR2": "PaintGreige",
            "GB": "WallTile", "UB": "WallTile", "EN": "WallTile"}
FLOOR_MAT = {"GB": "FloorTile", "UB": "FloorTile", "EN": "FloorTile", "KT": "FloorTile", "BH": "FloorTile"}


def in_rect(p, r, pad=0.0):
    return r["x0"] - pad <= p.x <= r["x1"] + pad and r["y0"] - pad <= p.y <= r["y1"] + pad


def room_at(p):
    for rm in ROOMS:
        st = rm["storey"]
        if st == "G":
            top = 26.0 if rm["id"] == "FY" else 13.0
            if not (0.0 <= p.z <= top):
                continue
        else:
            if not (14.0 <= p.z <= 26.0):
                continue
        if any(in_rect(p, r) for r in rm["rects"]):
            return rm["id"]
    return None


def in_void(p):
    return any(in_rect(p, v) for v in VOIDS) and 0.0 <= p.z <= 26.0


BOXES = [p for p in LAY["parts"] if p["role"] in ("wall", "sill", "floor", "ceiling")]


def _covered(x0, x1, y0, y1, z0, z1):
    c = Vector(((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2))
    return any(b["x0"] - 1e-6 <= c.x <= b["x1"] + 1e-6 and b["y0"] - 1e-6 <= c.y <= b["y1"] + 1e-6 and b["z0"] - 1e-6 <= c.z <= b["z1"] + 1e-6 for b in BOXES)


def _band_fill():
    """layout walls stop at 13 (ground) and start at 14 (upper); where no slab fills that band under an upper wall, the
    shell would show a 1-stud slot. Fill it with a wall-band box (art only), sampled every 0.5 along the wall."""
    add = []
    for b in [b for b in BOXES if b["role"] in ("wall", "sill") and abs(b["z0"] - 14.0) < 1e-6]:
        L = max(b["x1"] - b["x0"], b["y1"] - b["y0"])
        along = "x" if (b["x1"] - b["x0"]) >= (b["y1"] - b["y0"]) else "y"
        n = max(1, int(round(L / 0.5)))
        run = None
        for i in range(n + 1):
            t = (i + 0.5) / n if i < n else None
            if t is not None:
                if along == "x":
                    xa = b["x0"] + (b["x1"] - b["x0"]) * i / n; xb = b["x0"] + (b["x1"] - b["x0"]) * (i + 1) / n
                    free = not _covered(xa, xb, b["y0"], b["y1"], 13.0, 14.0)
                    seg = (xa, xb)
                else:
                    ya = b["y0"] + (b["y1"] - b["y0"]) * i / n; yb = b["y0"] + (b["y1"] - b["y0"]) * (i + 1) / n
                    free = not _covered(b["x0"], b["x1"], ya, yb, 13.0, 14.0)
                    seg = (ya, yb)
            else:
                free = False
            if free:
                run = (run[0], seg[1]) if run else seg
            elif run:
                if along == "x":
                    add.append(dict(id=b["id"] + "_Band", x0=run[0], x1=run[1], y0=b["y0"], y1=b["y1"], z0=13.0, z1=14.0, role="wall"))
                else:
                    add.append(dict(id=b["id"] + "_Band", x0=b["x0"], x1=b["x1"], y0=run[0], y1=run[1], z0=13.0, z1=14.0, role="wall"))
                run = None
    return add


BANDS = _band_fill()
PLANE_RECTS = []      # (z, x0, x1, y0, y1, facing_up) of every room floor (up) and ceiling (down) quad
# visual corner square where the back-hall wall (I_Y10_G_3) stops short of the hall wall line: without it two faces of
# the same plane look at each other across the corner (0.5 x 1 x 13, inside the wall corner; art only)
CORNERS = [dict(id="Corner_BH", x0=-9.5, x1=-8.5, y0=10.0, y1=10.5, z0=0.0, z1=13.0, role="wall")]
BOXES += BANDS + CORNERS
DOOR_OPS = [o for o in LAY["openings"] if o["kind"] == "door"]


def in_door_opening(c):
    """a face centre inside a door opening's reveal (the lining covers it)"""
    for o in DOOR_OPS:
        if o["axis"] == "x":
            a, t = c.x, c.y
        else:
            a, t = c.y, c.x
        if o["a"] - 0.01 <= a <= o["b"] + 0.01 and o["t0"] - 0.01 <= t <= o["t1"] + 0.01 and o["z0"] - 0.01 <= c.z <= o["z1"] + 0.01:
            return True
    return False


def inside_any(p, skip=None, eps=1e-3):
    for b in BOXES:
        if b is skip:
            continue
        if b["x0"] + eps < p.x < b["x1"] - eps and b["y0"] + eps < p.y < b["y1"] - eps and b["z0"] + eps < p.z < b["z1"] - eps:
            return True
    return False


SHELL = {}   # (storey, material) -> list of polys (list of Vector, CCW seen from the front)

def add_poly(mat, pts, storey):
    SHELL.setdefault((storey, mat), []).append([Vector(p) for p in pts])


def box_faces(x0, x1, y0, y1, z0, z1):
    """(normal, centre, CCW quad) for the 6 faces"""
    v = lambda x, y, z: Vector((x, y, z))
    return [
        (Vector((-1, 0, 0)), [v(x0, y1, z0), v(x0, y0, z0), v(x0, y0, z1), v(x0, y1, z1)]),
        (Vector((1, 0, 0)), [v(x1, y0, z0), v(x1, y1, z0), v(x1, y1, z1), v(x1, y0, z1)]),
        (Vector((0, -1, 0)), [v(x0, y0, z0), v(x1, y0, z0), v(x1, y0, z1), v(x0, y0, z1)]),
        (Vector((0, 1, 0)), [v(x1, y1, z0), v(x0, y1, z0), v(x0, y1, z1), v(x1, y1, z1)]),
        (Vector((0, 0, -1)), [v(x0, y1, z0), v(x1, y1, z0), v(x1, y0, z0), v(x0, y0, z0)]),
        (Vector((0, 0, 1)), [v(x0, y0, z1), v(x1, y0, z1), v(x1, y1, z1), v(x0, y1, z1)]),
    ]


def ext_mat(zc):
    return "Concrete" if zc < 0 else ("Render" if zc < 14.0 else "Cladding")


def visible_parts(face, normal, owner, n=5):
    """split a face into an n x n grid and keep the cells whose probe is not buried in another part"""
    a, b, c, d = face
    cells = []
    for i in range(n):
        for j in range(n):
            u0, u1, v0, v1 = i / n, (i + 1) / n, j / n, (j + 1) / n
            P = lambda u, v: a.lerp(b, u).lerp(d.lerp(c, u), v)
            q = [P(u0, v0), P(u1, v0), P(u1, v1), P(u0, v1)]
            cen = sum(q, Vector()) / 4
            if not inside_any(cen + normal * 0.03, skip=owner):
                cells.append(q)
    return cells


def exact_cells(face, normal, owner):
    """split an axis-aligned face at every boundary of the parts that touch it, then keep the cells whose centre is not
    buried in another part and not covered by a room floor / ceiling quad on the same plane (same facing)"""
    ax = max(range(3), key=lambda i: abs(normal[i]))
    u, v = [i for i in range(3) if i != ax]
    lo = [min(p[i] for p in face) for i in range(3)]
    hi = [max(p[i] for p in face) for i in range(3)]
    cu, cv = {lo[u], hi[u]}, {lo[v], hi[v]}
    key = ("x0", "y0", "z0"), ("x1", "y1", "z1")
    for b in BOXES:
        if b is owner:
            continue
        blo = [b["x0"], b["y0"], b["z0"]]; bhi = [b["x1"], b["y1"], b["z1"]]
        if any(bhi[i] < lo[i] - 0.06 or blo[i] > hi[i] + 0.06 for i in range(3)):
            continue
        for val in (blo[u], bhi[u]):
            if lo[u] + 1e-4 < val < hi[u] - 1e-4:
                cu.add(val)
        for val in (blo[v], bhi[v]):
            if lo[v] + 1e-4 < val < hi[v] - 1e-4:
                cv.add(val)
    for (fz, rx0, rx1, ry0, ry1, up) in PLANE_RECTS:
        if ax == 2 and abs(lo[2] - fz) < 1e-4:
            for val in (rx0, rx1):
                if lo[0] + 1e-4 < val < hi[0] - 1e-4:
                    cu.add(val)
            for val in (ry0, ry1):
                if lo[1] + 1e-4 < val < hi[1] - 1e-4:
                    cv.add(val)
    cu, cv = sorted(cu), sorted(cv)
    cells = []
    for i in range(len(cu) - 1):
        for j in range(len(cv) - 1):
            c = Vector(lo)
            c[u] = (cu[i] + cu[i + 1]) / 2; c[v] = (cv[j] + cv[j + 1]) / 2
            if inside_any(c + normal * 0.03, skip=owner):
                continue
            if ax == 2 and any(abs(c.z - fz) < 1e-4 and rx0 <= c.x <= rx1 and ry0 <= c.y <= ry1 and (normal.z > 0) == up
                               for (fz, rx0, rx1, ry0, ry1, up) in PLANE_RECTS):
                continue
            q = []
            for (a_, b_) in ((cu[i], cv[j]), (cu[i + 1], cv[j]), (cu[i + 1], cv[j + 1]), (cu[i], cv[j + 1])):
                pnt = Vector(lo); pnt[u] = a_; pnt[v] = b_
                q.append(pnt)
            nq = (q[1] - q[0]).cross(q[2] - q[0])
            if nq.dot(normal) < 0:
                q = list(reversed(q))
            cells.append(q)
    return cells, (len(cu) - 1) * (len(cv) - 1)


def merge_cells(cells, face, n):
    """if every cell is visible return the whole face, else the cells (keeps big faces as one quad)"""
    return [face] if len(cells) == n * n else cells


def o_axis_end(quad, nrm, b):
    """True for a wall box's end face (normal along the wall's length): a reveal"""
    thin_x = (b["x1"] - b["x0"]) <= 1.01 and (b["y1"] - b["y0"]) > 1.01
    thin_y = (b["y1"] - b["y0"]) <= 1.01 and (b["x1"] - b["x0"]) > 1.01
    return (thin_x and abs(nrm.y) > 0.5) or (thin_y and abs(nrm.x) > 0.5)


def build_shell():
    for rm in ROOMS:
        fz = 0.0 if rm["storey"] == "G" else 14.0
        cz = 26.0 if (rm["storey"] == "U" or rm["id"] == "FY") else 13.0
        for r in room_rects(rm):
            PLANE_RECTS.append((fz, r["x0"], r["x1"], r["y0"], r["y1"], True))
            PLANE_RECTS.append((cz, r["x0"], r["x1"], r["y0"], r["y1"], False))
    split_z = (0.0, 13.0, 14.0, 26.0)
    for b in BOXES:
        role = b["role"]
        zs = [b["z0"]] + [z for z in split_z if b["z0"] < z < b["z1"]] + [b["z1"]]
        for z0, z1 in zip(zs, zs[1:]):
            sub = dict(b, z0=z0, z1=z1)
            for nrm, quad in box_faces(b["x0"], b["x1"], b["y0"], b["y1"], z0, z1):
                if role in ("floor", "ceiling") and abs(nrm.z) > 0.5:
                    continue          # floor tops / ceiling undersides come from the room quads
                cen = sum(quad, Vector()) / 4
                probe = cen + nrm * 0.3
                storey = "G" if cen.z < 13.5 else "U"
                if role in ("wall", "sill") and in_door_opening(cen) and not (abs(abs(cen.y) - 31.0) < 1e-3 or abs(abs(cen.x) - 41.0) < 1e-3):
                    if (abs(nrm.z) > 0.5 and nrm.z < 0) or (o_axis_end(quad, nrm, b)):
                        continue
                if abs(nrm.z) > 0.5:
                    if inside_any(cen + nrm * 0.03, skip=b):
                        continue
                    mat = "PaintWhite"
                    if not (abs(probe.x) < 40.0 and abs(probe.y) < 30.0):
                        mat = ext_mat(cen.z)
                else:
                    on_edge = abs(abs(cen.x) - 41.0) < 1e-3 or abs(abs(cen.y) - 31.0) < 1e-3
                    thin = "x" if (b["x1"] - b["x0"]) <= 1.01 and (b["y1"] - b["y0"]) > 1.01 else ("y" if (b["y1"] - b["y0"]) <= 1.01 else None)
                    along_thickness = (thin == "x" and abs(nrm.x) > 0.5) or (thin == "y" and abs(nrm.y) > 0.5)
                    rid = room_at(probe)
                    band_in = 13.0 - 1e-3 <= cen.z <= 14.0 + 1e-3 and abs(probe.x) < 40.0 and abs(probe.y) < 30.0 and not (9.5 < probe.x and 4.5 < probe.y)
                    if role in ("floor", "ceiling"):
                        mat = ext_mat(cen.z) if (rid is None and not in_void(probe) and not band_in) else "PaintWhite"
                    elif along_thickness or on_edge:
                        if rid:
                            mat = WALL_MAT.get(rid, "PaintWhite")
                        elif in_void(probe) or band_in:
                            mat = "PaintWhite"
                        else:
                            mat = ext_mat(cen.z)
                    else:
                        mat = "PaintWhite"   # reveal of an opening or a wall end inside the house
                    if (b["x0"] <= -40.999 or b["x1"] >= 40.999 or b["y0"] <= -30.999 or b["y1"] >= 30.999) and not along_thickness and not on_edge:
                        mat = "PaintWhite"
                cells, total = exact_cells(quad, nrm, b)
                if not cells:
                    continue
                for q in ([quad] if len(cells) == total else cells):
                    add_poly(mat, q, storey)
    # floors and ceilings per room rect (plus the stair voids)
    for rm in ROOMS:
        fz = 0.0 if rm["storey"] == "G" else 14.0
        cz = 26.0 if (rm["storey"] == "U" or rm["id"] == "FY") else 13.0
        for r in room_rects(rm):
            x0, x1, y0, y1 = r["x0"], r["x1"], r["y0"], r["y1"]
            add_poly(FLOOR_MAT.get(rm["id"], "OakFloor"), [(x0, y0, fz), (x1, y0, fz), (x1, y1, fz), (x0, y1, fz)], rm["storey"])
            add_poly("CeilingWhite", [(x0, y1, cz), (x1, y1, cz), (x1, y0, cz), (x0, y0, cz)], rm["storey"])
    for o in DOOR_OPS:      # thresholds: each half of the wall depth in the floor of the room on that side (Concrete outside)
        tm = (o["t0"] + o["t1"]) / 2
        for (ta, tb, probe_t) in ((o["t0"], tm, o["t0"] - 0.4), (tm, o["t1"], o["t1"] + 0.4)):
            pa = (o["a"] + o["b"]) / 2
            pr = Vector((pa, probe_t, o["z0"] + 2)) if o["axis"] == "x" else Vector((probe_t, pa, o["z0"] + 2))
            rid = room_at(pr)
            mat = FLOOR_MAT.get(rid, "OakFloor") if rid else "Concrete"
            hc = Vector(((o["a"] + o["b"]) / 2, (ta + tb) / 2, o["z0"])) if o["axis"] == "x" else Vector(((ta + tb) / 2, (o["a"] + o["b"]) / 2, o["z0"]))
            if any(abs(fz - o["z0"]) < 1e-4 and up and rx0 <= hc.x <= rx1 and ry0 <= hc.y <= ry1 for (fz, rx0, rx1, ry0, ry1, up) in PLANE_RECTS):
                continue     # a room floor already reaches the wall centre line here
            if o["axis"] == "x":
                q = [(o["a"], ta, o["z0"]), (o["b"], ta, o["z0"]), (o["b"], tb, o["z0"]), (o["a"], tb, o["z0"])]
            else:
                q = [(ta, o["a"], o["z0"]), (tb, o["a"], o["z0"]), (tb, o["b"], o["z0"]), (ta, o["b"], o["z0"])]
            add_poly(mat, q, "G" if o["z0"] < 13 else "U")
    v = [v for v in VOIDS if v["id"] == "Void_BackStair"][0]
    add_poly("FloorTile", [(v["x0"], v["y0"], 0), (v["x1"], v["y0"], 0), (v["x1"], v["y1"], 0), (v["x0"], v["y1"], 0)], "G")
    add_poly("CeilingWhite", [(v["x0"], v["y1"], 26), (v["x1"], v["y1"], 26), (v["x1"], v["y0"], 26), (v["x0"], v["y0"], 26)], "U")
    # flat kitchen roof (outside, upper level): gravel membrane over the slab, x 9.5..40, y 4.5..30
    add_poly("Gravel", [(9.5, 4.5, 14.0), (40.0, 4.5, 14.0), (40.0, 30.0, 14.0), (9.5, 30.0, 14.0)], "U")


def _plane_key(poly):
    a, b, c = poly[0], poly[1], poly[2]
    n = (b - a).cross(c - a)
    if n.length < 1e-9:
        return None, None, None
    n.normalize()
    d = n.dot(a)
    return n, d, (round(abs(n.x), 3), round(abs(n.y), 3), round(abs(n.z), 3), round(abs(d), 2))


def _inside_poly(p, poly, n):
    ax = max(range(3), key=lambda i: abs(n[i]))
    u, v = [i for i in range(3) if i != ax]
    x, y = p[u], p[v]
    ins = False
    m = len(poly)
    for i in range(m):
        x1, y1 = poly[i][u], poly[i][v]
        x2, y2 = poly[(i + 1) % m][u], poly[(i + 1) % m][v]
        if (y1 > y) != (y2 > y):
            xi = x1 + (y - y1) * (x2 - x1) / (y2 - y1)
            if xi > x:
                ins = not ins
    return ins


def dedupe_shell():
    """drop every polygon whose centre lies on an opposite-facing coplanar polygon (any material, any group)"""
    allp = []
    for key, polys in SHELL.items():
        for i, poly in enumerate(polys):
            n, d, k = _plane_key(poly)
            if n is not None:
                allp.append((key, i, poly, n, d, k))
    buckets = {}
    for e in allp:
        buckets.setdefault(e[5], []).append(e)
    drop = set()
    for es in buckets.values():
        if len(es) < 2:
            continue
        for e in es:
            key, i, poly, n, d, _ = e
            c = sum(poly, Vector()) / len(poly)
            for f in es:
                if f is e or n.dot(f[3]) > -0.999 or abs(d + f[4]) > 2e-3:
                    continue
                if _inside_poly(c, f[2], f[3]):
                    drop.add((key, i)); break
    for key in list(SHELL):
        SHELL[key] = [p for i, p in enumerate(SHELL[key]) if (key, i) not in drop]
    return len(drop)


def coplanar_same_report():
    """exactly coplanar, same-facing overlapping polygons (z-fight) across all shell groups: blender_check's A8 skips
    hits closer than 0.001, so these are invisible to it. Returns a list of (group/material pairs, centre)."""
    allp = []
    for key, polys in SHELL.items():
        for i, poly in enumerate(polys):
            n, d, k = _plane_key(poly)
            if n is not None:
                allp.append((key, i, poly, n, d, k))
    buckets = {}
    for e in allp:
        buckets.setdefault(e[5], []).append(e)
    out = []
    for es in buckets.values():
        for e in es:
            c = sum(e[2], Vector()) / len(e[2])
            for f in es:
                if f is e or e[3].dot(f[3]) < 0.999 or abs(e[4] - f[4]) > 2e-3:
                    continue
                if _inside_poly(c, f[2], f[3]):
                    out.append((e[0], f[0], [round(v, 2) for v in c]))
                    break
    return out


def tiled_object(name, mat, polys):
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new("UVMap")
    ts = TILES.get(mat, 8.0)
    for poly in polys:
        vs = [bm.verts.new(p) for p in poly]
        try:
            f = bm.faces.new(vs)
        except ValueError:
            continue
        f.normal_update()
        n = f.normal
        a = max(range(3), key=lambda i: abs(n[i]))
        if a == 2:
            uax, vax = 0, 1
        else:
            uax, vax = (1 if a == 0 else 0), 2
        sgn = 1.0 if (a == 2 or n[a] > 0) else -1.0
        for l in f.loops:
            co = l.vert.co
            u = co[uax] / ts * (sgn if a == 0 else (-sgn if a == 1 else 1.0))
            l[uv].uv = (u, co[vax] / ts)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-4)
    bm.normal_update()
    bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="BEAUTY", ngon_method="BEAUTY")
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me); bm.free()
    for p in me.polygons:
        p.use_smooth = False
    ob = bpy.data.objects.new(name, me)
    coll("House").objects.link(ob)
    me.materials.append(tile_material(mat))
    ob["tile"] = mat
    ob["open_shell"] = True     # single-sided room linings by design (walls are seen from one side per face)
    return ob


TMAT = {}
def tile_material(mat):
    if mat in TMAT:
        return TMAT[mat]
    m = bpy.data.materials.new("T_" + mat)
    g = G(m)
    bsdf = g.n("ShaderNodeBsdfPrincipled")
    path = os.path.join(TEX, "tile", f"T_{mat}.png")
    im = bpy.data.images.load(path, check_existing=True)
    t = g.n("ShaderNodeTexImage", image=im)
    g.put(t.inputs[0], g.uv("UVMap"))
    g.put(bsdf.inputs["Base Color"], t.outputs[0])
    bsdf.inputs["Roughness"].default_value = {"Gravel": 0.95, "RoofMetal": 0.45, "WallTile": 0.2, "FloorTile": 0.3, "OakFloor": 0.45}.get(mat, 0.8)
    out = g.n("ShaderNodeOutputMaterial"); g.put(out.inputs["Surface"], bsdf.outputs[0])
    TMAT[mat] = m
    return m


PLAIN = {}
def plain_material(name, rgb, rough=0.5, alpha=1.0):
    if name in PLAIN:
        return PLAIN[name]
    m = bpy.data.materials.new(name)
    g = G(m)
    bsdf = g.n("ShaderNodeBsdfPrincipled")
    bsdf.inputs["Base Color"].default_value = srgb(rgb)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Alpha"].default_value = alpha
    out = g.n("ShaderNodeOutputMaterial"); g.put(out.inputs["Surface"], bsdf.outputs[0])
    m.diffuse_color = srgb(rgb)
    PLAIN[name] = m
    return m


# ----------------------------------------------------------------------------------------------------------- roof
S_ROOF = 6.0 / 35.5
def under_front(y):   # roof underside over the front block, valley at y 4.5
    return 27.3 + (4.5 - y) * S_ROOF
def under_back(y):
    return 27.3 + (y - 4.5) * S_ROOF


def roof_slab(name, x0, x1, ys, fz, thick=0.7):
    """sloped slab: underside z = fz(y) between ys[0]..ys[1], extruded along x"""
    y0, y1 = ys
    pts = [(y0, fz(y0)), (y1, fz(y1)), (y1, fz(y1) + thick), (y0, fz(y0) + thick)]
    mb_polys = []
    # build as tiled polys (top = metal; underside / edges = charcoal fascia)
    P = lambda x, y, z: Vector((x, y, z))
    top = [P(x0, y0, fz(y0) + thick), P(x1, y0, fz(y0) + thick), P(x1, y1, fz(y1) + thick), P(x0, y1, fz(y1) + thick)]
    bot = [P(x0, y1, fz(y1)), P(x1, y1, fz(y1)), P(x1, y0, fz(y0)), P(x0, y0, fz(y0))]
    e1 = [P(x0, y0, fz(y0)), P(x1, y0, fz(y0)), P(x1, y0, fz(y0) + thick), P(x0, y0, fz(y0) + thick)]
    e2 = [P(x1, y1, fz(y1)), P(x0, y1, fz(y1)), P(x0, y1, fz(y1) + thick), P(x1, y1, fz(y1) + thick)]
    s1 = [P(x0, y1, fz(y1)), P(x0, y0, fz(y0)), P(x0, y0, fz(y0) + thick), P(x0, y1, fz(y1) + thick)]
    s2 = [P(x1, y0, fz(y0)), P(x1, y1, fz(y1)), P(x1, y1, fz(y1) + thick), P(x1, y0, fz(y0) + thick)]
    if top[0].y > top[2].y:
        pass
    # orientation: check top normal points up, else reverse all
    def fix(q, want):
        n = (q[1] - q[0]).cross(q[2] - q[0])
        return q if n.dot(want) > 0 else list(reversed(q))
    add_poly("RoofMetal", fix(top, Vector((0, 0, 1))), "R")
    add_poly("Charcoal", fix(bot, Vector((0, 0, -1))), "R")
    add_poly("Charcoal", fix(e1, Vector((0, 1 if y0 > y1 else -1, 0))), "R")
    add_poly("Charcoal", fix(e2, Vector((0, -1 if y0 > y1 else 1, 0))), "R")
    add_poly("Charcoal", fix(s1, Vector((-1, 0, 0))), "R")
    add_poly("Charcoal", fix(s2, Vector((1, 0, 0))), "R")


def infill(axis, c0, c1, a0, a1, zb, ztop_fn, mat="Cladding", n=1):
    """vertical infill wall between z = zb and the roof underside (+0.15 into the slab): thickness c0..c1 across `axis`
    ('x' = wall runs along x at y c0..c1; 'y' = wall runs along y at x c0..c1), length a0..a1. Closed prism as polys."""
    pts = []
    for i in range(n + 1):
        a = a0 + (a1 - a0) * i / n
        pts.append((a, ztop_fn(a) + 0.15))
    prof = [(a0, zb), (a1, zb)] + list(reversed(pts))[:0] + [p for p in reversed(pts)]
    # prof goes a0,zb -> a1,zb -> along the top back to a0
    prof = [(a0, zb), (a1, zb)] + [pts[i] for i in range(n, -1, -1)]
    def P(a, z, c):
        return Vector((a, c, z)) if axis == "x" else Vector((c, a, z))
    for c, sgn in ((c0, -1), (c1, 1)):
        poly = [P(a, z, c) for a, z in prof]
        nrm = Vector((0, sgn, 0)) if axis == "x" else Vector((sgn, 0, 0))
        q = poly
        nn = (q[1] - q[0]).cross(q[-1] - q[0])
        if nn.dot(nrm) < 0:
            q = list(reversed(q))
        add_poly(mat, q, "R")
    for i in range(len(prof)):
        (a_, z_), (b_, w_) = prof[i], prof[(i + 1) % len(prof)]
        q = [P(a_, z_, c0), P(b_, w_, c0), P(b_, w_, c1), P(a_, z_, c1)]
        mid = (q[0] + q[1]) / 2
        cen = Vector(((a0 + a1) / 2, (c0 + c1) / 2, zb + 2)) if axis == "x" else Vector(((c0 + c1) / 2, (a0 + a1) / 2, zb + 2))
        out = mid - cen; out.x *= 1 if axis == "x" else 0; out.y *= 0 if axis == "x" else 1
        if axis == "x":
            out = Vector((mid.x - cen.x, 0, mid.z - cen.z))
        else:
            out = Vector((0, mid.y - cen.y, mid.z - cen.z))
        nn = (q[1] - q[0]).cross(q[3] - q[0])
        if nn.length < 1e-9:
            continue
        if nn.dot(out) < 0:
            q = list(reversed(q))
        add_poly(mat, q, "R")


def build_roof():
    # butterfly roof: front block (y -32.5..4.5, full width) and back wing (y 4.5..32.5, x -42.5..11), valley at y 4.5
    roof_slab("front_w", -42.5, 9.5, (-32.5, 4.5), under_front)
    roof_slab("front_e", 9.5, 42.5, (-32.5, 6.0), under_front)
    roof_slab("back", -42.5, 11.0, (4.5, 32.5), under_back)
    # infill between the top of the walls (27) and the roof underside, on the outside line
    infill("x", -31.0, -30.0, -41.0, 41.0, 27.0, lambda a: under_front(-30.0))                    # front (south) face
    infill("y", -41.0, -40.0, -30.0, 4.5, 27.0, lambda a: under_front(a))                        # west gable, front block
    infill("y", 40.0, 41.0, -30.0, 3.5, 27.0, lambda a: under_front(a))                          # east gable (the eave infill owns y 3.5..4.5)
    infill("x", 3.5, 4.5, 9.5, 41.0, 27.0, lambda a: under_front(4.5))                           # front block's north eave over the kitchen roof
    infill("y", -41.0, -40.0, 4.5, 30.0, 27.0, lambda a: under_back(a))                          # west gable, back wing
    infill("y", 8.5, 9.5, 4.5, 30.0, 27.0, lambda a: under_back(a))                              # back wing's east face over the kitchen roof
    infill("x", 30.0, 31.0, -41.0, 9.5, 27.0, lambda a: under_back(30.0))                        # back (north) face
    # parapets round the flat kitchen roof (render, 1.2 above the membrane)
    for (x0, x1, y0, y1) in ((40.0, 41.0, 4.5, 31.0), (9.5, 40.0, 30.0, 31.0)):
        for nrm, quad in box_faces(x0, x1, y0, y1, 13.0, 15.2):
            if nrm.z < -0.5:
                continue
            cen = sum(quad, Vector()) / 4
            if (nrm.x < -0.5 and abs(cen.x - 40.0) < 1e-3 and 4.5 < cen.y < 30) or (nrm.y < -0.5 and abs(cen.y - 30.0) < 1e-3):
                add_poly("Render", quad, "R")
            elif nrm.z > 0.5:
                add_poly("Charcoal", quad, "R")
            else:
                add_poly("Render", quad, "R")
    # porch canopy over the front door + front / back steps
    for (bx, mat) in (((-1.5, 8.0, -35.5, -30.98, 11.2, 11.8), "Charcoal"), ((-1.5, 7.5, -34.0, -31.0, -1.0, 0.0), "Concrete"),
                      ((-7.5, 1.5, 31.0, 34.0, -1.0, 0.0), "Concrete")):
        for nrm, quad in box_faces(*bx):
            if nrm.z < -0.5 and bx[4] < 0:
                continue
            if abs(nrm.y) > 0.5 and abs(sum(quad, Vector()).y / 4 - (-31.0 if bx[2] < 0 else 31.0)) < 0.05:
                continue   # the face against the house wall
            add_poly(mat, quad, "R")


def skylights():
    """two skylights over the kitchen: upstand + glass on the roof, a trim ring + light panel on the kitchen ceiling"""
    obs = []
    for i, (x0, x1, y0, y1) in enumerate(((17.0, 23.0, 15.0, 21.0), (32.0, 38.0, 15.0, 21.0))):
        for nrm, quad in box_faces(x0 - 0.4, x1 + 0.4, y0 - 0.4, y1 + 0.4, 13.98, 14.9):
            if nrm.z < -0.5:
                continue
            add_poly("Render" if abs(nrm.z) < 0.5 else "Charcoal", quad, "R")
        mb = MB(f"Skylight_{i + 1}_Glass", "Plain:Glass", 0.2)
        mb.boxr((x0 - 0.05, y0 - 0.05, 14.9), (x1 + 0.05, y1 + 0.05, 15.05), "glass_dark")
        obs.append(finish_plain(mb, "H_Glass"))
        tr = MB(f"Skylight_{i + 1}_Trim", "Windows", 0.4)
        for (a, b, c, d) in ((x0 - 0.3, x1 + 0.3, y0 - 0.3, y0), (x0 - 0.3, x1 + 0.3, y1, y1 + 0.3), (x0 - 0.3, x0, y0 - 0.02, y1 + 0.02), (x1, x1 + 0.3, y0 - 0.02, y1 + 0.02)):
            tr.boxr((a, c, 12.55), (b, d, 13.05), "lacquer_white")
        obs.append(finish(tr))
        gl = MB(f"Skylight_{i + 1}_Glow", "Plain:Glow", 0.1)
        gl.boxr((x0 - 0.02, y0 - 0.02, 12.7), (x1 + 0.02, y1 + 0.02, 12.8), "bulb")
        obs.append(finish_plain(gl, "H_Glow"))
    return obs


def finish_plain(mb, matname):
    ob = finish(mb)
    ob["atlas"] = "Plain:" + matname
    return ob


# ----------------------------------------------------------------------------------------------------------- stairs + rails
def stair(st):
    name = "Stair_Main" if st["id"] == "Stair_Main" else "Stair_Back"
    mb = MB(name, "Stairs", 14.0)
    n, rise, run = st["steps"], st["step_rise"], st["step_run"]
    x0, x1 = st["x0"], st["x1"]
    foot, top = st["foot_y"], st["top_y"]
    sgn = 1.0 if top > foot else -1.0
    # body: sawtooth profile in (y, z) under the treads (0.1 below each tread top), solid down to the floor
    prof = [(foot, 0.0)]
    for i in range(1, n + 1):
        ya = foot + sgn * (i - 1) * run
        yb = foot + sgn * i * run
        prof += [(ya, i * rise - 0.1), (yb, i * rise - 0.1)]
    prof += [(top, 0.0)]
    pts = [(p[0], p[1]) for p in prof]
    mb.prism(pts, "X", x0, x1, "lacquer_white")
    for i in range(1, n + 1):
        ya = foot + sgn * (i - 1) * run - sgn * 0.08     # nosing 0.08 over the riser
        yb = foot + sgn * i * run
        lo, hi = (min(ya, yb), max(ya, yb))
        if i == n:
            hi_ = hi if sgn > 0 else hi
            lo, hi = (lo, top) if sgn > 0 else (top, hi)
        mb.boxr((x0 + 0.01, lo, i * rise - 0.13), (x1 - 0.01, hi, i * rise), "oak")
    return finish(mb)


def railing(name, x0, x1, y0, y1, zfn, along, length_pts, atlas="Stairs", newel_ends=(True, True)):
    """balusters 0.25 sq every <= 1.2, handrail 0.35 x 0.25 with its top 3.5 above the walking line zfn(t)"""
    mb = MB(name, atlas, 3.5)
    a0, a1 = length_pts
    L = abs(a1 - a1 * 0 - a0)
    nb = max(2, int(math.ceil(abs(a1 - a0) / 1.2)) + 1)
    c = ((x0 + x1) / 2, (y0 + y1) / 2)
    def at(a, z):
        return Vector((a, c[1], z)) if along == "x" else Vector((c[0], a, z))
    for i in range(nb):
        a = a0 + (a1 - a0) * i / (nb - 1)
        if (i == 0 and newel_ends[0]) or (i == nb - 1 and newel_ends[1]):
            continue
        z = zfn(a)
        p = at(a, z)
        mb.boxr((p.x - 0.125, p.y - 0.125, z - 0.05), (p.x + 0.125, p.y + 0.125, z + 3.3), "black_metal")
    # newels
    for i, a in ((0, a0), (1, a1)):
        if newel_ends[i]:
            z = zfn(a)
            p = at(a, z)
            mb.boxr((p.x - 0.22, p.y - 0.22, z - 0.05), (p.x + 0.22, p.y + 0.22, z + 3.75), "black_metal")
    # handrail as a sloped / straight bar along the run (top 3.5 above the line)
    segs = 1
    pa, pb = at(a0, zfn(a0) + 3.25), at(a1, zfn(a1) + 3.25)
    d = (pb - pa)
    w, h = 0.175, 0.125
    side = Vector((0, 1, 0)) if along == "x" else Vector((1, 0, 0))
    up = Vector((0, 0, 1))
    vs = []
    for p in (pa, pb):
        for s, t in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            vs.append(p + side * (s * w) + up * (t * h))
    mb.raw(vs, [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)], "oak")
    # bottom rail 0.3 above the line (keeps the balusters tied)
    qa, qb = at(a0, zfn(a0) + 0.3), at(a1, zfn(a1) + 0.3)
    vs = []
    for p in (qa, qb):
        for s, t in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            vs.append(p + side * (s * 0.1) + up * (t * 0.06))
    mb.raw(vs, [(0, 1, 2, 3), (7, 6, 5, 4), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)], "black_metal")
    return finish(mb)


def stair_line(st):
    """walking line z(y) over the nosings of a stair"""
    foot, top, rise, run, n = st["foot_y"], st["top_y"], st["step_rise"], st["step_run"], st["steps"]
    sgn = 1.0 if top > foot else -1.0
    def z(y):
        t = (y - foot) * sgn / (run * n)
        return max(0.0, min(1.0, t)) * (rise * n) + rise * 0.5 * (1 - max(0.0, min(1.0, t)))
    return z


# ----------------------------------------------------------------------------------------------------------- doors
OPEN = {o["id"]: o for o in LAY["openings"]}


def door_leaf(d):
    """leaf in local space: hinge axis at the origin, leaf along +X, thickness across Y, bottom z 0. Posed by the object."""
    w, t, h = d["leaf"]["w"], d["leaf"]["t"], d["leaf"]["h"]
    name = "Door_" + d["id"].split("_", 1)[1]
    model = d["model"]
    obs = []
    if model == "BackDoor":
        mb = MB(name, "Doors", h)
        st = 0.45
        mb.boxr((0.0, -t / 2, 0.0), (st, t / 2, h), "black_metal")
        mb.boxr((w - st, -t / 2, 0.0), (w, t / 2, h), "black_metal")
        mb.boxr((st - 0.02, -t / 2, 0.0), (w - st + 0.02, t / 2, 0.9), "black_metal")
        mb.boxr((st - 0.02, -t / 2, h - 0.45), (w - st + 0.02, t / 2, h), "black_metal")
        for sy in (-1, 1):   # lever handles
            y = sy * (t / 2 + 0.12)
            mb.boxr((w - 0.42, min(sy * t / 2, y) - 0.0, 4.1), (w - 0.3, max(sy * t / 2, y), 4.3), "steel")
            mb.boxr((w - 1.1, y - sy * 0.05 - 0.05, 4.15), (w - 0.3, y - sy * 0.05 + 0.05, 4.25), "steel")
        obs.append(finish(mb))
        gl = MB(name + "_Glass", "Plain:Glass", h)
        gl.boxr((st - 0.06, -0.03, 0.84), (w - st + 0.06, 0.03, h - 0.39), "glass_dark")
        obs.append(finish_plain(gl, "H_Glass"))
        obs.append(broken_pane(name + "_BrokenGlass", (st - 0.06, 0.84), (w - st + 0.06, h - 0.39), axis="x", tm=0.0, seed=sum(map(ord, name))))
        return obs
    mb = MB(name, "Doors", h)
    if model == "FrontDoor":
        sx0, sx1, sz0, sz1 = 0.9, 1.35, 1.6, h - 1.6          # narrow glass slot cut through the leaf
        mb.boxr((0.0, -t / 2, 0.0), (sx0, t / 2, h), "oak_slat", grain=2)
        mb.boxr((sx1, -t / 2, 0.0), (w, t / 2, h), "oak_slat", grain=2)
        mb.boxr((sx0 - 0.01, -t / 2, 0.0), (sx1 + 0.01, t / 2, sz0), "oak_slat", grain=2)
        mb.boxr((sx0 - 0.01, -t / 2, sz1), (sx1 + 0.01, t / 2, h), "oak_slat", grain=2)
        mb.boxr((sx0 - 0.02, -0.03, sz0 - 0.02), (sx1 + 0.02, 0.03, sz1 + 0.02), "glass_dark")
        for sy in (-1,):     # long pull bar outside (street side)
            y = sy * (t / 2)
            mb.tube([(w - 0.6, y, 2.5), (w - 0.6, y - 0.35, 2.6), (w - 0.6, y - 0.35, 7.0), (w - 0.6, y, 7.1)], 0.07, "black_metal", segs=8)
        mb.boxr((w - 0.42, t / 2 - 0.01, 4.1), (w - 0.3, t / 2 + 0.12, 4.3), "black_metal")
        mb.boxr((w - 1.1, t / 2 + 0.07, 4.15), (w - 0.3, t / 2 + 0.17, 4.25), "black_metal")
    else:
        mb.boxr((0.0, -t / 2, 0.0), (w, t / 2, h), "lacquer_white")
        for sy in (-1, 1):
            y0, y1 = (t / 2 - 0.01, t / 2 + 0.12) if sy > 0 else (-t / 2 - 0.12, -t / 2 + 0.01)
            mb.boxr((w - 0.42, y0, 4.1), (w - 0.3, y1, 4.3), "black_metal")
            ly = (t / 2 + 0.07, t / 2 + 0.17) if sy > 0 else (-t / 2 - 0.17, -t / 2 - 0.07)
            mb.boxr((w - 1.1, ly[0], 4.15), (w - 0.3, ly[1], 4.25), "black_metal")
    obs.append(finish(mb))
    return obs


def door_frame(op):
    """lining + architraves for a door opening (white inside; the street / garden faces of the outer doors charcoal)"""
    mb = MB("DoorFrame_" + op["id"].split("_", 1)[1], "Doors", op["z1"] - op["z0"])
    a, b, z0, z1, t0, t1 = op["a"], op["b"], op["z0"], op["z1"], op["t0"], op["t1"]
    ext = op["wall"].startswith("W_")
    def B(alo, ahi, tlo, thi, zlo, zhi, kind):
        if op["axis"] == "x":
            mb.boxr((alo, tlo, zlo), (ahi, thi, zhi), kind)
        else:
            mb.boxr((tlo, alo, zlo), (thi, ahi, zhi), kind)
    k_in = "lacquer_white"
    lin = 0.1
    B(a, a + lin, t0 - 0.02, t1 + 0.02, z0, z1, k_in)
    B(b - lin, b, t0 - 0.02, t1 + 0.02, z0, z1, k_in)
    B(a - 0.01, b + 0.01, t0 - 0.02, t1 + 0.02, z1 - lin, z1, k_in)
    out_side_t0 = ext and (op["line"] < 0 if op["axis"] == "x" else op["line"] < 0)
    for side, (tl, th) in (("t0", (t0 - 0.14, t0 + 0.02)), ("t1", (t1 - 0.02, t1 + 0.14))):
        k = k_in
        if ext:
            outside = (side == "t0") if op["line"] < 0 else (side == "t1")
            k = "black_metal" if outside else k_in
        w = 0.35
        B(a - w, a + 0.12, tl, th, z0, z1 + w - 0.04, k)          # the architrave covers the lining's end (0.1)
        B(b - 0.12, b + w, tl, th, z0, z1 + w - 0.04, k)
        B(a - w + 0.02, b + w - 0.02, tl, th, z1 - 0.12, z1 + w, k)
    ob = finish(mb)
    return ob


# ----------------------------------------------------------------------------------------------------------- windows
def ring_prism(mb, outer, inner, axis, tm, half, kind):
    """closed ring (outer loop + jagged inner loop, same count, in the wall plane) extruded +-half across the wall"""
    def P(a, z, s):
        return Vector((a, tm + s, z)) if axis == "x" else Vector((tm + s, a, z))
    n = len(outer)
    vs = [P(a, z, -half) for a, z in outer] + [P(a, z, -half) for a, z in inner] + [P(a, z, half) for a, z in outer] + [P(a, z, half) for a, z in inner]
    O0, I0, O1, I1 = 0, n, 2 * n, 3 * n
    faces = []
    for i in range(n):
        j = (i + 1) % n
        faces.append((O0 + i, O0 + j, I0 + j, I0 + i))
        faces.append((O1 + i, I1 + i, I1 + j, O1 + j))
        faces.append((O0 + i, O1 + i, O1 + j, O0 + j))
        faces.append((I0 + i, I0 + j, I1 + j, I1 + i))
    return mb.raw(vs, faces, kind)


def broken_pane(name, lo, hi, axis, tm, seed, origin=None):
    """the jagged edge left in a pane's frame after it breaks: a ring of sawtooth shards (each a closed 0.06-thick
    triangle prism) with their bases buried 0.06 in the frame and tips 0.15-0.9 into the opening"""
    mb = MB(name, "Plain:Glass", hi[1] - lo[1])
    rng = random.Random(seed)
    (a0, z0), (a1, z1) = lo, hi
    W, H = a1 - a0, z1 - z0
    def P(a, z, s_):
        return Vector((a, tm + s_, z)) if axis == "x" else Vector((tm + s_, a, z))
    edges = [((a0, z0), (a1, z0), (0, 1)), ((a1, z0), (a1, z1), (-1, 0)), ((a1, z1), (a0, z1), (0, -1)), ((a0, z1), (a0, z0), (1, 0))]
    for (p0, p1, nrm) in edges:
        L = math.hypot(p1[0] - p0[0], p1[1] - p0[1])
        n = max(3, int(L / rng.uniform(0.35, 0.6)))
        ts = sorted([0.0, 1.0] + [rng.uniform(0.05, 0.95) for _ in range(n - 1)])
        for ta, tb in zip(ts, ts[1:]):
            if (tb - ta) * L < 0.08:
                continue
            ba = (p0[0] + (p1[0] - p0[0]) * ta, p0[1] + (p1[1] - p0[1]) * ta)
            bb = (p0[0] + (p1[0] - p0[0]) * tb, p0[1] + (p1[1] - p0[1]) * tb)
            tm_ = rng.uniform(0.3, 0.7)
            mid = (ba[0] + (bb[0] - ba[0]) * tm_, ba[1] + (bb[1] - ba[1]) * tm_)
            edge_dist = min(ta, 1 - tb) * L            # keep tips clear of the corner teeth of the next edge
            dep = rng.uniform(0.15, 0.45) if rng.random() > 0.2 else rng.uniform(0.5, 0.9)
            dep = min(dep, max(0.12, edge_dist + 0.1), 0.42 * min(W, H))
            tip = (mid[0] + nrm[0] * dep, mid[1] + nrm[1] * dep)
            base_out = lambda q: q          # the pane edge already sits 0.06 inside the frame member
            tri = [base_out(ba), base_out(bb), tip]
            vs = [P(a, z, -0.03) for a, z in tri] + [P(a, z, 0.03) for a, z in tri]
            mb.raw(vs, [(0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)], "glass_dark")
    return finish_plain(mb, "H_Glass")


def window(op):
    """frame (ring + mullions/transom, black aluminium) with inside sill (white) and outside flashing; glass panes;
    broken state. Objects: <id>_Frame, <id>_Glass, <id>_BrokenGlass"""
    a, b, z0, z1, t0, t1 = op["a"], op["b"], op["z0"], op["z1"], op["t0"], op["t1"]
    axis = op["axis"]
    tm = (t0 + t1) / 2
    ext = op["wall"].startswith("W_") or op["wall"] == "W_U4"
    interior = op.get("interior", False)
    W, H = b - a, z1 - z0
    ncol = max(1, int(math.ceil(W / 5.2)))
    nrow = 2 if H > 8.5 else 1
    fw, fd = 0.22, 0.2           # frame member width (in the wall plane), half depth across the wall
    fr = MB(op["id"] + "_Frame", "Windows", H)
    def B(alo, ahi, zlo, zhi, tlo, thi, kind):
        if axis == "x":
            fr.boxr((alo, tlo, zlo), (ahi, thi, zhi), kind)
        else:
            fr.boxr((tlo, alo, zlo), (thi, ahi, zhi), kind)
    # outer ring, buried 0.05 into the reveal
    B(a - 0.05, a + fw, z0 - 0.05, z1 + 0.05, tm - fd, tm + fd, "black_metal")
    B(b - fw, b + 0.05, z0 - 0.05, z1 + 0.05, tm - fd, tm + fd, "black_metal")
    B(a + fw - 0.02, b - fw + 0.02, z0 - 0.05, z0 + fw, tm - fd, tm + fd, "black_metal")
    B(a + fw - 0.02, b - fw + 0.02, z1 - fw, z1 + 0.05, tm - fd, tm + fd, "black_metal")
    xs = [a + fw + (W - 2 * fw) * i / ncol for i in range(ncol + 1)]
    zs = [z0 + fw + (H - 2 * fw) * i / nrow for i in range(nrow + 1)]
    if nrow == 2:
        zs[1] = z0 + fw + (H - 2 * fw) * 0.62
    mw = 0.16
    for x in xs[1:-1]:
        B(x - mw / 2, x + mw / 2, z0 + fw - 0.02, z1 - fw + 0.02, tm - fd * 0.8, tm + fd * 0.8, "black_metal")
    for z in zs[1:-1]:
        B(a + fw - 0.02, b - fw + 0.02, z - mw / 2, z + mw / 2, tm - fd * 0.8 - 0.01, tm + fd * 0.8 - 0.01, "black_metal")
    # sills: inside a white board, outside an aluminium flashing (exterior windows only)
    if not interior:
        sign_in = 1.0 if (op["line"] < 0) else -1.0          # inside is toward the house centre
        if axis == "x":
            tin = t1 if op["line"] < 0 else t0
            tout = t0 if op["line"] < 0 else t1
        else:
            tin = t1 if op["line"] < 0 else t0
            tout = t0 if op["line"] < 0 else t1
        si = 1.0 if tin > tout else -1.0
        tlo, thi = sorted((tm + si * fd - si * 0.02, tin + si * 0.35))
        B(a - 0.25, b + 0.25, z0 - 0.05, z0 + 0.15, tlo, thi, "lacquer_white")
        tlo, thi = sorted((tm - si * fd + si * 0.02, tout - si * 0.3))
        B(a - 0.1, b + 0.1, z0 - 0.1, z0 + 0.12, tlo, thi, "black_metal")
    o = finish(fr)
    # glass panes (0.06 thick on the mid-line, edges 0.06 inside the members)
    frost = op.get("frosted", False)
    gl = MB(op["id"] + "_Glass", "Plain:" + ("GlassFrost" if frost else "Glass"), H)
    panes = []
    for i in range(ncol):
        for j in range(nrow):
            pa0 = xs[i] + (mw / 2 if i > 0 else 0) - 0.06
            pa1 = xs[i + 1] - (mw / 2 if i < ncol - 1 else 0) + 0.06
            pz0 = zs[j] + (mw / 2 if j > 0 else 0) - 0.06
            pz1 = zs[j + 1] - (mw / 2 if j < nrow - 1 else 0) + 0.06
            panes.append(((pa0, pz0), (pa1, pz1)))
            if axis == "x":
                gl.boxr((pa0, tm - 0.03, pz0), (pa1, tm + 0.03, pz1), "glass_frost" if frost else "glass_dark")
            else:
                gl.boxr((tm - 0.03, pa0, pz0), (tm + 0.03, pa1, pz1), "glass_frost" if frost else "glass_dark")
    g = finish_plain(gl, "H_GlassFrost" if frost else "H_Glass")
    rng_seed = sum(map(ord, op["id"]))
    for k, (lo, hi) in enumerate(panes):
        bro_objs.append(broken_pane(f"{op['id']}_BrokenGlass_{k}", lo, hi, axis, tm, rng_seed + 13 * k))
    return [o, g]


bro_objs = []




# ----------------------------------------------------------------------------------------------------------- main
def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    objs[0].name = name; objs[0].data.name = name
    return objs[0]


def set_origin(o, p):
    p = Vector(p)
    o.data.transform(Matrix.Translation(-p))
    o.location = p


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(FBXD, exist_ok=True)
    build_shell()
    build_roof()
    baked = []
    plain = []
    sky = skylights()
    log("deduped", dedupe_shell(), "hidden back-to-back faces;", len(BANDS), "wall bands filled")
    cs = coplanar_same_report()
    log("coplanar same-facing overlaps:", len(cs), cs[:6])
    for st in LAY["stairs"]:
        baked.append(stair(st))
    stm = [s for s in LAY["stairs"] if s["id"] == "Stair_Main"][0]
    stb = [s for s in LAY["stairs"] if s["id"] == "Stair_Back"][0]
    zm, zb = stair_line(stm), stair_line(stb)
    baked.append(railing("Rail_Gallery", -3.5, 8.5, -4.15, -3.85, lambda a: 14.0, "x", (-3.45, 8.45)))
    baked.append(railing("Rail_MainStair", -3.55, -3.35, -23.0, -4.15, zm, "y", (-23.0, -4.75), newel_ends=(True, False)))
    baked.append(railing("Rail_BackStair", 3.85, 4.05, 4.15, 23.0, zb, "y", (23.0, 9.6), newel_ends=(True, True)))
    # doors: leaf at the origin, then posed on the hinge
    door_info = []
    for d in LAY["doors"]:
        obs = door_leaf(d)
        for o in obs:
            o.location = (d["hinge"][0], d["hinge"][1], d["z0"])
            o.rotation_euler = (0, 0, math.radians(d["leaf_yaw_deg"]))
        door_info.append(dict(id=d["id"], objects=[o.name for o in obs], hinge_plan=[d["hinge"][0], d["hinge"][1], d["z0"]],
                              leaf=d["leaf"], state=d["state"], angle_deg=d["angle_deg"], leaf_yaw_deg=d["leaf_yaw_deg"],
                              closed_yaw_deg=round(math.degrees(math.atan2(d["closed_dir"][1], d["closed_dir"][0])), 2)))
        for o in obs:
            (plain if str(o.get("atlas", "")).startswith("Plain:") else baked).append(o)
    frames = []
    win_info = []
    for op in LAY["openings"]:
        if op["kind"] == "door":
            frames.append(door_frame(op))
        elif op["kind"] == "window":
            n0 = len(bro_objs)
            fo, go = window(op)
            parts = bro_objs[n0:]
            bo = join(parts, op["id"] + "_BrokenGlass")
            bo["atlas"] = go["atlas"]
            cen = ((op["a"] + op["b"]) / 2, (op["t0"] + op["t1"]) / 2, op["z0"])
            p = Vector((cen[0], cen[1], cen[2])) if op["axis"] == "x" else Vector((cen[1], cen[0], cen[2]))
            for o in (fo, go, bo):
                set_origin(o, p)
            frames.append(fo); plain += [go, bo]
            win_info.append(dict(id=op["id"], frame=fo.name, glass=go.name, broken=bo.name, origin_plan=[round(v, 3) for v in p],
                                 opening=dict(a=op["a"], b=op["b"], z0=op["z0"], z1=op["z1"], axis=op["axis"], line=op["line"]),
                                 frosted=op.get("frosted", False), interior=op.get("interior", False)))
    baked += frames
    for o in sky:
        (plain if str(o.get("atlas", "")).startswith("Plain:") else baked).append(o)
    log("baked", len(baked), "plain", len(plain))
    # bake the atlases (posed objects are fine: AO only sees each atlas group; leaves spread a little would be cleaner)
    atl_files = {}
    if not NOBAKE:
        setup_cycles()
        groups = {}
        for o in baked:
            groups.setdefault(o["atlas"], []).append(o)
        for atl, objs in groups.items():
            # bake each group spread out (AO must not see the house): move far away, bake, move back
            saved = [(o, o.location.copy(), o.rotation_euler.copy()) for o in objs]
            x = 0.0
            for o in objs:
                o.rotation_euler = (0, 0, 0)
                o.location = (0, 0, 0)
                bpy.context.view_layer.update()
                lo, hi = bbox([o])
                o.location = (5000 + x - lo.x, 5000 - lo.y, -lo.z)
                bpy.context.view_layer.update()
                x += (hi.x - lo.x) + 4
            imgs = bake_atlas(atl, objs)
            finalize(objs, atlas_material(atl, imgs))
            atl_files[atl] = {p: f"tex/{PREFIX}{atl}_{p}.png" for p in imgs}
            for o, l, r in saved:
                o.location = l; o.rotation_euler = r
            bpy.context.view_layer.update()
    for o in plain:
        mname = o["atlas"].split(":", 1)[1]
        col = {"H_Glass": (150, 170, 180), "Glass": (150, 170, 180), "H_GlassFrost": (214, 222, 226), "GlassFrost": (214, 222, 226), "H_Glow": (255, 250, 236), "Glow": (255, 250, 236)}[mname]
        me = o.data
        me.materials.clear()
        me.materials.append(plain_material("H_" + mname.replace("H_", ""), col, rough=0.05 if "Glass" in mname else 0.5))
        for p in me.polygons:
            p.material_index = 0
        for nm in [l.name for l in me.uv_layers if l.name != "UVMap"]:
            me.uv_layers.remove(me.uv_layers[nm])
    # shell: one object per (storey, tiling material)
    PLAIN_T = {"Charcoal": (44, 44, 44)}
    shell = []
    for (storey, mat), polys in sorted(SHELL.items()):
        if mat in PLAIN_T:
            ob = tiled_object(f"Shell_{storey}_{mat}", "Render", polys)
            ob.data.materials.clear(); ob.data.materials.append(plain_material("H_Charcoal", PLAIN_T[mat], 0.6))
            ob["tile"] = mat
        else:
            ob = tiled_object(f"Shell_{storey}_{mat}", mat, polys)
        shell.append(ob)
    allobs = shell + baked + plain
    for o in allobs:
        for c in o.users_collection:
            c.objects.unlink(o)
        coll("House").objects.link(o)
    for c in list(bpy.data.collections):
        if c.name == "Masters" and not c.objects:
            bpy.data.collections.remove(c)
    cube, mk = scale_cube_marker()
    cube.location = (0, -120, 5); mk.location = (12, -120, 0)
    bpy.context.view_layer.update()
    man = dict(note="Blender = layout plan coordinates (x east, y north, z up), 1 unit = 1 stud. Layout world = ORIGIN + (x, z, -y). "
                    "Import 3D: measure K_ScaleCube (10 studs, Blender (0,-120,5)) and read K_Marker (long arm +X, upright +Z, short arm +Y, "
                    "Blender (12,-120,0)) to confirm the axes before placing; 'Insert Using Scene Position' keeps the layout position. "
                    "All meshes are art: CanCollide / CanQuery / CanTouch off; the layout Parts are the collision.",
               shell_tiles={k: dict(file=f"tex/tile/T_{k}.png", studs_per_tile=v) for k, v in TILES.items()},
               atlases=atl_files, doors=door_info, windows=win_info, objects=[])
    for o in allobs:
        lo, hi = bbox([o])
        man["objects"].append(dict(name=o.name, tris=tris(o), material=o.data.materials[0].name if o.data.materials else None,
                                   bbox_plan=[[round(v, 3) for v in lo], [round(v, 3) for v in hi]],
                                   origin_plan=[round(v, 3) for v in o.location]))
    man["total_tris"] = sum(e["tris"] for e in man["objects"])
    json.dump(man, open(os.path.join(ROOT, "house_shell.json"), "w"), indent=1)
    if not NOBAKE:
        export_fbx(os.path.join(FBXD, "H_House.fbx"), allobs + [cube, mk])
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    bpy.ops.file.make_paths_relative(); bpy.ops.wm.save_mainfile()
    log("DONE", len(allobs), "objects", man["total_tris"], "tris")


if __name__ == "__main__":
    main()

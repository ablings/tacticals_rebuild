"""1965 test-site House: the shell's restyle data and generators, used by build_house.py.
- ROOM_WALLS / FLOORS: per-room wall bands (lower texture to a split height, upper texture above) and floors.
- split(): cuts a wall poly at the band height (v is measured from the storey floor, so a texture can carry its own grime
  band or frieze at the right height).
- trims(): baseboard / chair rail / picture rail / plate rail / crown cut from the actual wall pieces (they stop at every
  opening because the wall pieces do), stepped 0.03 on y-facing walls so two trims never share a top plane in a corner.
- wear(): the wear layer (water stains, peeling, scorch, bullet holes, faded rectangles, chalk test marks, floor scuffs, sand
  fans, cracked lino, dust) as quads 0.12 off their surface, UVs into tex/decals65/wear_atlas.png (alpha).
- dressing(): where the loose 1965 dressing and the test dummies go, from the layout's furniture records.
Everything here is art: no collision, never moves a wall, opening, door, window or cover box."""
import math, random
from mathutils import Vector, Matrix

# room -> (lower texture, split height above the floor, upper texture, trims, full-height feature walls)
# feature walls: [(normal axis, normal sign, plane test, texture)] e.g. the living room's west wall is fieldstone
ROOM_WALLS = {
    "FY":  ("Wainscot", 3.15, "PaperSprig", ("base", "chair", "crown")),
    "CH":  ("Wainscot", 3.15, "PaperVine", ("base", "chair", "crown")),
    "BH":  ("Wainscot", 3.15, "PaperVine", ("base", "chair", "crown")),
    "MR":  ("PaintCoffeeLow", 3.5, "Pegboard", ("base", "rail35", "crown")),
    "LR":  ("Wainscot", 3.15, "PaintCoffee", ("base", "chair", "crown")),
    "GB":  ("TileMint", 4.5, "PaperSprig", ("crown",)),
    "DR":  ("Wainscot", 3.15, "PaperSprig", ("base", "chair", "plate", "crown")),
    "KT":  ("TileCream", 4.5, "PaperDiamond", ("crown",)),
    "LD":  ("Wainscot", 3.15, "PaperVine", ("base", "chair", "crown")),
    "UH":  ("Wainscot", 3.15, "PaperVine", ("base", "chair", "crown")),
    "MB":  ("PaperSprigRoseLow", 3.5, "PaperSprigRose", ("base", "picture", "crown")),
    "EN":  ("TilePink", 4.5, "PaperSprigRose", ("crown",)),
    "BR2": ("PaintMustardLow", 3.5, "PaintMustard", ("base", "crown")),
    "BR3": ("PaperVineYellowLow", 3.5, "PaperVineYellow", ("base", "crown")),
    "UB":  ("TileButter", 4.5, "PaperVine", ("crown",)),
}
FEATURE = {   # room -> (axis, sign of the inward normal, plane coordinate beyond which the wall is the feature, texture)
    "LR": (0, +1, -39.0, "Fieldstone"),      # the west wall (faces east), behind the media console
    "BR2": (0, -1, 39.0, "Pine"),            # the bed wall on the east (faces west): knotty pine
}
FLOORS = {"FY": "Parquet", "CH": "Parquet", "BH": "LinoA", "MR": "LinoA", "LR": "CarpetGold", "GB": "HexTile", "DR": "LinoA",
          "KT": "LinoB", "LD": "CarpetGreige", "UH": "CarpetGreige", "MB": "CarpetGold", "EN": "HexTile", "BR2": "CarpetGreige",
          "BR3": "CarpetTiles", "UB": "HexTile"}
EXT_BASE = ("Fieldstone", 2.5, "SidingWhite")      # outside: fieldstone base course, white lap siding above
FLOOR_Z = {"G": 0.0, "U": 14.0, "R": 0.0}
TRIM = {   # name: (z from the floor (None = from the ceiling), height, depth)
    "base": (0.0, 0.5, 0.12), "chair": (3.0, 0.3, 0.18), "rail35": (3.35, 0.25, 0.16), "picture": (9.0, 0.15, 0.12),
    "plate": (8.0, 0.14, 0.42), "crown": (None, 0.5, 0.26),
}

SEGS = []      # wall pieces facing into rooms: dict(rid, ax, sg, plane, u0, u1, z0, z1, floor, ceil)


def poly_frame(poly):
    """for an axis-aligned vertical poly: (normal axis, sign, plane, u0, u1, z0, z1) or None"""
    a, b, c = poly[0], poly[1], poly[2]
    n = (b - a).cross(c - a)
    if n.length < 1e-9:
        return None
    n.normalize()
    if abs(n.z) > 0.5:
        return None
    ax = 0 if abs(n.x) > abs(n.y) else 1
    sg = 1 if n[ax] > 0 else -1
    ua = 1 - ax
    us = [p[ua] for p in poly]
    zs = [p.z for p in poly]
    return ax, sg, poly[0][ax], min(us), max(us), min(zs), max(zs)


def clip_z(poly, z, keep_below):
    out = []
    n = len(poly)
    for i in range(n):
        p, q = poly[i], poly[(i + 1) % n]
        pin = (p.z <= z + 1e-6) if keep_below else (p.z >= z - 1e-6)
        qin = (q.z <= z + 1e-6) if keep_below else (q.z >= z - 1e-6)
        if pin:
            out.append(p)
        if pin != qin:
            t = (z - p.z) / (q.z - p.z)
            out.append(p + (q - p) * t)
    clean = []
    for p in out:
        if not clean or (p - clean[-1]).length > 1e-6:
            clean.append(p)
    if len(clean) > 2 and (clean[0] - clean[-1]).length < 1e-6:
        clean.pop()
    return clean if len(clean) >= 3 else None


def split(mat, poly, storey, room_ceil):
    """resolve a ROOM:<id> / EXT wall material into (texture, poly) pieces; records room wall pieces for trims and wear"""
    if mat == "EXT":
        low, h, high = EXT_BASE
        zc = h
        rid = None
    elif mat.startswith("ROOM:"):
        rid = mat[5:]
        spec = ROOM_WALLS.get(rid)
        if not spec:
            return [("PaintCream", poly)]
        fr = poly_frame(poly)
        if fr and rid in FEATURE:
            ax, sg, plane, *_ = fr
            fa, fs, fp, ftex = FEATURE[rid]
            if ax == fa and sg == fs and ((plane < fp) if fs > 0 else (plane > fp)):
                _record(rid, fr, storey, room_ceil, feature=True)
                return [(ftex, poly)]
        low, h, high, _t = spec
        zc = FLOOR_Z[storey] + h
        if fr:
            _record(rid, fr, storey, room_ceil)
    else:
        return [(mat, poly)]
    out = []
    lo = clip_z(poly, zc, True)
    hi = clip_z(poly, zc, False)
    if lo:
        out.append((low, lo))
    if hi:
        out.append((high, hi))
    return out


def _record(rid, fr, storey, ceil, feature=False):
    ax, sg, plane, u0, u1, z0, z1 = fr
    SEGS.append(dict(rid=rid, ax=ax, sg=sg, plane=plane, u0=u0, u1=u1, z0=z0, z1=z1, floor=FLOOR_Z[storey], ceil=ceil, feature=feature))


def _merge(iv):
    iv = sorted(iv)
    out = []
    for a, b in iv:
        if out and a <= out[-1][1] + 1e-4:
            out[-1][1] = max(out[-1][1], b)
        else:
            out.append([a, b])
    return out


def trims(add_poly):
    """trim strips as closed prisms (front, top, bottom, ends; no back) in TrimWalnut. Returns the count."""
    groups = {}
    for s in SEGS:
        spec = ROOM_WALLS[s["rid"]][3]
        for t in spec:
            if t == "chair" and s["feature"]:
                continue
            zf, h, d = TRIM[t]
            za = (s["ceil"] - h) if zf is None else s["floor"] + zf
            zb = za + h
            if s["ax"] == 1:          # y-facing walls: stepped so corner trims never share a top / bottom plane
                zb += 0.03 if zf is not None else 0.0
                za -= 0.03 if zf is None else 0.0
                d += 0.02
            if not (s["z0"] <= za + 1e-4 and s["z1"] >= zb - 1e-4):
                continue
            key = (s["rid"], t, s["ax"], s["sg"], round(s["plane"], 3), round(za, 3), round(zb, 3), round(d, 3))
            groups.setdefault(key, []).append((s["u0"], s["u1"]))
    n = 0
    for (rid, t, ax, sg, plane, za, zb, d), iv in groups.items():
        storey = "G" if za < 13.5 else "U"
        for u0, u1 in _merge(iv):
            if u1 - u0 < 0.3:
                continue
            _prism(add_poly, ax, sg, plane, u0, u1, za, zb, d, crown=(t == "crown"), storey=storey)
            n += 1
    return n


def _prism(add_poly, ax, sg, plane, u0, u1, za, zb, d, crown, storey):
    ua = 1 - ax
    def P(u, w, z):            # u along the wall, w out of the wall (into the room), z up
        v = [0.0, 0.0, z]
        v[ua] = u
        v[ax] = plane + sg * w
        return Vector(v)
    # profile in (w, z): a plain strip, or a coved crown (wide at the ceiling, narrow at the bottom)
    if crown:
        prof = [(0.0, za), (0.08, za), (0.1, za + 0.12), (d * 0.55, za + 0.22), (d, zb - 0.06), (d, zb), (0.0, zb)]
    else:
        prof = [(0.0, za), (d, za), (d, zb - 0.04), (d - 0.04, zb), (0.0, zb)]
    m = len(prof)
    def orient(q, want):
        nn = (q[1] - q[0]).cross(q[2] - q[0])
        return q if nn.dot(want) > 0 else list(reversed(q))
    for i in range(m):
        (w0, z0), (w1, z1) = prof[i], prof[(i + 1) % m]
        if w0 < 1e-6 and w1 < 1e-6:
            continue                     # the back, against the wall
        if crown and abs(z0 - zb) < 1e-6 and abs(z1 - zb) < 1e-6:
            continue                     # the top of the crown, against the ceiling
        q = [P(u0, w0, z0), P(u1, w0, z0), P(u1, w1, z1), P(u0, w1, z1)]
        mid_w, mid_z = (w0 + w1) / 2, (z0 + z1) / 2
        out = Vector((0, 0, 0)); out[ax] = sg * (mid_w - d * 0.4); out.z = mid_z - (za + zb) / 2
        add_poly("TrimWalnut", orient(q, out if out.length > 1e-6 else Vector((0, 0, 1))), storey)
    for u, s_ in ((u0, -1), (u1, 1)):     # ends
        q = [P(u, w, z) for w, z in prof]
        want = Vector((0, 0, 0)); want[ua] = s_
        add_poly("TrimWalnut", orient(q, want), storey)


# ----------------------------------------------------------------------------------------------------------- wear layer
WEAR_CELLS = ["water_stain_a", "water_stain_b", "peel_corner", "peel_seam", "scorch_a", "scorch_b", "bullets_a", "bullets_b",
              "faded_rect", "chalk_marks_a", "chalk_marks_b", "floor_scuff", "sand_fan", "cobweb", "lino_crack", "dust_patch"]
WALL_PLAN = {   # room -> wear cells on its walls (each placed once on a random free wall piece)
    "FY": ["chalk_marks_a", "faded_rect", "bullets_a", "water_stain_b"], "CH": ["bullets_b", "faded_rect"],
    "BH": ["peel_seam", "chalk_marks_b"], "MR": ["scorch_a", "bullets_a"], "LR": ["peel_corner", "bullets_b", "faded_rect", "chalk_marks_b"],
    "DR": ["water_stain_a", "bullets_a", "peel_seam"], "KT": ["scorch_b", "chalk_marks_a", "bullets_b"], "GB": ["water_stain_b"],
    "LD": ["bullets_a", "faded_rect"], "UH": ["peel_corner"], "MB": ["peel_seam", "chalk_marks_a", "bullets_b", "scorch_a"],
    "BR2": ["peel_corner", "bullets_a", "faded_rect"], "BR3": ["water_stain_a", "chalk_marks_b"], "UB": ["peel_corner"],
}
FLOOR_PLAN = {"LR": ["floor_scuff", "dust_patch"], "DR": ["floor_scuff", "dust_patch"], "KT": ["lino_crack", "floor_scuff", "dust_patch"],
              "FY": ["floor_scuff", "dust_patch"], "BH": ["floor_scuff"], "MR": ["dust_patch"], "CH": ["floor_scuff"],
              "MB": ["dust_patch"], "BR2": ["dust_patch"], "BR3": ["floor_scuff"], "LD": ["floor_scuff"], "UH": ["dust_patch"]}
CEIL_PLAN = {"LR": ["water_stain_a"], "MB": ["water_stain_b"], "KT": ["water_stain_b"], "BR3": ["water_stain_a"]}
SIZE = {"water_stain_a": 3.2, "water_stain_b": 2.6, "peel_corner": 2.0, "peel_seam": 2.4, "scorch_a": 2.6, "scorch_b": 2.2,
        "bullets_a": 2.0, "bullets_b": 2.2, "faded_rect": 2.6, "chalk_marks_a": 2.4, "chalk_marks_b": 2.4, "floor_scuff": 4.0,
        "sand_fan": 3.0, "cobweb": 1.5, "lino_crack": 2.4, "dust_patch": 4.0}
OFF = 0.12


def _cell_uv(name, corner):
    i = WEAR_CELLS.index(name)
    cx, cy = i % 4, i // 4
    u = (cx + corner[0]) / 4.0
    v = 1.0 - (cy + 1 - corner[1]) / 4.0       # image row 0 is the top
    return (u, v)


def wear(rooms, room_rects, floor_z, ceil_z, blocked_floor, rng_seed=1965):
    """returns {storey: [(quad verts, uv corners)]}. blocked_floor(x, y, z, r) -> True where rugs / furniture sit"""
    rng = random.Random(rng_seed)
    out = {"G": [], "U": []}
    used = []
    def free(c, r):
        return all((c - q).length > r + rr for q, rr in used)
    for rid, cells in WALL_PLAN.items():
        segs = [s for s in SEGS if s["rid"] == rid and not s["feature"]]
        for cell in cells:
            S = SIZE[cell]
            for _try in range(60):
                s = rng.choice(segs) if segs else None
                if not s or s["u1"] - s["u0"] < S + 0.6:
                    continue
                zlo = s["floor"] + (3.7 if cell != "faded_rect" else 4.5)
                zhi = min(s["z1"], s["ceil"] - 0.8) - S
                if zhi < zlo or s["z0"] > zlo:
                    continue
                if cell.startswith("water") or cell.startswith("peel_corner"):
                    zlo = max(zlo, zhi - 1.0)        # stains and peeling high on the wall
                u = rng.uniform(s["u0"] + 0.3 + S / 2, s["u1"] - 0.3 - S / 2)
                z = rng.uniform(zlo, zhi)
                c = Vector((0, 0, z + S / 2)); c[1 - s["ax"]] = u; c[s["ax"]] = s["plane"] + s["sg"] * OFF
                if not free(c, S / 2):
                    continue
                used.append((c, S / 2))
                q = _wall_quad(s, u, z, S, S)
                st = "G" if s["floor"] < 1 else "U"
                out[st].append((q, cell))
                break
    for rid, cells in list(FLOOR_PLAN.items()) + [(r, ["__ceil__" + c for c in cs]) for r, cs in CEIL_PLAN.items()]:
        rm = rooms.get(rid)
        if not rm:
            continue
        for cell in cells:
            ceil = cell.startswith("__ceil__")
            cell = cell.replace("__ceil__", "")
            S = SIZE[cell]
            for _try in range(80):
                r = rng.choice(room_rects(rm))
                if r["x1"] - r["x0"] < S + 1 or r["y1"] - r["y0"] < S + 1:
                    continue
                if ceil:   # near a corner of the room
                    x = rng.choice((r["x0"] + 0.6 + S / 2, r["x1"] - 0.6 - S / 2)); y = rng.choice((r["y0"] + 0.6 + S / 2, r["y1"] - 0.6 - S / 2))
                    z = ceil_z(rm) - OFF
                else:
                    x = rng.uniform(r["x0"] + S / 2 + 0.5, r["x1"] - S / 2 - 0.5); y = rng.uniform(r["y0"] + S / 2 + 0.5, r["y1"] - S / 2 - 0.5)
                    z = floor_z(rm) + OFF
                    if blocked_floor(x, y, z, S / 2):
                        continue
                c = Vector((x, y, z))
                if not free(c, S / 2):
                    continue
                used.append((c, S / 2))
                a = rng.uniform(0, 2 * math.pi)
                q = [Vector((x + S / 2 * math.cos(a + k * math.pi / 2 + math.pi / 4) * math.sqrt(2), y + S / 2 * math.sin(a + k * math.pi / 2 + math.pi / 4) * math.sqrt(2), z)) for k in range(4)]
                if ceil:
                    q = list(reversed(q))
                    uvc = [(0, 0), (0, 1), (1, 1), (1, 0)]
                else:
                    uvc = [(0, 0), (1, 0), (1, 1), (0, 1)]
                out["G" if z < 13.5 else "U"].append((q, cell, uvc))
                break
    return out


def _wall_quad(s, u, z, w, h):
    ax, sg = s["ax"], s["sg"]
    ua = 1 - ax
    def P(uu, zz):
        v = [0.0, 0.0, zz]; v[ua] = uu; v[ax] = s["plane"] + sg * OFF
        return Vector(v)
    # right-hand: looking at the wall from the room, u increases to the right when (sg, ax) gives that orientation
    right = 1 if (ax == 1 and sg > 0) or (ax == 0 and sg < 0) else -1
    ul, ur = (u - w / 2, u + w / 2) if right < 0 else (u + w / 2, u - w / 2)
    return [P(ul, z), P(ur, z), P(ur, z + h), P(ul, z + h)]

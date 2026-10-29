"""House map, illusion pass: the world outside the windows (art only, no collision). One run rebuilds everything:
  python art/house/illusion/tools/make_tex.py
  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python art/house/illusion/tools/build_illusion.py -- [--part far,near,mid]
Conventions = art/house/v2 (build_exterior_1965.py): plan coordinates (x east, y north, z up), 1 unit = 1 stud, outside
ground z = -1, house floor z = 0, house walls x -40..40 / y -30..30 (outer faces at +-41 / +-31). FBX through hcore.export_fbx
(cm, Studio Import 3D at scale 0.01; Blender (x, y, z) -> Studio (-x, z, y)), K_ScaleCube (10 studs) + K_Marker in every file.
Every visible surface is textured (Import 3D keeps a TextureID), one material per object.
  fbx/X_Far.fbx   X_Skirt_* (desert ground ring 850 -> 4,000) + X_Mesa1_* (buttes / mesas 1,100-1,400) + X_Mesa2_* (ridges
                  1,800-2,200) + X_Mesa3_* (range 2,800-3,400), in plan place (origin = plan origin)
  fbx/X_Near.fbx  porch, back stoop, driveway, foundation strip, in plan place (origin = plan origin)
  fbx/X_Mid.fbx   one of each mid piece at the origin, pivot = bottom centre on the ground (z 0 = ground under it)
Writes house_illusion.json (manifest), house_illusion.blend, renders/."""
import os, sys, math, random, json
HERE = os.path.dirname(os.path.abspath(__file__))
IROOT = os.path.abspath(os.path.join(HERE, ".."))
V2TOOLS = os.path.abspath(os.path.join(IROOT, "..", "v2", "tools"))
sys.dont_write_bytecode = True     # importing the v2 helpers must not rewrite their tracked __pycache__
sys.path.insert(0, V2TOOLS)
import bpy, bmesh
from mathutils import Vector
import hcore
from hcore import coll, export_fbx, scale_cube_marker, tris, bbox, srgb, G, log
import build_house as bh          # tiled_object / tile_material / box_faces: the v2 tiles, same UV phase as the v2 exterior

ITEX = os.path.join(IROOT, "tex")
IFBX = os.path.join(IROOT, "fbx")
BLEND = os.path.join(IROOT, "house_illusion.blend")
REG = json.load(open(os.path.join(ITEX, "regions.json")))
ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
PARTS = (ARGV[ARGV.index("--part") + 1] if "--part" in ARGV else "far,near,mid").split(",")
GZ = -1.0
SIZE_CAP = 1900.0           # Roblox caps a MeshPart at 2,048 (work order: < 2,000); keep a margin
HAZE = (214, 196, 166)


# ------------------------------------------------------------------------------------------------------- mesh builder
def newell(pts):
    n = Vector()
    for i in range(len(pts)):
        a, b = pts[i], pts[(i + 1) % len(pts)]
        n.x += (a.y - b.y) * (a.z + b.z); n.y += (a.z - b.z) * (a.x + b.x); n.z += (a.x - b.x) * (a.y + b.y)
    return n


class Acc:
    """faces with per-corner UVs; face(pts, uvs, out) flips the winding so the normal points along `out`"""
    def __init__(s, name):
        s.name, s.faces = name, []

    def face(s, pts, uvs, out=None):
        pts = [Vector(p) for p in pts]
        uvs = list(uvs)
        if out is not None and newell(pts).dot(Vector(out)) < 0:
            pts, uvs = pts[::-1], uvs[::-1]
        if newell(pts).length < 1e-9:
            return
        s.faces.append((pts, uvs))


MATS = {}
def img_mat(name, alpha=False):
    if name in MATS:
        return MATS[name]
    m = bpy.data.materials.new(name)
    g = G(m)
    bsdf = g.n("ShaderNodeBsdfPrincipled")
    im = bpy.data.images.load(os.path.join(ITEX, name + ".png"), check_existing=True)
    t = g.n("ShaderNodeTexImage", image=im)
    g.put(t.inputs[0], g.uv("UVMap"))
    g.put(bsdf.inputs["Base Color"], t.outputs[0])
    bsdf.inputs["Roughness"].default_value = 0.9
    if alpha:
        g.put(bsdf.inputs["Alpha"], t.outputs[1])
        try:
            m.surface_render_method = "DITHERED"
        except Exception:
            pass
    out = g.n("ShaderNodeOutputMaterial"); g.put(out.inputs["Surface"], bsdf.outputs[0])
    MATS[name] = m
    return m


OBJS = {}     # name -> (object, meta)
def build(acc, mat, collection, open_shell=True, origin=(0, 0, 0), smooth_deg=35.0, alpha=False, meta=None):
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    vc = {}
    def V(p):
        k = (round(p.x, 4), round(p.y, 4), round(p.z, 4))
        if k not in vc:
            vc[k] = bm.verts.new(p - Vector(origin))
        return vc[k]
    for pts, uvs in acc.faces:
        vs, us = [], []
        for p, uv in zip(pts, uvs):
            v = V(p)
            if vs and v is vs[-1]:
                continue
            vs.append(v); us.append(uv)
        if len(vs) > 1 and vs[0] is vs[-1]:
            vs.pop(); us.pop()
        uvs = us
        if len(set(vs)) < 3:
            continue
        try:
            f = bm.faces.new(vs)
        except ValueError:
            continue
        for l, uv in zip(f.loops, uvs):
            l[uvl].uv = uv
    bm.normal_update()          # normals FIRST, then triangulate (A1c folded caps)
    bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="BEAUTY", ngon_method="BEAUTY")
    bm.normal_update()
    for f in bm.faces:
        f.smooth = True
    for e in bm.edges:
        e.smooth = len(e.link_faces) == 2 and e.calc_face_angle(math.pi) < math.radians(smooth_deg)
    me = bpy.data.meshes.new(acc.name)
    bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(acc.name, me)
    coll(collection).objects.link(ob)
    ob.location = origin
    me.materials.append(img_mat(mat, alpha))
    ob["open_shell"] = bool(open_shell)
    ob["atlas"] = mat
    OBJS[acc.name] = (ob, dict(meta or {}, collection=collection, material=mat, alpha=alpha, open_shell=bool(open_shell)))
    return ob


def tiled(name, mat, polys, collection, meta=None):
    ob = bh.tiled_object(name, mat, polys)
    for c in ob.users_collection:
        c.objects.unlink(ob)
    coll(collection).objects.link(ob)
    ob["atlas"] = "T_" + mat
    OBJS[name] = (ob, dict(meta or {}, collection=collection, material="T_" + mat, alpha=False,
                           texture=f"art/house/v2/tex/tile/T_{mat}.png (v2 tile, same image as the v2 exterior)"))
    return ob


def aabb(ob):
    lo, hi = bbox([ob])
    return lo, hi, hi - lo


# ------------------------------------------------------------------------------------------------------- atlas UVs
class Atlas:
    def __init__(s, key, size=1024):
        s.key, s.size = key, size
        s.rects = REG[key].get("rects", {})

    def uv(s, rect, fu, fv, band=0, band_h=0, inset=1.5):
        """fu, fv in 0..1 across the rect (fv 0 = rect bottom); rect in px, y down from the top"""
        x0, y0, x1, y1 = s.rects[rect] if isinstance(rect, str) else rect
        y0 += band * band_h; y1 += band * band_h
        fu = min(1.0, max(0.0, fu)); fv = min(1.0, max(0.0, fv))
        px = x0 + inset + (x1 - x0 - 2 * inset) * fu
        py = y1 - inset - (y1 - y0 - 2 * inset) * fv
        return (px / s.size, 1.0 - py / s.size)

    def pps(s, rect, a, b, pa, pb, band=0, band_h=0):
        """planar: a, b in studs from the rect's bottom-left, pa / pb px per stud"""
        x0, y0, x1, y1 = s.rects[rect]
        return s.uv(rect, a * pa / (x1 - x0), b * pb / (y1 - y0), band, band_h)


TOWN = Atlas("X_Town"); SITE = Atlas("X_Site"); NEAR = Atlas("X_Near")


# ------------------------------------------------------------------------------------------------------- generic shapes
def box_uv(acc, lo, hi, uvfn, skip=()):
    """axis box; uvfn(normal, point) -> uv. skip: subset of {'-x','+x','-y','+y','-z','+z'}"""
    x0, y0, z0 = lo; x1, y1, z1 = hi
    for n, quad in bh.box_faces(x0, x1, y0, y1, z0, z1):
        key = ("+" if max(n) > 0.5 else "-") + "xyz"[[abs(c) for c in n].index(1.0)]
        if key in skip:
            continue
        acc.face(quad, [uvfn(n, p) for p in quad], n)


def frame_of(p0, p1):
    d = (Vector(p1) - Vector(p0)).normalized()
    ref = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
    u = d.cross(ref).normalized(); w = d.cross(u).normalized()
    return d, u, w


def tube(acc, pts, r, sides, uvfn, caps=False, r_end=None):
    """polyline tube; uvfn(fu, fv) with fu round (0..1) and fv along (0..1)"""
    pts = [Vector(p) for p in pts]
    L = [0.0]
    for a, b in zip(pts, pts[1:]):
        L.append(L[-1] + (b - a).length)
    rings = []
    for i, p in enumerate(pts):
        a = pts[max(0, i - 1)]; b = pts[min(len(pts) - 1, i + 1)]
        d, u, w = frame_of(a, b) if (b - a).length > 1e-9 else frame_of(pts[0], pts[1])
        rr = r if r_end is None else r + (r_end - r) * (L[i] / L[-1])
        rings.append([p + (u * math.cos(2 * math.pi * k / sides) + w * math.sin(2 * math.pi * k / sides)) * rr for k in range(sides)])
    for i in range(len(pts) - 1):
        for k in range(sides):
            q = [rings[i][k], rings[i][(k + 1) % sides], rings[i + 1][(k + 1) % sides], rings[i + 1][k]]
            c = sum(q, Vector()) / 4
            axis_pt = (pts[i] + pts[i + 1]) / 2
            uvs = [uvfn(k / sides, L[i] / L[-1]), uvfn((k + 1) / sides, L[i] / L[-1]),
                   uvfn((k + 1) / sides, L[i + 1] / L[-1]), uvfn(k / sides, L[i + 1] / L[-1])]
            acc.face(q, uvs, c - axis_pt)
    if caps:
        for i, sg in ((0, -1), (len(pts) - 1, 1)):
            d = (pts[-1] - pts[0]).normalized() * sg
            acc.face(rings[i], [uvfn(0.5 + 0.5 * math.cos(2 * math.pi * k / sides), 0.5) for k in range(sides)], d)


def bar(acc, p0, p1, w, uvfn, caps=False):
    tube(acc, [p0, p1], w / math.sqrt(2), 4, uvfn, caps=caps)


# ------------------------------------------------------------------------------------------------------- FAR: skirt
def zs(r):
    """skirt height: -1.05 at the inner edge (just under the v2 1,800 square at -1), dropping 0.9 by r 1,000 so the
    overlap with the square never z-fights, then gently to -6 at 4,000"""
    t = min(1.0, max(0.0, (r - 850.0) / 150.0))
    return -1.05 - 0.9 * t * t * (3 - 2 * t) - 4.05 * min(1.0, max(0.0, (r - 1000.0) / 3000.0))


def dune(r, th):
    a = 1.4 * min(1.0, max(0.0, (r - 1300.0) / 700.0))
    return a * (0.6 * math.sin(3 * th + r / 260.0) + 0.4 * math.sin(7 * th - r / 410.0 + 1.3))


def skirt():
    A = 64
    bands = [[850, 900, 1000, 1150, 1400, 1700, 2000], [2000, 2350, 2700, 3000], [3000, 3500, 4000]]
    names = []
    def P(r, i):
        th = 2 * math.pi * i / A
        z = zs(r) + (dune(r, th) if r not in (850, 4000) else 0.0)
        return Vector((r * math.cos(th), r * math.sin(th), z))
    def UV(r, i):
        v = math.sqrt((r - 850.0) / 3150.0)
        return (12.0 * i / A, 0.003 + 0.994 * v)
    for bi, rings in enumerate(bands):
        for nseg in (4, 8, 16, 32, 64):
            ok = True
            for s in range(nseg):
                i0, i1 = s * A // nseg, (s + 1) * A // nseg
                pts = [P(r, i) for r in rings for i in range(i0, i1 + 1)]
                ext = max(max(p[k] for p in pts) - min(p[k] for p in pts) for k in range(2))
                ok &= ext < SIZE_CAP
            if ok:
                break
        for s in range(nseg):
            i0, i1 = s * A // nseg, (s + 1) * A // nseg
            acc = Acc(f"X_Skirt_{bi + 1}_{s + 1:02d}")
            for a, b in zip(rings, rings[1:]):
                for i in range(i0, i1):
                    q = [P(a, i), P(a, i + 1), P(b, i + 1), P(b, i)]
                    acc.face(q, [UV(a, i), UV(a, i + 1), UV(b, i + 1), UV(b, i)], (0, 0, 1))
            build(acc, "X_Ground", "Far", open_shell=True, smooth_deg=60, meta=dict(piece="X_GroundSkirt"))
            names.append(acc.name)
    return names


# ------------------------------------------------------------------------------------------------------- FAR: mesa ring
def periodic(rng, ks, power=0.9):
    ph = [rng.uniform(0, 2 * math.pi) for _ in ks]
    am = [rng.uniform(0.6, 1.0) / (k ** power) for k in ks]
    return lambda th: sum(a * math.sin(k * th + p) for a, p, k in zip(am, ph, ks))


def tier_band(tier):
    r0, r1 = REG["X_Mesa"][f"tier{tier}"]["rows"]
    return (1.0 - (r1 - 3) / 1024.0, 1.0 - (r0 + 3) / 1024.0)


ZLO = -30.0
ZHI = {1: 195.0, 2: 330.0, 3: 530.0}


def mesa_v(tier, z):
    v0, v1 = tier_band(tier)
    t = min(1.0, max(0.0, (z - ZLO) / (ZHI[tier] - ZLO)))
    return v0 + (v1 - v0) * t


def ring_tier(tier, R, w_in, hmin, hmax, A, nseg, seed, tile_u):
    """a continuous ridge band round the full circle (no ends), seen from the centre: foot sunk 15 under the skirt,
    a talus break, a shoulder and a jagged ridge line. Only the inward faces exist (open shell)."""
    rng = random.Random(seed)
    fh = periodic(rng, [2, 3, 5, 7, 11, 13, 19, 29, 37])
    fr = periodic(rng, [2, 5, 9, 14])
    hs = [fh(2 * math.pi * i / A) + rng.uniform(-0.06, 0.06) for i in range(A)]
    lo_, hi_ = min(hs), max(hs)
    H = [hmin + (hmax - hmin) * ((h - lo_) / (hi_ - lo_)) ** 1.15 for h in hs]
    rr = [R + 60.0 * fr(2 * math.pi * i / A) / 1.2 for i in range(A)]
    jit = [(rng.uniform(-18, 18), rng.uniform(-0.05, 0.05), rng.uniform(-0.06, 0.06)) for i in range(A)]
    nrep = max(1, round(2 * math.pi * R / tile_u))
    def prof(i):
        i %= A
        th = 2 * math.pi * i / A
        c, s = math.cos(th), math.sin(th)
        h, r, (jr, j1, j2) = H[i], rr[i], jit[i]
        rf = r - w_in
        pts = [(rf, zs(rf) - 15.0), (r - w_in * 0.62 + jr, h * (0.2 + j1)), (r - w_in * 0.24 + jr * 0.5, h * (0.72 + j2)), (r, h)]
        return [Vector((rad * c, rad * s, z)) for rad, z in pts]
    names = []
    per = A // nseg
    for sg in range(nseg):
        acc = Acc(f"X_Mesa{tier}_{sg + 1:02d}")
        for i in range(sg * per, (sg + 1) * per):
            a, b = prof(i), prof(i + 1)
            ua, ub = nrep * i / A, nrep * (i + 1) / A
            th = 2 * math.pi * (i + 0.5) / A
            inward = Vector((-math.cos(th), -math.sin(th), 0.25))
            for k in range(3):
                q = [a[k], b[k], b[k + 1], a[k + 1]]
                acc.face(q, [(ua, mesa_v(tier, a[k].z)), (ub, mesa_v(tier, b[k].z)), (ub, mesa_v(tier, b[k + 1].z)), (ua, mesa_v(tier, a[k + 1].z))], inward)
        ob = build(acc, "X_Mesa", "Far", open_shell=True, smooth_deg=50, meta=dict(piece="X_MesaRing", tier=tier))
        names.append(acc.name)
    return names, H


# landform profiles: (outline scale, height fraction) per ring above the sunk base; the last ring is the rim
PROFILES = {
    "mesa":    [(0.84, 0.24), (0.72, 0.36), (0.64, 1.0)],
    "stepped": [(0.86, 0.2), (0.76, 0.32), (0.74, 0.56), (0.52, 0.64), (0.46, 1.0)],
    "butte":   [(0.74, 0.26), (0.52, 0.38), (0.44, 1.0)],
    "cone":    [(0.72, 0.3), (0.45, 0.72), (0.2, 1.0)],
    "twin":    [(0.82, 0.24), (0.7, 0.4), (0.6, 1.0)],
}
KIND_SIZE = {"mesa": ((140, 260), (80, 160), (65, 125)), "stepped": ((160, 300), (90, 160), (90, 150)),
             "butte": ((45, 100), (40, 85), (120, 180)), "cone": ((90, 170), (80, 150), (60, 115)),
             "twin": ((180, 300), (80, 140), (85, 150))}


def mesas_tier1():
    """buttes, mesas and eroded hills 1,100-1,400 from the centre with gaps between them (tier 2 shows through): closed
    solids, foot sunk 12 under the skirt, five landform profiles, rims tilted, notched and jittered (no straight top
    edge), no two alike (kind, size, profile and rim all random per piece)"""
    rng = random.Random(1101)
    th0 = rng.uniform(0, 2 * math.pi)
    th = th0
    specs = []
    bag = []
    while len(specs) < 24:
        if not bag:
            bag = ["mesa", "mesa", "stepped", "butte", "butte", "cone", "twin"]
            rng.shuffle(bag)
        kind = bag.pop()
        (w0, w1), (d0, d1), (h0, h1) = KIND_SIZE[kind]
        w, d, h = rng.uniform(w0, w1), rng.uniform(d0, d1), rng.uniform(h0, h1)
        R = rng.uniform(1180, 1320)
        half = (w / 2) / R
        if specs and th + 2 * half > th0 + 2 * math.pi - 0.08:
            break
        specs.append(dict(kind=kind, w=w, d=d, h=h, R=R, th=th + half, rot=rng.uniform(-0.4, 0.4), seed=rng.randrange(1 << 30)))
        th += 2 * half + rng.uniform(0.08, 0.2)      # the gap to the next one (tier 2 shows through)
    shapes = []
    for m in specs:
        r2 = random.Random(m["seed"])
        N = 12
        cx, cy = m["R"] * math.cos(m["th"]), m["R"] * math.sin(m["th"])
        t = Vector((-math.sin(m["th"]), math.cos(m["th"]), 0)); n = Vector((math.cos(m["th"]), math.sin(m["th"]), 0))
        cr, sr = math.cos(m["rot"]), math.sin(m["rot"])
        rad = [1.0 + r2.uniform(-0.14, 0.14) for _ in range(N)]
        ex = {"mesa": 2.8, "stepped": 2.6, "twin": 2.6}.get(m["kind"], 2.0)
        tilt = r2.uniform(-0.14, 0.14)
        notch = r2.randrange(N); notch_d = r2.uniform(0.12, 0.3)
        def outline(scale, jit):
            out = []
            for k in range(N):
                a = 2 * math.pi * k / N + r2.uniform(-0.08, 0.08)
                ca, sa = math.cos(a), math.sin(a)
                sx = math.copysign(abs(ca) ** (2 / ex), ca); sy = math.copysign(abs(sa) ** (2 / ex), sa)
                u = sx * m["w"] / 2 * scale * rad[k] * (1 + r2.uniform(-jit, jit))
                v = sy * m["d"] / 2 * scale * rad[k] * (1 + r2.uniform(-jit, jit))
                out.append((Vector((cx, cy, 0)) + t * (u * cr - v * sr) + n * (u * sr + v * cr), u, k))
            return out
        def ring_z(frac, u, k, last):
            z = m["h"] * frac * (1 + tilt * u / (m["w"] / 2))
            if last:
                z *= 1 + r2.uniform(-0.07, 0.07)
                if k == notch or (k - 1) % N == notch:
                    z *= 1 - notch_d                                                   # a broken caprock
                if m["kind"] == "twin":
                    z *= 1.0 - 0.32 * math.exp(-(u / (m["w"] * 0.1)) ** 2)            # a saddle between two tops
            else:
                z *= 1 + r2.uniform(-0.12, 0.12)
            return min(z, 176.0)                     # tier 1 stays inside the brief's 60-180
        base = [Vector((p.x, p.y, zs(math.hypot(p.x, p.y)) - 12.0)) for p, u, k in outline(1.0, 0.05)]
        lv = [base]
        prof = PROFILES[m["kind"]]
        for j, (scale, frac) in enumerate(prof):
            last = j == len(prof) - 1
            lv.append([Vector((p.x, p.y, ring_z(frac, u, k, last))) for p, u, k in outline(scale, 0.04 if not last else 0.06)])
        dome = {"cone": 0.07, "butte": 0.04}.get(m["kind"], 0.015)
        cap = sum(lv[-1], Vector()) / N
        cap.z = min(180.0, max(p.z for p in lv[-1]) + m["h"] * dome)
        shapes.append(dict(spec=m, lv=lv, cap=cap))
    # group neighbours into segments (< SIZE_CAP on each axis)
    groups, cur = [], []
    for sh in shapes:
        trial = cur + [sh]
        pts = [p for s in trial for ring in s["lv"] for p in ring]
        ext = max(max(p[k] for p in pts) - min(p[k] for p in pts) for k in range(2))
        if cur and (ext > 900.0 or len(cur) >= 2):
            groups.append(cur); cur = [sh]
        else:
            cur = trial
    if cur:
        groups.append(cur)
    names = []
    for gi, grp in enumerate(groups):
        acc = Acc(f"X_Mesa1_{gi + 1:02d}")
        for sh in grp:
            lv, c = sh["lv"], Vector((sh["spec"]["R"] * math.cos(sh["spec"]["th"]), sh["spec"]["R"] * math.sin(sh["spec"]["th"]), 0))
            N = len(lv[0])
            per = [0.0]
            for k in range(N):
                per.append(per[-1] + (lv[1][(k + 1) % N] - lv[1][k]).length)
            tile = per[-1] / max(1, round(per[-1] / 260.0))
            for L in range(len(lv) - 1):
                for k in range(N):
                    k2 = (k + 1) % N
                    q = [lv[L][k], lv[L][k2], lv[L + 1][k2], lv[L + 1][k]]
                    out = (sum(q, Vector()) / 4) - Vector((c.x, c.y, (q[0].z + q[2].z) / 2))
                    uvs = [(per[k] / tile, mesa_v(1, q[0].z)), (per[k + 1] / tile, mesa_v(1, q[1].z)),
                           (per[k + 1] / tile, mesa_v(1, q[2].z)), (per[k] / tile, mesa_v(1, q[3].z))]
                    acc.face(q, uvs, out)
            for k in range(N):
                k2 = (k + 1) % N
                tri_ = [lv[-1][k], lv[-1][k2], sh["cap"]]
                acc.face(tri_, [(p.x / 260.0, mesa_v(1, p.z)) for p in tri_], (0, 0, 1))
            acc.face(list(reversed(lv[0])), [(p.x / 260.0, mesa_v(1, p.z)) for p in reversed(lv[0])], (0, 0, -1))
        build(acc, "X_Mesa", "Far", open_shell=False, smooth_deg=50, meta=dict(piece="X_MesaRing", tier=1,
              shapes=[dict(kind=s["spec"]["kind"], w=round(s["spec"]["w"]), d=round(s["spec"]["d"]), h=round(s["spec"]["h"]),
                           R=round(s["spec"]["R"]), deg=round(math.degrees(s["spec"]["th"]) % 360, 1)) for s in grp]))
        names.append(acc.name)
    return names, specs


def far():
    out = dict(skirt=skirt())
    m1, specs = mesas_tier1()
    m2, H2 = ring_tier(2, 2050.0, 250.0, 150.0, 320.0, 144, 12, 2202, 520.0)
    m3, H3 = ring_tier(3, 3200.0, 350.0, 250.0, 520.0, 144, 12, 3303, 720.0)
    out.update(mesa1=m1, mesa2=m2, mesa3=m3)
    return out


# ------------------------------------------------------------------------------------------------------- NEAR
def near():
    """porch + canopy, back stoop + rail / mat / crate, driveway slab, gravel foundation strip. Each piece CONTAINS the
    v2 house's own step / canopy boxes (H_House Shell_R: front step x -1.5..7.5 y -34..-31 z -1..0, canopy x -1.5..8
    y -35.5..-30.98 z 11.2..11.8, back step x -7.5..1.5 y 31..34 z -1..0) with >= 0.13 margin, so those are buried
    whether or not the installer hides them, and sits >= 0.13 above the v2 exterior's yard slabs (top -0.82 / -0.75)."""
    names = []
    P = {}
    def add(mat, lo, hi, skip=("-z",)):
        for n, quad in bh.box_faces(lo[0], hi[0], lo[1], hi[1], lo[2], hi[2]):
            key = ("+" if max(n) > 0.5 else "-") + "xyz"[[abs(c) for c in n].index(1.0)]
            if key in skip:
                continue
            P.setdefault(mat, []).append(quad)
    # front porch: stoop slab, 2 steps down to the v2 path (top -0.82), two posts, a flat canopy
    add("Concrete65", (-3.0, -34.3, -1.1), (9.0, -30.95, 0.15), skip=("-z", "+y"))
    add("Concrete65", (-2.0, -35.15, -1.1), (8.0, -34.3, -0.17), skip=("-z", "+y"))
    add("Concrete65", (-2.0, -36.0, -1.1), (8.0, -35.15, -0.50), skip=("-z", "+y"))
    for px in (-2.55, 8.55):
        add("TrimWhite", (px - 0.225, -34.075, 0.10), (px + 0.225, -33.625, 10.95), skip=("-z", "+z"))
    for n, quad in bh.box_faces(-3.2, 9.2, -36.2, -30.95, 10.9, 12.0):
        if n.y > 0.5:
            continue
        P.setdefault("Shingle" if n.z > 0.5 else "TrimWhite", []).append(quad)
    for mat, polys in P.items():
        names.append(tiled(f"X_PorchFront_{mat}", mat, polys, "Near", meta=dict(piece="X_PorchFront")).name)
    P.clear()
    # back stoop
    add("Concrete65", (-7.65, 30.95, -1.1), (1.65, 34.3, 0.15), skip=("-z", "-y"))
    add("Concrete65", (-7.0, 34.3, -1.1), (1.0, 35.15, -0.15), skip=("-z", "-y"))
    add("Concrete65", (-7.0, 35.15, -1.1), (1.0, 36.0, -0.45), skip=("-z", "-y"))
    for mat, polys in P.items():
        names.append(tiled(f"X_BackStoop_{mat}", mat, polys, "Near", meta=dict(piece="X_BackStoop")).name)
    P.clear()
    acc = Acc("X_BackStoop_Props")
    iron = lambda fu, fv: NEAR.uv("iron", fu, fv)
    rx = -7.3
    for (y, z0, z1) in ((31.4, 0.10, 3.3), (34.0, 0.10, 3.3), (35.6, -0.50, 2.55)):
        bar(acc, (rx, y, z0), (rx, y, z1), 0.16, iron, caps=True)
    bar(acc, (rx, 31.3, 3.3), (rx, 34.0, 3.3), 0.12, iron, caps=True)
    bar(acc, (rx, 34.0, 3.3), (rx, 35.7, 2.5), 0.12, iron, caps=True)
    bar(acc, (rx, 31.4, 1.7), (rx, 34.0, 1.7), 0.08, iron, caps=True)
    bar(acc, (rx, 34.0, 1.7), (rx, 35.6, 0.95), 0.08, iron, caps=True)
    # doormat (top 0.14 over the slab, bottom sunk 0.03) and a wooden milk crate
    def mat_uv(n, p):
        if n.z > 0.5:
            return NEAR.uv("mat", (p.x + 4.6) / 3.2, (p.y - 31.15) / 2.0)
        return NEAR.uv("mat", 0.02, 0.5)
    box_uv(acc, (-4.6, 31.15, 0.12), (-1.4, 33.15, 0.29), mat_uv, skip=("-z",))
    def crate_uv(n, p):
        lo, hi = Vector((0.15, 31.25, 0.12)), Vector((1.45, 32.55, 1.17))
        if n.z > 0.5:
            return NEAR.uv("crate_top", (p.x - lo.x) / 1.3, (p.y - lo.y) / 1.3)
        if abs(n.y) > 0.5:
            a = (p.x - lo.x) if n.y < 0 else (hi.x - p.x)          # text reads left-to-right on every side
        else:
            a = (p.y - lo.y) if n.x > 0 else (hi.y - p.y)
        return NEAR.uv("crate", a / 1.3, (p.z - lo.z) / 1.05)
    box_uv(acc, (0.15, 31.25, 0.12), (1.45, 32.55, 1.17), crate_uv, skip=("-z",))
    names.append(build(acc, "X_Near", "Near", open_shell=True, meta=dict(piece="X_BackStoop")).name)
    # driveway: cracked slab, top 0.13 over the v2 slab (-0.82), into the wall 0.05
    acc = Acc("X_Driveway")
    dp = REG["X_Near"]["drive_plan"]
    def dr_uv(n, p):
        if n.z > 0.5:
            return NEAR.uv("drive", (p.x - 15.9) / 14.2, 1.0 - (-30.95 - p.y) / 25.15)
        a = (p.x - 15.9) / 14.2 if abs(n.y) > 0.5 else (-30.95 - p.y) / 25.15
        return NEAR.uv("drive_edge", a, (p.z + 1.1) / 0.41)
    box_uv(acc, (15.9, -56.1, -1.1), (30.1, -30.95, -0.69), dr_uv, skip=("-z", "+y"))
    names.append(build(acc, "X_Near", "Near", open_shell=True, meta=dict(piece="X_Driveway")).name)
    # gravel / soil strip round the house foot: mitred ring, inner edge 0.05 inside the wall, top -0.72 at the wall
    # falling to -0.92 at 1.5 out (under the v2 dry lawn -0.85 by ~1 out), outer face to -1.1; breaks at the porch,
    # the driveway and the v2 back patio (x -14..16), each end 0.08 into its neighbour
    xi, yi, xo, yo = 40.95, 30.95, 42.45, 32.45
    zin, zout, zb = -0.72, -0.92, -1.1
    def st(x, y, side):
        if side == "S":
            return (Vector((x, -yi, zin)), Vector((x, -yo, zout)))
        if side == "N":
            return (Vector((x, yi, zin)), Vector((x, yo, zout)))
        if side == "E":
            return (Vector((xi, y, zin)), Vector((xo, y, zout)))
        return (Vector((-xi, y, zin)), Vector((-xo, y, zout)))
    cS = lambda sx: (Vector((sx * xi, -yi, zin)), Vector((sx * xo, -yo, zout)))
    cN = lambda sx: (Vector((sx * xi, yi, zin)), Vector((sx * xo, yo, zout)))
    runs = [
        [st(30.02, 0, "S"), cS(1), cN(1), st(15.92, 0, "N")],
        [st(-13.92, 0, "N"), cN(-1), cS(-1), st(-2.92, 0, "S")],
        [st(8.92, 0, "S"), st(15.98, 0, "S")],
    ]
    polys = []
    for run in runs:
        for (i0, o0), (i1, o1) in zip(run, run[1:]):
            polys.append(_up([i0, i1, o1, o0]))
            polys.append(_facing([o0, o1, o1 + Vector((0, 0, zb - zout)), o0 + Vector((0, 0, zb - zout))], (o0 + o1) / 2 - (i0 + i1) / 2))
        for (ii, oo), sgn in ((run[0], -1), (run[-1], 1)):
            nxt = run[1] if sgn < 0 else run[-2]
            d = (ii - nxt[0]).normalized()
            cap = [Vector((ii.x, ii.y, zb)), ii, oo, Vector((oo.x, oo.y, zb))]
            polys.append(_facing(cap, d))
    names.append(tiled("X_FoundationStrip_Gravel65", "Gravel65", polys, "Near", meta=dict(piece="X_Driveway (foundation strip)")).name)
    return names


def _up(q):
    return q if newell(q).z > 0 else list(reversed(q))


def _facing(q, d):
    return q if newell(q).dot(Vector(d)) > 0 else list(reversed(q))


# ------------------------------------------------------------------------------------------------------- MID: town houses
def wall(acc, band, axis, line, sgn, a0, a1, zb, zt, opens, atlas=TOWN, d=0.45, frame=0.35, proud=0.13):
    """one outward wall plane (axis 'x': runs along x at y = line, outward = sgn*y; 'y': along y at x = line) minus its
    openings (real holes), each opening with reveals back to dark glass / a door leaf, and a proud white frame ring"""
    B = dict(band=band, band_h=256)
    def P(a, z, off=0.0):
        return Vector((a, line + sgn * off, z)) if axis == "x" else Vector((line + sgn * off, a, z))
    out = Vector((0, sgn, 0)) if axis == "x" else Vector((sgn, 0, 0))
    sid = lambda a, z: atlas.pps("siding", a - a0 + 1.0, z, 8, 8, **B)
    cuts = sorted({a0, a1} | {v for o in opens for v in (o[0], o[1])})
    for ca, cb in zip(cuts, cuts[1:]):
        am = (ca + cb) / 2
        zs_ = [(zb, zt)]
        for o in opens:
            if o[0] < am < o[1]:
                new = []
                for (p, q) in zs_:
                    if o[3] <= p or o[2] >= q:
                        new.append((p, q)); continue
                    if o[2] > p: new.append((p, o[2]))
                    if o[3] < q: new.append((o[3], q))
                zs_ = new
        for (p, q) in zs_:
            quad = [P(ca, p), P(cb, p), P(cb, q), P(ca, q)]
            acc.face(quad, [sid(ca, p), sid(cb, p), sid(cb, q), sid(ca, q)], out)
    trim = lambda fu, fv: atlas.uv("trim", fu, fv, **B)
    for o in opens:
        oa, ob, oz0, oz1 = o[:4]
        kind = o[4] if len(o) > 4 else "win"
        back = "glass" if kind == "win" else "door"
        acc.face([P(oa, oz0, -d), P(ob, oz0, -d), P(ob, oz1, -d), P(oa, oz1, -d)],
                 [atlas.uv(back, 0, 0, **B), atlas.uv(back, 1, 0, **B), atlas.uv(back, 1, 1, **B), atlas.uv(back, 0, 1, **B)], out)
        # reveals from the proud frame face back to the glass (jambs, head, sill)
        sides = [((oa, oz0), (oa, oz1), Vector((1, 0, 0)) if axis == "x" else Vector((0, 1, 0))),
                 ((ob, oz1), (ob, oz0), -(Vector((1, 0, 0)) if axis == "x" else Vector((0, 1, 0)))),
                 ((oa, oz1), (ob, oz1), Vector((0, 0, -1)))]
        if kind == "win":
            sides.append(((ob, oz0), (oa, oz0), Vector((0, 0, 1))))
        for (p0, p1, nrm) in sides:
            q = [P(*p0, proud), P(*p1, proud), P(*p1, -d), P(*p0, -d)]
            acc.face(q, [trim(0, 0), trim(1, 0), trim(1, 1), trim(0, 1)], nrm)
        # frame ring (front faces + outer edges)
        fa, fb, fz0, fz1 = oa - frame, ob + frame, (oz0 - frame if kind == "win" else oz0), oz1 + frame
        rings = [((fa, fz0), (oa, fz0), (oa, fz1), (fa, fz1)), ((ob, fz0), (fb, fz0), (fb, fz1), (ob, fz1)),
                 ((oa, oz1), (ob, oz1), (ob, fz1), (oa, fz1))]
        if kind == "win":
            rings.append(((oa, fz0), (ob, fz0), (ob, oz0), (oa, oz0)))
        for r_ in rings:
            acc.face([P(a, z, proud) for a, z in r_], [trim(0, 0), trim(1, 0), trim(1, 1), trim(0, 1)], out)
        edges = [((fa, fz0), (fa, fz1)), ((fb, fz1), (fb, fz0)), ((fa, fz1), (fb, fz1))]
        if kind == "win":
            edges.append(((fb, fz0), (fa, fz0)))
        for (p0, p1) in edges:
            q = [P(*p0, 0.0), P(*p1, 0.0), P(*p1, proud), P(*p0, proud)]
            c = sum(q, Vector()) / 4
            ctr = P((oa + ob) / 2, (oz0 + oz1) / 2, proud / 2)
            acc.face(q, [trim(0, 0), trim(1, 0), trim(1, 0.2), trim(0, 0.2)], c - ctr)


def gable_roof(acc, band, W, D, zeave, rise, over=1.5, t=0.5, atlas=TOWN):
    B = dict(band=band, band_h=256)
    s = rise / (D / 2)
    xa, xb = -(W / 2 + over), W / 2 + over
    ye = D / 2 + over
    ze = zeave - over * s
    zr = zeave + rise
    L = math.hypot(ye, zr - ze)
    roof = lambda x, l: atlas.pps("roof", x - xa + 0.5, l + 0.5, 8, 8, **B)
    trim = lambda fu, fv: atlas.uv("trim", fu, fv, **B)
    for sg in (-1, 1):
        top = [Vector((xa, sg * ye, ze + t)), Vector((xb, sg * ye, ze + t)), Vector((xb, 0, zr + t)), Vector((xa, 0, zr + t))]
        acc.face(top, [roof(xa, 0), roof(xb, 0), roof(xb, L), roof(xa, L)], (0, sg * 0.5, 1))
        bot = [Vector((xa, sg * ye, ze)), Vector((xb, sg * ye, ze)), Vector((xb, 0, zr)), Vector((xa, 0, zr))]
        acc.face(bot, [trim(0, 0), trim(1, 0), trim(1, 1), trim(0, 1)], (0, -sg * 0.3, -1))
        fas = [Vector((xa, sg * ye, ze)), Vector((xb, sg * ye, ze)), Vector((xb, sg * ye, ze + t)), Vector((xa, sg * ye, ze + t))]
        acc.face(fas, [trim(0, 0), trim(1, 0), trim(1, 0.3), trim(0, 0.3)], (0, sg, 0))
        for x, sx in ((xa, -1), (xb, 1)):
            rk = [Vector((x, sg * ye, ze)), Vector((x, 0, zr)), Vector((x, 0, zr + t)), Vector((x, sg * ye, ze + t))]
            acc.face(rk, [trim(0, 0), trim(1, 0), trim(1, 0.3), trim(0, 0.3)], (sx, 0, 0))
    for x, sx in ((-W / 2, -1), (W / 2, 1)):
        tri_ = [Vector((x, -D / 2, zeave)), Vector((x, D / 2, zeave)), Vector((x, 0, zr + 0.1))]
        sid = lambda p: atlas.pps("siding", p.y + D / 2 + 1, p.z - zeave + 13.0, 8, 8, **B)
        acc.face(tri_, [sid(p) for p in tri_], (sx, 0, 0))


def plinth(acc, band, W, D, ztop, atlas=TOWN, over=0.25):
    B = dict(band=band, band_h=256)
    x0, x1, y0, y1 = -W / 2 - over, W / 2 + over, -D / 2 - over, D / 2 + over
    def uvf(n, p):
        if n.z > 0.5:
            return atlas.uv("concrete", (p.x - x0) / (x1 - x0), (p.y - y0) / (y1 - y0), **B)
        a = (p.x - x0) if abs(n.y) > 0.5 else (p.y - y0)
        return atlas.pps("stone", a, p.z + 0.6, 8, 8, **B)
    box_uv(acc, (x0, y0, -0.6), (x1, y1, ztop), uvf, skip=("-z",))


def chimney(acc, band, x0, x1, y0, y1, z1, atlas=TOWN):
    B = dict(band=band, band_h=256)
    def uvf(n, p):
        if n.z > 0.5:
            return atlas.uv("dark", 0.5, 0.5, **B)
        a = (p.x - x0) if abs(n.y) > 0.5 else (p.y - y0)
        return atlas.pps("stone", p.z + 0.6, a, 8, 8, **B)      # stones turned 90 degrees (the region is long and low)
    box_uv(acc, (x0, y0, -0.6), (x1, y1, z1), uvf, skip=("-z", "-x" if x0 > 0 else "+x"))


def concrete_box(acc, band, lo, hi, atlas=TOWN):
    B = dict(band=band, band_h=256)
    def uvf(n, p):
        fx = (p.x - lo[0]) / (hi[0] - lo[0]); fy = (p.y - lo[1]) / (hi[1] - lo[1]); fz = (p.z - lo[2]) / (hi[2] - lo[2])
        if n.z > 0.5:
            return atlas.uv("concrete", fx, fy, **B)
        return atlas.uv("concrete", fx if abs(n.y) > 0.5 else fy, fz * 0.3, **B)
    box_uv(acc, lo, hi, uvf, skip=("-z",))


BANDS = REG["X_Town"]["bands"]


def town_house_A(band):
    acc = Acc(f"X_TownHouse_A_{BANDS[band]}")
    W, D, zb, ze, rise = 40.0, 26.0, 1.6, 10.4, 3.0
    plinth(acc, band, W, D, zb)
    wall(acc, band, "x", -D / 2, -1, -W / 2, W / 2, zb, ze, [(-15, -6, 4.0, 8.6), (-3.5, 0.0, zb, 8.6, "door"), (3, 7, 4.4, 8.6), (11, 16, 4.4, 8.6)])
    wall(acc, band, "x", D / 2, 1, -W / 2, W / 2, zb, ze, [(-16, -11, 4.4, 8.6), (-6, -2, 4.4, 8.6), (6, 9, 6.0, 8.6), (12, 17, 4.4, 8.6)])
    wall(acc, band, "y", -W / 2, -1, -D / 2, D / 2, zb, ze, [(5, 9, 4.4, 8.6)])
    wall(acc, band, "y", W / 2, 1, -D / 2, D / 2, zb, ze, [(-3, 3, 4.4, 8.6)])
    gable_roof(acc, band, W, D, ze, rise)
    chimney(acc, band, -W / 2 - 2.6, -W / 2 + 0.2, -6.5, -3.5, ze + rise + 2.2)
    concrete_box(acc, band, (-4.5, -D / 2 - 2.4, -0.6), (1.0, -D / 2 - 0.2, 0.9))
    return acc


def town_house_B(band):
    acc = Acc(f"X_TownHouse_B_{BANDS[band]}")
    W, D, zb, ze, rise = 36.0, 28.0, 1.6, 21.4, 2.1
    plinth(acc, band, W, D, zb)
    wall(acc, band, "x", -D / 2, -1, -W / 2, W / 2, zb, ze, [(-2, 1.5, zb, 8.6, "door"), (-14, -8, 4.4, 8.8), (7, 13, 4.4, 8.8),
                                                            (-14, -9, 14.4, 19.0), (-2.5, 2.5, 14.4, 19.0), (9, 14, 14.4, 19.0)])
    wall(acc, band, "x", D / 2, 1, -W / 2, W / 2, zb, ze, [(-12, -7, 4.4, 8.8), (5, 11, 4.4, 8.8), (-13, -8, 14.4, 19.0), (8, 13, 14.4, 19.0)])
    wall(acc, band, "y", -W / 2, -1, -D / 2, D / 2, zb, ze, [(-3, 3, 14.4, 19.0)])
    wall(acc, band, "y", W / 2, 1, -D / 2, D / 2, zb, ze, [(-3, 3, 4.4, 8.8), (-3, 3, 14.4, 19.0)])
    gable_roof(acc, band, W, D, ze, rise, over=1.2)
    chimney(acc, band, -W / 2 - 2.6, -W / 2 + 0.2, 4.0, 7.0, ze + rise + 2.0)
    B = dict(band=band, band_h=256)
    box_uv(acc, (-3.6, -D / 2 - 2.8, 9.5), (3.1, -D / 2 + 0.05, 10.0), lambda n, p: TOWN.uv("trim", 0.5, 0.5, **B))   # door hood
    concrete_box(acc, band, (-3.4, -D / 2 - 2.4, -0.6), (2.9, -D / 2 - 0.2, 0.9))
    return acc


# ------------------------------------------------------------------------------------------------------- MID: test site
def region_uv(rect, atlas=SITE):
    return lambda fu, fv: atlas.uv(rect, fu, fv)


def water_tower():
    acc = Acc("X_WaterTower")
    steel = region_uv("steel"); dark = region_uv("darksteel")
    legb, legt, zt = 10.5, 6.36, 46.6
    corners = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
    leg = lambda sx, sy, z: Vector((sx * (legb + (legt - legb) * (z / zt)), sy * (legb + (legt - legb) * (z / zt)), z))
    for sx, sy in corners:
        tube(acc, [leg(sx, sy, -0.5), leg(sx, sy, zt + 0.6)], 0.6, 6, steel)
        box_uv(acc, (sx * legb - 1.1, sy * legb - 1.1, -0.5), (sx * legb + 1.1, sy * legb + 1.1, 0.8),
               lambda n, p: SITE.uv("concrete", 0.3 + 0.1 * (abs(n.y) > 0.5) * ((p.x - sx * legb + 1.1) / 2.2) + 0.1 * (abs(n.x) > 0.5) * ((p.y - sy * legb + 1.1) / 2.2), 0.05 + 0.05 * (p.z + 0.5) / 1.3), skip=("-z",))
    lv = [0.8, 12.5, 24.0, 35.5, 46.0]
    for za, zb_ in zip(lv, lv[1:]):
        for i in range(4):
            c0, c1 = corners[i], corners[(i + 1) % 4]
            bar(acc, leg(*c0, za), leg(*c1, zb_), 0.32, steel)
            bar(acc, leg(*c1, za), leg(*c0, zb_), 0.32, steel)
            bar(acc, leg(*c0, zb_), leg(*c1, zb_), 0.4, steel)
    tube(acc, [(0, 0, -0.5), (0, 0, 45.6)], 1.2, 8, steel)                        # riser pipe
    for oy in (-0.55, 0.55):                                                      # ladder up the riser
        bar(acc, (1.5, oy, 0.0), (1.5, oy, 46.6), 0.14, dark)
    # tank: 20-sided wall (our own 'T-7' stencil in the wrap), dished bottom, cone roof with an underside ring, rod
    NS, R, z0, z1 = 20, 9.0, 47.0, 61.0
    ring = lambda r, z, k: Vector((r * math.cos(2 * math.pi * k / NS), r * math.sin(2 * math.pi * k / NS), z))
    for k in range(NS):
        q = [ring(R, z0, k), ring(R, z0, k + 1), ring(R, z1, k + 1), ring(R, z1, k)]
        acc.face(q, [SITE.uv("tank", k / NS, 0), SITE.uv("tank", (k + 1) / NS, 0), SITE.uv("tank", (k + 1) / NS, 1), SITE.uv("tank", k / NS, 1)],
                 sum(q, Vector()) / 4 - Vector((0, 0, (z0 + z1) / 2)))
        acc.face([ring(R, z0, k + 1), ring(R, z0, k), Vector((0, 0, z0 - 2.2))], [steel(1, 1), steel(0, 1), steel(0.5, 0)], (0, 0, -1))
        acc.face([ring(9.3, z1, k), ring(9.3, z1, k + 1), Vector((0, 0, z1 + 4.6))], [SITE.uv("roofcone", k / NS, 0), SITE.uv("roofcone", (k + 1) / NS, 0), SITE.uv("roofcone", 0.5, 1)], (0, 0, 1))
        acc.face([ring(R - 0.05, z1, k), ring(R - 0.05, z1, k + 1), ring(9.3, z1, k + 1), ring(9.3, z1, k)], [dark(0, 0), dark(1, 0), dark(1, 1), dark(0, 1)], (0, 0, -1))
        # catwalk: deck annulus 9..10.7 (top, underside, edge), two rail bands
        for (zz, nz) in ((z0 + 0.0, 1), (z0 - 0.3, -1)):
            acc.face([ring(R - 0.05, zz, k), ring(R - 0.05, zz, k + 1), ring(10.7, zz, k + 1), ring(10.7, zz, k)], [dark(0, 0), dark(1, 0), dark(1, 1), dark(0, 1)], (0, 0, nz))
        q = [ring(10.7, z0 - 0.3, k), ring(10.7, z0 - 0.3, k + 1), ring(10.7, z0, k + 1), ring(10.7, z0, k)]
        acc.face(q, [dark(0, 0), dark(1, 0), dark(1, 1), dark(0, 1)], sum(q, Vector()) / 4 - Vector((0, 0, z0)))
        for (za, zb_) in ((z0 + 3.0, z0 + 3.25), (z0 + 1.5, z0 + 1.68)):
            q = [ring(10.6, za, k), ring(10.6, za, k + 1), ring(10.6, zb_, k + 1), ring(10.6, zb_, k)]
            acc.face(q, [dark(0, 0), dark(1, 0), dark(1, 1), dark(0, 1)], sum(q, Vector()) / 4 - Vector((0, 0, za)))
            q2 = [ring(10.56, za, k), ring(10.56, za, k + 1), ring(10.56, zb_, k + 1), ring(10.56, zb_, k)]
            acc.face(q2, [dark(0, 0), dark(1, 0), dark(1, 1), dark(0, 1)], Vector((0, 0, za)) - sum(q2, Vector()) / 4)
    for k in range(0, NS, 4):           # rail posts
        p = ring(10.58, 0, k)
        bar(acc, (p.x, p.y, z0), (p.x, p.y, z0 + 3.25), 0.14, dark)
    for oy in (-0.45, 0.45):            # ladder up the tank side to the roof
        bar(acc, (9.25, oy, z0), (9.25, oy, z1 + 0.3), 0.12, dark)
    bar(acc, (0, 0, z1 + 4.4), (0, 0, 70.0), 0.22, dark, caps=True)
    return acc


def sloped_wall(acc, base, top, out, opens, uvfn, d, back_uv, reveal_uv):
    """a battered wall: base = ((xa, ya), (xb, yb)) at z -0.5, top = the same at z 8; opens (fa, fb, z0, z1) with fa/fb
    in 0..1 along the wall; returns nothing. Openings are real holes with horizontal reveals back d."""
    (a0, a1), (t0, t1) = base, top
    ZB, ZT = -0.5, 8.0
    def P(f, z):
        k = (z - ZB) / (ZT - ZB)
        pa = Vector((a0[0] + (t0[0] - a0[0]) * k, a0[1] + (t0[1] - a0[1]) * k, z))
        pb = Vector((a1[0] + (t1[0] - a1[0]) * k, a1[1] + (t1[1] - a1[1]) * k, z))
        return pa.lerp(pb, f)
    cuts = sorted({0.0, 1.0} | {v for o in opens for v in (o[0], o[1])})
    for fa, fb in zip(cuts, cuts[1:]):
        fm = (fa + fb) / 2
        zr = [(ZB, ZT)]
        for o in opens:
            if o[0] < fm < o[1]:
                new = []
                for (p, q) in zr:
                    if o[3] <= p or o[2] >= q:
                        new.append((p, q)); continue
                    if o[2] > p: new.append((p, o[2]))
                    if o[3] < q: new.append((o[3], q))
                zr = new
        for (p, q) in zr:
            quad = [P(fa, p), P(fb, p), P(fb, q), P(fa, q)]
            acc.face(quad, [uvfn(v) for v in quad], out)
    outv = Vector(out).normalized()
    for (fa, fb, z0, z1) in opens:
        corners = [P(fa, z0), P(fb, z0), P(fb, z1), P(fa, z1)]
        backs = [c - Vector((outv.x, outv.y, 0)) * d for c in corners]
        acc.face(backs, [back_uv(0, 0), back_uv(1, 0), back_uv(1, 1), back_uv(0, 1)], out)
        for i in range(4):
            q = [corners[i], corners[(i + 1) % 4], backs[(i + 1) % 4], backs[i]]
            ctr = sum(corners, Vector()) / 4
            acc.face(q, [reveal_uv(0, 0), reveal_uv(1, 0), reveal_uv(1, 1), reveal_uv(0, 1)], ctr - sum(q, Vector()) / 4)


def sandbag_arc(acc, cx, cy, r, a0, a1, n, h=2.3):
    prof = [(-0.85, -0.4), (-0.8, h * 0.55), (-0.45, h), (0.45, h), (0.8, h * 0.55), (0.85, -0.4)]
    st = []
    for i in range(n + 1):
        a = math.radians(a0 + (a1 - a0) * i / n)
        c = Vector((cx + r * math.cos(a), cy + r * math.sin(a), 0)); nr = Vector((math.cos(a), math.sin(a), 0))
        st.append([c + nr * pv + Vector((0, 0, pz)) for pv, pz in prof])
    def U(i):
        k = i % 8
        return (k if k <= 4 else 8 - k) / 4.0       # ping-pong: the 11-stud bag rows mirror every 4 stations
    m = len(prof)
    per = [0.0]
    for k in range(m - 1):
        per.append(per[-1] + math.hypot(prof[k + 1][0] - prof[k][0], prof[k + 1][1] - prof[k][1]))
    for i in range(n):
        for k in range(m - 1):
            q = [st[i][k], st[i + 1][k], st[i + 1][k + 1], st[i][k + 1]]
            mid = (st[i][0] + st[i][-1]) / 2
            uvs = [SITE.uv("sandbag", U(i), per[k] / per[-1]), SITE.uv("sandbag", U(i + 1), per[k] / per[-1]),
                   SITE.uv("sandbag", U(i + 1), per[k + 1] / per[-1]), SITE.uv("sandbag", U(i), per[k + 1] / per[-1])]
            acc.face(q, uvs, sum(q, Vector()) / 4 - Vector((mid.x, mid.y, h * 0.3)))
    for i, sg in ((0, -1), (n, 1)):
        tang = (st[min(n, i + 1)][0] - st[max(0, i - 1)][0]).normalized() * sg
        acc.face(st[i], [SITE.uv("sandbag", 0.5 + 0.4 * pv, (pz + 0.4) / (h + 0.4)) for pv, pz in prof], tang)


def bunker():
    acc = Acc("X_Bunker")
    conx = lambda v: SITE.pps("concrete", v.x + 15.5, v.z + 0.6, 12, 12)
    cony = lambda v: SITE.pps("concrete", v.y + 10.5, v.z + 0.6, 12, 12)
    dark = region_uv("dark"); door = region_uv("door"); conr = lambda fu, fv: SITE.uv("concrete", fu * 0.1, fv * 0.1)
    bx, by, tx, ty = 15.0, 10.0, 13.8, 8.8
    sloped_wall(acc, ((-bx, -by), (bx, -by)), ((-tx, -ty), (tx, -ty)), (0, -1, 0.15), [(0.233, 0.767, 4.8, 6.0)], conx, 1.6, dark, conr)
    sloped_wall(acc, ((bx, by), (-bx, by)), ((tx, ty), (-tx, ty)), (0, 1, 0.15), [], conx, 0, dark, conr)
    sloped_wall(acc, ((-bx, by), (-bx, -by)), ((-tx, ty), (-tx, -ty)), (-1, 0, 0.15), [], cony, 0, dark, conr)
    sloped_wall(acc, ((bx, -by), (bx, by)), ((tx, -ty), (tx, ty)), (1, 0, 0.15), [(0.30, 0.50, -0.5, 6.5)], cony, 0.8, door, conr)
    def roof_uv(n, p):
        if abs(n.z) > 0.5:
            return SITE.pps("concrete", p.x + 14.4, p.y + 9.4, 12, 12)
        return SITE.pps("concrete", (p.x + 14.6) if abs(n.y) > 0.5 else (p.y + 9.6), p.z - 7.4, 12, 12)
    box_uv(acc, (-14.4, -9.4, 7.9), (14.4, 9.4, 10.0), roof_uv)
    tube(acc, [(9, 4, 9.9), (9, 4, 12.4)], 0.5, 6, region_uv("darksteel"), caps=True)          # vent
    bar(acc, (-11, 6, 9.9), (-11, 6, 17.0), 0.12, region_uv("darksteel"), caps=True)           # antenna
    sandbag_arc(acc, 0, -4.5, 9.5, 205, 335, 10)                                                 # in front of the slit
    sandbag_arc(acc, 17.0, -1.0, 4.2, 285, 435, 6, h=1.8)                                        # round the blast door
    return acc


def quonset():
    acc = Acc("X_Quonset")
    NS, R, zc, L = 20, 20.0, 0.6, 40.0
    cor = lambda u, v: SITE.uv("corrugated", u, v)
    arc = [(R * math.cos(math.pi * i / NS), zc + R * math.sin(math.pi * i / NS)) for i in range(NS + 1)]
    for i in range(NS):
        (xa, za), (xb, zb_) = arc[i], arc[i + 1]
        q = [Vector((xa, -L, za)), Vector((xa, L, za)), Vector((xb, L, zb_)), Vector((xb, -L, zb_))]
        acc.face(q, [cor(0, i / NS), cor(1, i / NS), cor(1, (i + 1) / NS), cor(0, (i + 1) / NS)], Vector(((xa + xb) / 2, 0, (za + zb_) / 2 - zc)))
        # the shell has a real 0.15 thickness at the ends: an edge strip at y = +-L and the inside from the end to the
        # inset end wall (an inside face in the outer face's plane would fold over it: A1c)
        ki = (R - 0.15) / R
        ia, ib = (xa * ki, zc + (za - zc) * ki), (xb * ki, zc + (zb_ - zc) * ki)
        for sg in (-1, 1):
            q = [Vector((ia[0], sg * L, ia[1])), Vector((ib[0], sg * L, ib[1])), Vector((ib[0], sg * (L - 0.45), ib[1])), Vector((ia[0], sg * (L - 0.45), ia[1]))]
            acc.face(q, [cor(0, i / NS), cor(0, (i + 1) / NS), cor(0.01, (i + 1) / NS), cor(0.01, i / NS)], Vector((-(xa + xb) / 2, 0, -((za + zb_) / 2 - zc))))
            e = [Vector((xa, sg * L, za)), Vector((xb, sg * L, zb_)), Vector((ib[0], sg * L, ib[1])), Vector((ia[0], sg * L, ia[1]))]
            acc.face(e, [cor(0, i / NS), cor(0, (i + 1) / NS), cor(0.005, (i + 1) / NS), cor(0.005, i / NS)], (0, sg, 0))
    def arc_z(x):
        for (xa, za), (xb, zb_) in zip(arc, arc[1:]):
            if min(xa, xb) - 1e-6 <= x <= max(xa, xb) + 1e-6:
                return za + (zb_ - za) * ((x - xa) / (xb - xa) if abs(xb - xa) > 1e-9 else 0)
        return zc
    for sg, opens in ((-1, [(-9.0, 9.0, zc, 14.0, "hangardoor")]), (1, [(-2.0, 2.0, zc, 8.0, "darksteel"), (-12.5, -8.5, 6.0, 9.5, "dark"), (8.5, 12.5, 6.0, 9.5, "dark")])):
        y = sg * (L - 0.45)
        ew = lambda x, z, sg=sg: SITE.uv("endwall", (20 - sg * x) / 40.0 if sg > 0 else (x + 20) / 40.0, z / 40.0)   # reads left-to-right from outside at both ends
        xs = sorted({a[0] for a in arc} | {v for o in opens for v in (o[0], o[1])})
        for xa, xb in zip(xs, xs[1:]):
            xm = (xa + xb) / 2
            zr = [(zc, None)]
            for o in opens:
                if o[0] < xm < o[1]:
                    new = []
                    for (p, q) in zr:
                        qq = q if q is not None else 99
                        if o[3] <= p or o[2] >= qq:
                            new.append((p, q)); continue
                        if o[2] > p: new.append((p, o[2]))
                        new.append((o[3], q))
                    zr = new
            for (p, q) in zr:
                if q is None:
                    poly = [Vector((xa, y, p)), Vector((xb, y, p)), Vector((xb, y, arc_z(xb))), Vector((xa, y, arc_z(xa)))]
                else:
                    poly = [Vector((xa, y, p)), Vector((xb, y, p)), Vector((xb, y, q)), Vector((xa, y, q))]
                acc.face(poly, [ew(v.x, v.z) for v in poly], (0, sg, 0))
        for (oa, ob, z0, z1, rg) in opens:
            d = 0.8 if rg == "hangardoor" else 0.5
            yb = y - sg * d
            acc.face([Vector((oa, yb, z0)), Vector((ob, yb, z0)), Vector((ob, yb, z1)), Vector((oa, yb, z1))],
                     [SITE.uv(rg, 0, 0), SITE.uv(rg, 1, 0), SITE.uv(rg, 1, 1), SITE.uv(rg, 0, 1)], (0, sg, 0))
            dk = region_uv("darksteel")
            rev = [((oa, z0), (oa, z1), (1, 0, 0)), ((ob, z1), (ob, z0), (-1, 0, 0)), ((oa, z1), (ob, z1), (0, 0, -1))]
            if z0 > zc + 0.01:
                rev.append(((ob, z0), (oa, z0), (0, 0, 1)))
            for (p0, p1, n) in rev:
                q = [Vector((p0[0], y, p0[1])), Vector((p1[0], y, p1[1])), Vector((p1[0], yb, p1[1])), Vector((p0[0], yb, p0[1]))]
                acc.face(q, [dk(0, 0), dk(1, 0), dk(1, 1), dk(0, 1)], n)
    def slab_uv(n, p):
        if n.z > 0.5:
            return SITE.uv("concrete", (p.x + 20.6) / 41.2, (p.y + 40.6) / 81.2)
        a = (p.x + 20.6) / 41.2 if abs(n.y) > 0.5 else (p.y + 40.6) / 81.2
        return SITE.uv("concrete", a, (p.z + 0.5) / 12.0)
    box_uv(acc, (-20.6, -40.6, -0.5), (20.6, 40.6, zc + 0.02), slab_uv, skip=("-z",))
    for yy in (-22.0, 0.0, 22.0):
        box_uv(acc, (-1.1, yy - 1.4, zc + R - 0.3), (1.1, yy + 1.4, zc + R + 1.2), lambda n, p: SITE.uv("darksteel", 0.5, 0.5), skip=("-z",))
    return acc


def observation_stand():
    acc = Acc("X_ObservationStand")
    tim = lambda u, v: SITE.uv("timber", u, v)
    dk = region_uv("darksteel")
    # stepped deck (4 tiers) as one closed prism along x, front = -y
    top = [(-4.6, 1.2), (-2.6, 1.2), (-2.6, 2.6), (-0.6, 2.6), (-0.6, 4.0), (1.4, 4.0), (1.4, 5.4), (3.4, 5.4)]
    under = [(3.4, 5.0), (1.8, 5.0), (1.8, 3.6), (-0.2, 3.6), (-0.2, 2.2), (-2.2, 2.2), (-2.2, 0.8), (-4.6, 0.8)]
    prof = top + under
    X0, X1 = -15.0, 15.0
    for k in range(len(prof)):
        (ya, za), (yb, zb_) = prof[k], prof[(k + 1) % len(prof)]
        q = [Vector((X0, ya, za)), Vector((X1, ya, za)), Vector((X1, yb, zb_)), Vector((X0, yb, zb_))]
        nrm = Vector((0, zb_ - za, -(yb - ya)))
        acc.face(q, [tim(0, 0), tim(1, 0), tim(1, 0.12), tim(0, 0.12)], -nrm)
    for x, sx in ((X0, -1), (X1, 1)):
        pts = [Vector((x, y, z)) for y, z in prof]
        acc.face(pts, [tim((y + 5) / 10, z / 6) for y, z in prof], (sx, 0, 0))
    # posts under the tiers, the back rail, the shade roof on 6 posts, end bracing
    for x in (-14.6, -7.3, 0.0, 7.3, 14.6):
        for (y, zt) in ((-4.3, 0.85), (-2.3, 2.25), (-0.3, 3.65), (1.7, 5.05)):
            box_uv(acc, (x - 0.2, y - 0.2, -0.4), (x + 0.2, y + 0.2, zt), lambda n, p: tim(0.5, (p.z + 0.4) / 6), skip=("-z", "+z"))
    for x in (-14.6, 0.0, 14.6):
        box_uv(acc, (x - 0.25, 3.0, 5.3), (x + 0.25, 3.5, 7.4), lambda n, p: tim(0.5, 0.5), skip=("-z",))
    box_uv(acc, (-15.0, 2.94, 6.8), (15.0, 3.24, 7.2), lambda n, p: tim((p.x + 15) / 30, 0.5))     # rail 0.06 proud of the posts
    zf, zbk = 13.7, 12.3
    for x in (-14.8, 0.0, 14.8):
        bar(acc, (x, -4.4, -0.4), (x, -4.4, zf - 0.15), 0.32, dk)
        bar(acc, (x, 3.6, 5.2), (x, 3.6, zbk - 0.15), 0.32, dk)
    ry0, ry1 = -5.6, 4.6
    rf = lambda y: zf + (zbk - zf) * (y - ry0) / (ry1 - ry0)
    th = 0.3
    rt = [Vector((-15.6, ry0, rf(ry0) + th)), Vector((15.6, ry0, rf(ry0) + th)), Vector((15.6, ry1, rf(ry1) + th)), Vector((-15.6, ry1, rf(ry1) + th))]
    rb = [Vector((v.x, v.y, v.z - th)) for v in rt]
    cor = lambda u, v: SITE.uv("corrugated", u, v)
    acc.face(rt, [cor(0, 0), cor(1, 0), cor(1, 0.4), cor(0, 0.4)], (0, 0.1, 1))
    acc.face(rb, [cor(0, 0), cor(1, 0), cor(1, 0.4), cor(0, 0.4)], (0, -0.1, -1))
    for i in range(4):
        q = [rb[i], rb[(i + 1) % 4], rt[(i + 1) % 4], rt[i]]
        c = sum(q, Vector()) / 4
        acc.face(q, [dk(0, 0), dk(1, 0), dk(1, 1), dk(0, 1)], c - Vector((0, -0.5, c.z)))
    for x in (-14.9, 14.9):
        bar(acc, (x, -4.3, 0.2), (x, 1.7, 4.6), 0.22, tim)
        bar(acc, (x, 1.7, 0.2), (x, -4.3, 0.75), 0.22, tim)
    return acc


def chain_link():
    acc = Acc("X_ChainLink")
    fab_v0, fab_v1 = 1.0 - 446.0 / 512.0, 1.0 - 4.0 / 512.0
    pv0, pv1 = 1.0 - 510.0 / 512.0, 1.0 - 450.0 / 512.0
    L, z0, z1 = 30.0, 0.1, 7.6
    for (y, sg) in ((-0.015, -1), (0.015, 1)):         # double-sided card: each side its own face and normal (A13)
        q = [Vector((-L, y, z0)), Vector((L, y, z0)), Vector((L, y, z1)), Vector((-L, y, z1))]
        acc.face(q, [(0, fab_v0), (2 * L / 4.0, fab_v0), (2 * L / 4.0, fab_v1), (0, fab_v1)], (0, sg, 0))
    post = lambda fu, fv: (fu, pv0 + (pv1 - pv0) * fv)
    for x in (-30.0, -15.0, 0.0, 15.0, 30.0):
        tube(acc, [(x, 0, -0.5), (x, 0, 8.0)], 0.17, 4, post)
    tube(acc, [(-30.0, 0, 7.75), (30.0, 0, 7.75)], 0.1, 4, post)
    return acc


def pole_line():
    acc = Acc("X_PoleLine")
    wood = region_uv("polewood"); wire = region_uv("wire"); ins = region_uv("insul"); dk = region_uv("darksteel")
    xs = [-210.0 + 60.0 * i for i in range(8)]
    H = 30.0
    rng = random.Random(808)
    tops = []
    for i, x in enumerate(xs):
        lean = rng.uniform(-0.25, 0.25)
        tube(acc, [(x, 0, -0.5), (x + lean, 0, H)], 0.5, 6, wood, r_end=0.34)
        box_uv(acc, (x + lean - 0.2, -3.3, H - 1.8), (x + lean + 0.2, 3.3, H - 1.3), lambda n, p: wood(0.5, 0.5))
        for yy in (-2.9, 0.0, 2.9):
            tube(acc, [(x + lean, yy, H - 1.3), (x + lean, yy, H - 0.7)], 0.13, 3, ins, caps=True)
        if i in (2, 5):
            tube(acc, [(x + lean, 0.95, H - 6.0), (x + lean, 0.95, H - 4.0)], 0.7, 6, dk, caps=True)
        tops.append(x + lean)
    for yy in (-2.9, 0.0, 2.9):
        for xa, xb in zip(tops, tops[1:]):
            pts = [(xa + (xb - xa) * k / 5, yy, H - 0.75 - 2.4 * 4 * (k / 5) * (1 - k / 5)) for k in range(6)]
            tube(acc, pts, 0.09, 3, wire)
    for x, d in ((tops[0], -1), (tops[-1], 1)):
        tube(acc, [(x, 0, H - 3.0), (x + d * 9.0, 0, -0.3)], 0.07, 3, wire)
    return acc


def mid():
    names = []
    for b in range(4):
        for fn, piece in ((town_house_A, "X_TownHouse_A"), (town_house_B, "X_TownHouse_B")):
            names.append(build(fn(b), "X_Town", "Mid", open_shell=True, meta=dict(piece=piece, colourway=BANDS[b])).name)
    for fn, piece, closed in ((water_tower, "X_WaterTower", False), (bunker, "X_Bunker", False), (quonset, "X_Quonset", False),
                              (observation_stand, "X_ObservationStand", False), (pole_line, "X_PoleLine", False)):
        names.append(build(fn(), "X_Site", "Mid", open_shell=True, meta=dict(piece=piece)).name)
    names.append(build(chain_link(), "X_ChainLink", "Mid", open_shell=True, alpha=True, meta=dict(piece="X_ChainLink")).name)
    return names


# ------------------------------------------------------------------------------------------------------- main
def mean_colour(ob):
    """average texture colour under the object's UVs (fallback Color if Import 3D drops the texture)"""
    me = ob.data
    mat = me.materials[0]
    im = None
    for nd in mat.node_tree.nodes:
        if nd.type == "TEX_IMAGE":
            im = nd.image
    if im is None:
        return None
    import numpy as np
    w, h = im.size
    px = np.empty(w * h * 4, np.float32); im.pixels.foreach_get(px)
    px = px.reshape(h, w, 4)
    uvd = me.uv_layers["UVMap"].data
    rng = np.random.default_rng(1)
    samp = []
    for poly in me.polygons:
        uvs = np.array([uvd[li].uv[:] for li in poly.loop_indices], np.float32)
        if len(uvs) < 3:
            continue
        k = max(1, int(poly.area * 2))               # samples in proportion to the face area
        w = rng.dirichlet(np.ones(3), size=min(k, 4000))
        for i in range(1, len(uvs) - 1):
            tri_ = np.stack([uvs[0], uvs[i], uvs[i + 1]])
            samp.append(w @ tri_)
    if not samp:
        return None
    uv = np.concatenate(samp)
    u = ((uv[:, 0] % 1.0) * (w_ := px.shape[1] - 1)).astype(int); v = ((uv[:, 1] % 1.0) * (px.shape[0] - 1)).astype(int)
    c = px[v, u, :3].mean(0)          # byte PNGs: pixels are the stored sRGB values / 255
    return [int(round(255 * min(1.0, max(0.0, float(x))))) for x in c]


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(IFBX, exist_ok=True)
    groups = {}
    if "far" in PARTS:
        groups["Far"] = far()
    if "near" in PARTS:
        groups["Near"] = near()
    if "mid" in PARTS:
        groups["Mid"] = mid()
    for c in list(bpy.data.collections):
        if c.name in ("House", "Masters") and not c.objects:
            bpy.data.collections.remove(c)
    cube, mk = scale_cube_marker()
    cube.location = (0, -150, 40); mk.location = (12, -150, 35)
    bpy.context.view_layer.update()
    # size guard (Roblox MeshPart cap) and the manifest
    man = dict(note="House illusion pass (art only: Anchored, CanCollide / CanQuery / CanTouch off, CastShadow off past the near "
                    "field). Plan coordinates as art/house/v2 (x east, y north, z up; outside ground z -1; Blender (x,y,z) -> "
                    "Studio (-x, z, y) before the map's own CFrame). FBX in cm: Import 3D at scale 0.01, verify with K_ScaleCube "
                    "(10 studs). Far / Near: origin = plan origin (place the model as the v2 H_Exterior). Mid: origin = bottom "
                    "centre on the ground (z 0 = the ground under the piece), front = -Y.",
               textures={k: f"art/house/illusion/tex/{k}.png" for k in ("X_Ground", "X_Mesa", "X_Town", "X_Site", "X_ChainLink", "X_Near")},
               objects=[], errors=[])
    for name, (ob, meta) in OBJS.items():
        lo, hi, sz = aabb(ob)
        if max(sz) >= SIZE_CAP:
            man["errors"].append(f"{name} {tuple(round(v) for v in sz)} over {SIZE_CAP}")
        e = dict(name=name, **{k: v for k, v in meta.items()}, tris=tris(ob),
                 bbox_min=[round(v, 2) for v in lo], bbox_max=[round(v, 2) for v in hi], size=[round(v, 2) for v in sz],
                 origin=[round(v, 3) for v in ob.location])
        e["fallback_rgb"] = mean_colour(ob)
        man["objects"].append(e)
    tot = {}
    for e in man["objects"]:
        tot.setdefault(e["collection"], 0); tot[e["collection"]] += e["tris"]
    man["tris_by_file"] = tot
    pieces = {}
    for e in man["objects"]:
        pieces.setdefault(e["piece"], 0); pieces[e["piece"]] += e["tris"]
    man["tris_by_piece"] = pieces
    path = os.path.join(IROOT, "house_illusion.json")
    if os.path.exists(path) and set(PARTS) != {"far", "near", "mid"}:
        old = json.load(open(path))
        keep = [o for o in old.get("objects", []) if o["collection"] not in groups]
        man["objects"] = keep + man["objects"]
        for k in ("tris_by_file", "tris_by_piece"):
            d_ = dict(old.get(k, {})); d_.update(man[k]); man[k] = d_
    json.dump(man, open(path, "w"), indent=1)
    if man["errors"]:
        log("SIZE ERRORS", man["errors"])
    fname = {"Far": "X_Far.fbx", "Near": "X_Near.fbx", "Mid": "X_Mid.fbx"}
    for g in groups:
        objs = [ob for ob, meta in OBJS.values() if meta["collection"] == g]
        export_fbx(os.path.join(IFBX, fname[g]), objs + [cube, mk])
        log("exported", fname[g], len(objs), "objects", tot[g], "tris")
    bl = BLEND if set(PARTS) == {"far", "near", "mid"} else BLEND.replace(".blend", f"_{'_'.join(PARTS)}.blend")
    bpy.ops.wm.save_as_mainfile(filepath=bl)
    bpy.ops.file.make_paths_relative(); bpy.ops.wm.save_mainfile()
    log("DONE", tot)


if __name__ == "__main__":
    main()

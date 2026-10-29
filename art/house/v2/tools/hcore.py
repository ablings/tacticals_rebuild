"""House kit core (shared by build_furniture.py and build_house.py). Adapted from art/warehouse2/tools/build_props.py:
MB mesh accumulator (closed shells, per-face material kind, PL helper UV), layered procedural materials baked into one
atlas per family (colour+AO, roughness, metalness, tangent normal), buried faces get zero UV, ships triangles.
Blender (x, y, z) -> Studio (-x, z, y). 1 unit = 1 stud. Front of every prop = Blender -Y."""
import bpy, bmesh, math, random, json, os, sys, time
from mathutils import Vector, Matrix
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))
TEX = os.path.join(ROOT, "tex")
DEC = TEX                     # decal image names are relative to tex/ ("gen/art_abstract", "decals/x")
FBXD = os.path.join(ROOT, "fbx")
PREFIX = "H_"
ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
def arg(k, d):
    return type(d)(ARGV[ARGV.index(k) + 1]) if k in ARGV else d
RES = arg("--res", 1024)
SAMPLES = arg("--samples", 16)
NOBAKE = "--nobake" in ARGV
DEVICES = arg("--device", "OPTIX,CUDA").split(",")
T0 = time.time()
def log(*a):
    print(f"[{time.time() - T0:6.1f}s]", *a, flush=True)

def srgb(c):
    def f(v):
        v /= 255.0
        return v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4
    return (f(c[0]), f(c[1]), f(c[2]), 1.0)


# ----------------------------------------------------------------------------------------------------------- geometry
class MB:
    """bmesh accumulator for one object: closed shells, a material kind per face, a 'PL' helper UV (plank / grain /
    arc coordinates per shell, in studs) and face attributes grv (grooves / tread on) and pid (random per shell)."""
    def __init__(s, name, atlas, height):
        s.name, s.atlas, s.height = name, atlas, height
        s.bm = bmesh.new()
        s.uv0 = s.bm.loops.layers.uv.new("UVMap")
        s.pl = s.bm.loops.layers.uv.new("PL")
        s.grv = s.bm.faces.layers.float.new("grv")
        s.pid = s.bm.faces.layers.float.new("pid")
        s.kinds = []
        s.decals = []
        s.rng = random.Random(sum(map(ord, name)) * 7)

    def k(s, kind):
        if kind not in s.kinds:
            s.kinds.append(kind)
        return s.kinds.index(kind)

    def shell(s, verts, faces, kind, grain=None, groove=0.0, pl="box", r_ref=1.0, center=None, kindfn=None, groovefn=None):
        vs = [s.bm.verts.new(Vector(v)) for v in verts]
        fs = []
        for f in faces:
            try:
                fs.append(s.bm.faces.new([vs[i] for i in f]))
            except ValueError:
                pass
        for f in fs:      # normals FIRST: triangulating a concave n-gon with no normal flips some of its triangles
            f.normal_update()
        big = [f for f in fs if len(f.verts) > 4]
        if big:
            res = bmesh.ops.triangulate(s.bm, faces=big, quad_method="BEAUTY", ngon_method="BEAUTY")
            fs = list(dict.fromkeys([f for f in fs if f.is_valid] + list(res["faces"])))
        bmesh.ops.recalc_face_normals(s.bm, faces=fs)
        c = Vector(center) if center is not None else sum((Vector(v) for v in verts), Vector()) / len(verts)
        pid = s.rng.random()
        for f in fs:
            f.normal_update()
            f.material_index = s.k(kindfn(f) if kindfn else kind)
            f[s.grv] = groovefn(f) if groovefn else groove
            f[s.pid] = pid
            s._pl(f, pl, grain, c, r_ref)
        return fs

    def _pl(s, f, mode, grain, c, r_ref):
        n = f.normal
        if mode == "cyl" and abs(n.z) < 0.8:
            fc = f.calc_center_median() - c
            a0 = math.atan2(fc.y, fc.x)
            for l in f.loops:
                p = l.vert.co - c
                da = (math.atan2(p.y, p.x) - a0 + math.pi) % (2 * math.pi) - math.pi
                l[s.pl].uv = ((a0 + da) * r_ref, p.z)
            return
        a = max(range(3), key=lambda i: abs(n[i]))
        inplane = [i for i in range(3) if i != a]
        u = grain if (grain is not None and grain in inplane) else (0 if 0 in inplane else 1)
        v = [i for i in inplane if i != u][0]
        for l in f.loops:
            p = l.vert.co - c
            l[s.pl].uv = (p[u], p[v])

    # primitives ------------------------------------------------------------------------------------------------
    def box(s, c, size, kind, R=None, grain="auto", **kw):
        hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
        pts = [(-hx, -hy, -hz), (hx, -hy, -hz), (hx, hy, -hz), (-hx, hy, -hz), (-hx, -hy, hz), (hx, -hy, hz), (hx, hy, hz), (-hx, hy, hz)]
        R = R or Matrix.Identity(3)
        vs = [Vector(c) + R @ Vector(p) for p in pts]
        if grain == "auto":
            grain = max(range(3), key=lambda i: size[i])
        return s.shell(vs, [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)], kind,
                       grain=grain, center=c, **kw)

    def boxr(s, lo, hi, kind, **kw):
        lo, hi = Vector(lo), Vector(hi)
        return s.box((lo + hi) / 2, hi - lo, kind, **kw)

    def lathe(s, prof, segs, kind, M=None, deform=None, cap=True, a0=0.0, **kw):
        verts, rings, faces = [], [], []
        for (r, z) in prof:
            if r < 1e-6:
                rings.append([len(verts)]); verts.append(Vector((0, 0, z)))
            else:
                ring = []
                for i in range(segs):
                    a = a0 + 2 * math.pi * i / segs
                    ring.append(len(verts)); verts.append(Vector((r * math.cos(a), r * math.sin(a), z)))
                rings.append(ring)
        for A, B in zip(rings, rings[1:]):
            if len(A) == 1 and len(B) == 1:
                continue
            if len(A) == 1:
                faces += [(A[0], B[i], B[(i + 1) % segs]) for i in range(segs)]
            elif len(B) == 1:
                faces += [(A[i], A[(i + 1) % segs], B[0]) for i in range(segs)]
            else:
                faces += [(A[i], A[(i + 1) % segs], B[(i + 1) % segs], B[i]) for i in range(segs)]
        if cap and len(rings[0]) > 1:
            faces.append(tuple(reversed(rings[0])))
        if cap and len(rings[-1]) > 1:
            faces.append(tuple(rings[-1]))
        if deform:
            verts = [deform(v) for v in verts]
        M = M or Matrix.Identity(4)
        verts = [M @ v for v in verts]
        return s.shell(verts, faces, kind, pl="cyl", center=M @ Vector((0, 0, 0)), **kw)

    def revolve(s, loop, segs, kind, M=None, deform=None, **kw):
        """closed (r, z) loop revolved around Z: a torus-like closed solid (tyres, lamp shade)"""
        n, verts, faces = len(loop), [], []
        for i in range(segs):
            a = 2 * math.pi * i / segs
            for (r, z) in loop:
                verts.append(Vector((r * math.cos(a), r * math.sin(a), z)))
        for i in range(segs):
            i2 = (i + 1) % segs
            for j in range(n):
                j2 = (j + 1) % n
                faces.append((i * n + j, i * n + j2, i2 * n + j2, i2 * n + j))
        if deform:
            verts = [deform(v) for v in verts]
        M = M or Matrix.Identity(4)
        verts = [M @ v for v in verts]
        return s.shell(verts, faces, kind, pl="cyl", center=M @ Vector((0, 0, 0)), **kw)

    def prism(s, pts, axis, a0, a1, kind, **kw):
        """polygon pts extruded along axis from a0 to a1. axis 'X': pts are (y, z); 'Y': (x, z); 'Z': (x, y)"""
        def mk(p, t):
            if axis == "X": return Vector((t, p[0], p[1]))
            if axis == "Y": return Vector((p[0], t, p[1]))
            return Vector((p[0], p[1], t))
        pts = clean_poly(pts)
        n = len(pts)
        verts = [mk(p, a0) for p in pts] + [mk(p, a1) for p in pts]
        faces = [tuple(range(n)), tuple(range(n, 2 * n))] + [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
        return s.shell(verts, faces, kind, **kw)

    def tube(s, path, r, kind, segs=6, **kw):
        path = [Vector(p) for p in path]
        verts, faces, rings = [], [], []
        b1 = None
        for k, p in enumerate(path):
            t = (path[min(k + 1, len(path) - 1)] - path[max(k - 1, 0)]).normalized()
            if b1 is None:   # first frame, then parallel transport (no twist, no flipped rings)
                up = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
                b1 = t.cross(up).normalized()
            else:
                b1 = (b1 - t * b1.dot(t)).normalized()
            b2 = t.cross(b1)
            ring = []
            for i in range(segs):
                a = 2 * math.pi * i / segs
                ring.append(len(verts)); verts.append(p + (b1 * math.cos(a) + b2 * math.sin(a)) * r)
            rings.append(ring)
        for A, B in zip(rings, rings[1:]):
            faces += [(A[i], A[(i + 1) % segs], B[(i + 1) % segs], B[i]) for i in range(segs)]
        faces.append(tuple(reversed(rings[0]))); faces.append(tuple(rings[-1]))
        return s.shell(verts, faces, kind, **kw)

    def raw(s, verts, faces, kind, **kw):
        return s.shell(verts, faces, kind, **kw)

    # decals ----------------------------------------------------------------------------------------------------
    def decal(s, img, n, c, w, h, col=None, op=0.92, rough=None, kinds=None, depth=0.6):
        s.decals.append(dict(img=img, mode="plane", n=Vector(n).normalized(), c=Vector(c), w=w, h=h, col=col, op=op,
                             rough=rough, kinds=kinds, depth=depth))

    def decal_cyl(s, img, ang, zc, r, w, h, col=None, op=0.92, rough=None, kinds=None, cx=0.0, cy=0.0):
        s.decals.append(dict(img=img, mode="cyl", a0=ang, zc=zc, r=r, w=w, h=h, col=col, op=op, rough=rough, kinds=kinds,
                             cx=cx, cy=cy))


def clean_poly(pts):
    """drop repeated and collinear points (they triangulate into zero-area faces)"""
    out = []
    for p in pts:
        if not out or (abs(p[0] - out[-1][0]) > 1e-6 or abs(p[1] - out[-1][1]) > 1e-6):
            out.append(p)
    if len(out) > 1 and abs(out[0][0] - out[-1][0]) < 1e-6 and abs(out[0][1] - out[-1][1]) < 1e-6:
        out.pop()
    changed = True
    while changed and len(out) > 3:
        changed = False
        for i in range(len(out)):
            a, b, c = out[i - 1], out[i], out[(i + 1) % len(out)]
            if abs((b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])) < 1e-7:
                out.pop(i); changed = True; break
    return out


def apply_decals(mb):
    for i, d in enumerate(mb.decals):
        lay = mb.bm.loops.layers.uv.new(f"D{i}")
        kinds = d["kinds"]
        allowed = {mb.kinds.index(k) for k in mb.kinds if (k in kinds if kinds else K[k].get("paintable"))}
        d["slots"] = allowed
        if d["mode"] == "plane":
            n = d["n"]
            right = Vector((0, 0, 1)).cross(n).normalized() if abs(n.z) < 0.5 else Vector((1, 0, 0))
            up = n.cross(right).normalized()
        for f in mb.bm.faces:
            ok = f.material_index in allowed
            if ok and d["mode"] == "plane":
                ok = f.normal.dot(n) > 0.7 and (f.calc_center_median() - d["c"]).dot(n) > -d["depth"]
            elif ok:
                fn = f.normal
                ok = abs(fn.z) < 0.6 and abs((math.atan2(fn.y, fn.x) - d["a0"] + math.pi) % (2 * math.pi) - math.pi) < d["w"] / 2 / d["r"] + 0.35
            for l in f.loops:
                if not ok:
                    l[lay].uv = (-5.0, -5.0); continue
                p = l.vert.co
                if d["mode"] == "plane":
                    q = p - d["c"]
                    l[lay].uv = (q.dot(right) / d["w"] + 0.5, q.dot(up) / d["h"] + 0.5)
                else:
                    a = math.atan2(p.y - d["cy"], p.x - d["cx"])
                    da = (a - d["a0"] + math.pi) % (2 * math.pi) - math.pi
                    l[lay].uv = (da * d["r"] / d["w"] + 0.5, (p.z - d["zc"]) / d["h"] + 0.5)

# ----------------------------------------------------------------------------------------------------------- materials
# Modern suburban house: clean (little dirt, no rust or chips), neutral warm greys and cream, oak and walnut, black metal,
# one restrained accent (dusty slate blue / sage) per room. No yellow or orange accents (Design Rules).
DEF = dict(paint=None, under=(130, 130, 126), rust_col=((78, 40, 20), (128, 66, 30)), wood=False, groove=False, chip=0.0,
           rust=0.0, streak=0.0, stain=0.0, rough=0.6, under_rough=0.38, metal_paint=0.0, metal_under=0.0, dirt=0.18,
           dust=0.0, mottle=0.06, spangle=False, weave=False, bleach=0.0, tape=False, holes=False, tread=False, rope=False,
           heat=0.0, paintable=False, bump=0.4, slats=0.0, tile=0.0, grout=(150, 148, 142), vein=0.0, vein_col=(160, 158, 154),
           stitch=False, stones=0.0, bricks=0.0)
K = {
    # soft furnishings (weave = fine fabric bump; stitch = darker piping on the edges)
    "fabric_grey":     dict(paint=(118, 116, 110), weave=True, stitch=True, rough=0.95, mottle=0.07, bump=0.35),
    "fabric_charcoal": dict(paint=(60, 61, 62), weave=True, stitch=True, rough=0.95, mottle=0.07, bump=0.35),
    "fabric_cream":    dict(paint=(206, 200, 186), weave=True, stitch=True, rough=0.95, mottle=0.06, bump=0.35),
    "fabric_slate":    dict(paint=(84, 96, 110), weave=True, stitch=True, rough=0.95, mottle=0.07, bump=0.35),
    "fabric_sage":     dict(paint=(132, 138, 118), weave=True, stitch=True, rough=0.95, mottle=0.07, bump=0.35),
    "fabric_rust":     dict(paint=(122, 72, 56), weave=True, stitch=True, rough=0.95, mottle=0.07, bump=0.35),
    "linen_white":     dict(paint=(228, 224, 214), weave=True, rough=0.95, mottle=0.05, bump=0.3, dirt=0.12),
    "linen_grey":      dict(paint=(150, 150, 146), weave=True, rough=0.95, mottle=0.06, bump=0.3, dirt=0.12),
    "linen_blue":      dict(paint=(92, 110, 132), weave=True, rough=0.95, mottle=0.06, bump=0.3, dirt=0.12),
    "leather_brown":   dict(paint=(92, 60, 42), stitch=True, rough=0.5, mottle=0.14, bump=0.25),
    "leather_black":   dict(paint=(34, 33, 32), stitch=True, rough=0.45, mottle=0.1, bump=0.25),
    # wood (no grooves: veneer)
    "oak":             dict(under=(178, 144, 104), wood=True, stain=0.12, rough=0.55, mottle=0.08, paintable=True),
    "oak_light":       dict(under=(196, 170, 134), wood=True, stain=0.1, rough=0.55, mottle=0.08, paintable=True),
    "walnut":          dict(under=(104, 72, 50), wood=True, stain=0.15, rough=0.5, mottle=0.1, paintable=True),
    "floor_oak":       dict(under=(170, 134, 96), wood=True, groove=True, stain=0.15, rough=0.5, mottle=0.1),
    # painted / lacquered panels
    "lacquer_white":   dict(paint=(226, 222, 212), rough=0.35, paintable=True),
    "lacquer_greige":  dict(paint=(172, 166, 154), rough=0.38, paintable=True),
    "lacquer_charcoal":dict(paint=(54, 56, 58), rough=0.38, paintable=True),
    "lacquer_slate":   dict(paint=(78, 92, 106), rough=0.38, paintable=True),
    "lacquer_sage":    dict(paint=(128, 136, 116), rough=0.4, paintable=True),
    "plinth":          dict(paint=(30, 30, 30), rough=0.6, dirt=0.3),
    # metals
    "black_metal":     dict(paint=(30, 30, 31), rough=0.45, metal_paint=0.3, mottle=0.04),
    "steel":           dict(paint=(172, 174, 174), rough=0.32, metal_paint=1.0, mottle=0.05, paintable=True),
    "chrome":          dict(paint=(214, 214, 214), rough=0.12, metal_paint=1.0, mottle=0.02, dirt=0.05),
    "bronze":          dict(paint=(120, 96, 72), rough=0.35, metal_paint=1.0, mottle=0.05),
    # stone, ceramic, glass, plastic
    "quartz":          dict(paint=(232, 230, 224), vein=0.45, vein_col=(170, 168, 164), rough=0.22, dirt=0.08),
    "quartz_dark":     dict(paint=(48, 48, 48), vein=0.35, vein_col=(120, 120, 118), rough=0.22, dirt=0.06),
    "ceramic":         dict(paint=(238, 236, 230), rough=0.14, dirt=0.1, mottle=0.03),
    "tile_white":      dict(paint=(222, 220, 214), tile=1.0, grout=(160, 158, 152), rough=0.2, dirt=0.15),
    "tile_grey":       dict(paint=(128, 128, 124), tile=1.0, grout=(92, 92, 90), rough=0.3, dirt=0.15),
    "glass_dark":      dict(paint=(34, 40, 44), rough=0.06, dirt=0.04, mottle=0.02),
    "mirror":          dict(paint=(150, 160, 166), rough=0.04, metal_paint=1.0, dirt=0.03, mottle=0.03),
    "screen":          dict(paint=(12, 13, 15), rough=0.08, dirt=0.0, mottle=0.02),
    "plastic_white":   dict(paint=(232, 230, 226), rough=0.4, paintable=True),
    "plastic_black":   dict(paint=(24, 24, 25), rough=0.45, paintable=True),
    "plastic_grey":    dict(paint=(110, 112, 114), rough=0.45, paintable=True),
    "rubber":          dict(paint=(22, 22, 22), rough=0.9, dirt=0.2),
    "concrete_pot":    dict(paint=(150, 148, 142), rough=0.85, mottle=0.14, bump=0.6, dirt=0.3),
    "terracotta":      dict(paint=(150, 98, 74), rough=0.85, mottle=0.12, bump=0.5, dirt=0.3),
    "soil":            dict(paint=(52, 40, 30), rough=0.95, mottle=0.3, bump=0.9, dirt=0.4),
    "leaf":            dict(paint=(58, 88, 50), rough=0.5, mottle=0.18, bump=0.3, dirt=0.1),
    "leaf_dark":       dict(paint=(40, 64, 40), rough=0.5, mottle=0.18, bump=0.3, dirt=0.1),
    "stem":            dict(paint=(84, 70, 52), rough=0.8),
    "shade":           dict(paint=(232, 226, 210), weave=True, rough=0.95, mottle=0.04, bump=0.2, dirt=0.05),
    "bulb":            dict(paint=(250, 240, 214), rough=0.15, dirt=0.0, mottle=0.02),
    "canvas":          dict(paint=(236, 232, 218), rough=0.8, paintable=True, dirt=0.05, mottle=0.02),
    "paper":           dict(paint=(240, 238, 232), rough=0.85, paintable=True, dirt=0.05, mottle=0.02),
    "books":           dict(paint=(110, 100, 90), rough=0.75, paintable=True, dirt=0.15, mottle=0.04),
    "rug":             dict(paint=(190, 184, 172), weave=True, rough=0.98, paintable=True, bump=0.5, dirt=0.1),
    "towel":           dict(paint=(214, 210, 200), weave=True, rough=0.98, bump=0.7, dirt=0.1),
    "toy_red":         dict(paint=(176, 46, 40), rough=0.35, paintable=True),
    "toy_blue":        dict(paint=(52, 96, 168), rough=0.35, paintable=True),
    "toy_green":       dict(paint=(64, 134, 76), rough=0.35, paintable=True),
    "toy_white":       dict(paint=(236, 234, 228), rough=0.35, paintable=True),
    "plush":           dict(paint=(132, 98, 70), weave=True, rough=1.0, mottle=0.1, bump=0.8),
    "fruit":           dict(paint=(150, 40, 34), rough=0.3, mottle=0.2),
}
for k_ in K:
    d_ = dict(DEF); d_.update(K[k_]); K[k_] = d_


# ----------------------------------------------------------------------------------------------------------- extra shapes
def rbox(mb, lo, hi, kind, r=0.15, segs=2, top_only=False, **kw):
    """box with rounded (bevelled) edges: cushions, upholstered panels, appliances"""
    lo, hi = Vector(lo), Vector(hi)
    t = bmesh.new()
    bmesh.ops.create_cube(t, size=1.0)
    sz = hi - lo
    for v in t.verts:
        v.co = Vector((lo.x + (v.co.x + 0.5) * sz.x, lo.y + (v.co.y + 0.5) * sz.y, lo.z + (v.co.z + 0.5) * sz.z))
    r = min(r, min(sz) * 0.45)
    edges = t.edges[:]
    if top_only:
        edges = [e for e in t.edges if all(v.co.z > lo.z + sz.z * 0.5 for v in e.verts)]
    bmesh.ops.bevel(t, geom=edges, offset=r, segments=segs, affect="EDGES", profile=0.5, clamp_overlap=True)
    verts = [v.co.copy() for v in t.verts]
    t.verts.index_update()
    faces = [[v.index for v in f.verts] for f in t.faces]
    t.free()
    return mb.raw(verts, faces, kind, center=(lo + hi) / 2, **kw)


def sq_ring(A, B, n=4.0, segs=32, a0=0.0):
    """superellipse loop (half-axes A, B) as a list of (x, y), CCW"""
    out = []
    for i in range(segs):
        a = a0 + 2 * math.pi * i / segs
        c, s = math.cos(a), math.sin(a)
        out.append((A * math.copysign(abs(c) ** (2 / n), c), B * math.copysign(abs(s) ** (2 / n), s)))
    return out


def sq_lathe(mb, prof, A, B, kind, n=4.0, segs=32, M=None, **kw):
    """lathe whose rings are superellipses: prof = [(scale, z)], ring = scale * (A, B) superellipse. scale 0 = a point.
    Use for tubs, basins, rounded-rect pots: profile goes out, up the outer wall, over the rim and down inside."""
    verts, rings, faces = [], [], []
    base = sq_ring(A, B, n, segs)
    for (k, z) in prof:
        if k < 1e-6:
            rings.append([len(verts)]); verts.append(Vector((0, 0, z)))
        else:
            ring = []
            for (x, y) in base:
                ring.append(len(verts)); verts.append(Vector((x * k, y * k, z)))
            rings.append(ring)
    for P_, Q in zip(rings, rings[1:]):
        if len(P_) == 1 and len(Q) == 1:
            continue
        if len(P_) == 1:
            faces += [(P_[0], Q[i], Q[(i + 1) % segs]) for i in range(segs)]
        elif len(Q) == 1:
            faces += [(P_[i], P_[(i + 1) % segs], Q[0]) for i in range(segs)]
        else:
            faces += [(P_[i], P_[(i + 1) % segs], Q[(i + 1) % segs], Q[i]) for i in range(segs)]
    if len(rings[0]) > 1:
        faces.append(tuple(reversed(rings[0])))
    if len(rings[-1]) > 1:
        faces.append(tuple(rings[-1]))
    M = M or Matrix.Identity(4)
    verts = [M @ v for v in verts]
    return mb.shell(verts, faces, kind, pl="cyl", center=M @ Vector((0, 0, 0)), **kw)


def ellipsoid(mb, c, r, kind, segs=12, rings=8, M=None, **kw):
    """closed ellipsoid (radii r = (rx, ry, rz)) at c: plush toys, fruit, leaves (flat ry)"""
    prof = [(math.sin(math.pi * i / rings), -math.cos(math.pi * i / rings)) for i in range(rings + 1)]
    S = Matrix.Diagonal((r[0], r[1], r[2], 1.0))
    Mf = Matrix.Translation(Vector(c)) @ (M or Matrix.Identity(4)) @ S
    return mb.lathe([(p[0], p[1]) for p in prof], segs, kind, M=Mf, **kw)


def leaf(mb, base, direction, length, width, kind, droop=0.25, thick=0.05, segs=4):
    """closed lens-shaped leaf (both sides real faces, so no culling hole): base point, unit direction, curved down."""
    d = Vector(direction).normalized()
    side = d.cross(Vector((0, 0, 1)))
    if side.length < 1e-3:
        side = Vector((1, 0, 0))
    side.normalize()
    up = side.cross(d).normalized()
    top, bot, L, R = [], [], [], []
    pts = []
    for i in range(segs + 1):
        t = i / segs
        w = max(0.03, width * 0.5 * math.sin(math.pi * t) ** 0.8)
        p = Vector(base) + d * (length * t) - up * (droop * length * t * t)
        pts.append((p, w))
    verts, faces = [], []
    # cross-section: left edge, top mid, right edge, bottom mid
    for (p, w) in pts:
        verts += [p - side * w, p + up * thick, p + side * w, p - up * thick]
    for i in range(segs):
        a, b = 4 * i, 4 * (i + 1)
        for j in range(4):
            faces.append((a + j, a + (j + 1) % 4, b + (j + 1) % 4, b + j))
    faces.append((3, 2, 1, 0))
    n = 4 * segs
    faces.append((n, n + 1, n + 2, n + 3))
    return mb.raw(verts, faces, kind, center=Vector(base) + d * length * 0.5)


class G:
    def __init__(s, mat):
        mat.use_nodes = True
        s.nt = mat.node_tree; s.N = s.nt.nodes; s.L = s.nt.links
        s.N.clear()

    def n(s, t, **kw):
        nd = s.N.new(t)
        for k, v in kw.items():
            setattr(nd, k, v)
        return nd

    def put(s, sock, v):
        if isinstance(v, bpy.types.NodeSocket):
            s.L.new(v, sock)
        elif isinstance(v, (tuple, list)):
            if len(v) == 3 and sock.type == "RGBA":
                v = (*v, 1.0)
            sock.default_value = v
        else:
            sock.default_value = v

    def m(s, op, a, b=0.0, c=None, clamp=False):
        nd = s.n("ShaderNodeMath", operation=op, use_clamp=clamp)
        s.put(nd.inputs[0], a); s.put(nd.inputs[1], b)
        if c is not None:
            s.put(nd.inputs[2], c)
        return nd.outputs[0]

    def mr(s, v, a, b, c=0.0, d=1.0):
        nd = s.n("ShaderNodeMapRange", clamp=True)
        s.put(nd.inputs[0], v)
        nd.inputs[1].default_value, nd.inputs[2].default_value = a, b
        nd.inputs[3].default_value, nd.inputs[4].default_value = c, d
        return nd.outputs[0]

    def mixc(s, fac, a, b, blend="MIX"):
        nd = s.n("ShaderNodeMix", data_type="RGBA", blend_type=blend)
        s.put(nd.inputs[0], fac); s.put(nd.inputs[6], a); s.put(nd.inputs[7], b)
        return nd.outputs[2]

    def mixf(s, fac, a, b):
        nd = s.n("ShaderNodeMix", data_type="FLOAT")
        s.put(nd.inputs[0], fac); s.put(nd.inputs[2], a); s.put(nd.inputs[3], b)
        return nd.outputs[0]

    def mul(s, col, f):
        return s.mixc(1.0, col, f, "MULTIPLY")

    def rgb(s, c):
        nd = s.n("ShaderNodeRGB"); nd.outputs[0].default_value = srgb(c); return nd.outputs[0]

    def noise(s, vec, scale, detail=4.0, rough=0.55):
        nd = s.n("ShaderNodeTexNoise")
        s.put(nd.inputs["Vector"], vec); nd.inputs["Scale"].default_value = scale
        nd.inputs["Detail"].default_value = detail; nd.inputs["Roughness"].default_value = rough
        return nd.outputs["Fac"]

    def xyz(s, x, y, z):
        nd = s.n("ShaderNodeCombineXYZ")
        for i, v in enumerate((x, y, z)):
            s.put(nd.inputs[i], v)
        return nd.outputs[0]

    def sep(s, v):
        nd = s.n("ShaderNodeSeparateXYZ"); s.put(nd.inputs[0], v); return nd.outputs

    def attr(s, name):
        return s.n("ShaderNodeAttribute", attribute_name=name, attribute_type="GEOMETRY").outputs["Fac"]

    def uv(s, name):
        return s.n("ShaderNodeUVMap", uv_map=name).outputs[0]

    def add(s, *xs):
        out = xs[0]
        for x in xs[1:]:
            out = s.m("ADD", out, x)
        return out

def make_mat(name, kind, mb, decals):
    P = K[kind]
    mat = bpy.data.materials.new(name)
    g = G(mat)
    obj = g.n("ShaderNodeTexCoord").outputs["Object"]
    o = g.sep(obj)
    zr = g.m("DIVIDE", o["Z"], max(0.2, mb.height))
    geo = g.n("ShaderNodeNewGeometry")
    N = geo.outputs["Normal"]
    nz = g.sep(N)["Z"]
    pl = g.sep(g.uv("PL"))
    u, v = pl["X"], pl["Y"]
    grv, pid = g.attr("grv"), g.attr("pid")

    base = P["paint"] or P["under"]
    col = g.rgb(base)
    col = g.mul(col, g.mr(g.noise(obj, 1.4, 3), 0.3, 0.7, 1 - P["mottle"], 1 + P["mottle"]))
    col = g.mul(col, g.mr(pid, 0, 1, 0.92, 1.08))
    under = g.mul(g.rgb(P["under"]), g.mr(g.noise(obj, 3.0, 4), 0.3, 0.7, 0.85, 1.12))
    height = 0.0
    rough = P["rough"]
    metal = P["metal_paint"]

    if P["wood"]:
        vv = g.m("DIVIDE", v, 0.45)
        plank = g.m("FLOOR", vv)
        fr = g.m("FRACT", vv)
        wn = g.n("ShaderNodeTexWhiteNoise", noise_dimensions="1D")
        g.put(wn.inputs["W"], g.m("MULTIPLY_ADD", pid, 7.0, plank))
        pv = wn.outputs["Value"]
        grain = g.noise(g.xyz(g.m("MULTIPLY", u, 0.35), g.m("MULTIPLY", v, 9.0), g.m("MULTIPLY", pv, 5.0)), 1.0, 6, 0.6)
        knots = g.mr(g.noise(g.xyz(g.m("MULTIPLY", u, 1.5), g.m("MULTIPLY", v, 4.0), pv), 2.0, 2), 0.68, 0.74)
        wood = g.mul(g.rgb(P["under"]), g.mr(grain, 0.3, 0.7, 0.7, 1.22))
        wood = g.mul(wood, g.mr(pv, 0, 1, 0.84, 1.14))
        wood = g.mixc(g.m("MULTIPLY", knots, 0.6), wood, g.rgb((60, 42, 28)))
        if P["groove"]:
            edge = g.m("MINIMUM", fr, g.m("SUBTRACT", 1.0, fr))
            groove = g.m("MULTIPLY", g.mr(edge, 0.04, 0.11, 1.0, 0.0), grv)
            wood = g.mixc(g.m("MULTIPLY", groove, 0.75), wood, g.rgb((34, 26, 18)))
            height = g.add(height, g.m("MULTIPLY", groove, -1.0))
        height = g.add(height, g.m("MULTIPLY", grain, 0.12))
        if P["paint"] is None:
            col = g.mul(wood, g.mr(g.noise(obj, 1.4, 3), 0.3, 0.7, 1 - P["mottle"], 1 + P["mottle"]))
        else:
            under = wood
            if P["groove"]:
                col = g.mixc(g.m("MULTIPLY", groove, 0.6), col, g.rgb((28, 30, 18)))
        if P["stain"]:
            st = g.m("MULTIPLY", g.mr(g.noise(g.xyz(o["X"], o["Y"], g.m("MULTIPLY", o["Z"], 0.4)), 1.2, 5), 0.55, 0.75), P["stain"])
            col = g.mixc(st, col, g.rgb((58, 50, 38)))
    if P["spangle"]:
        vo = g.n("ShaderNodeTexVoronoi"); g.put(vo.inputs["Vector"], obj); vo.inputs["Scale"].default_value = 7.0
        col = g.mul(col, g.mr(g.sep(vo.outputs["Color"])["X"], 0, 1, 0.9, 1.08))
    if P["weave"]:
        w1 = g.m("SINE", g.m("MULTIPLY", g.add(o["X"], o["Z"]), 60.0))
        w2 = g.m("SINE", g.m("MULTIPLY", g.add(o["Y"], o["Z"]), 60.0))
        weave = g.m("MULTIPLY", w1, w2)
        col = g.mul(col, g.mr(weave, -1, 1, 0.93, 1.05))
        height = g.add(height, g.m("MULTIPLY", weave, 0.25))
    if P["rope"]:
        tw = g.m("FRACT", g.m("MULTIPLY", g.add(o["X"], o["Y"], o["Z"]), 9.0))
        tw = g.m("ABSOLUTE", g.m("SUBTRACT", tw, 0.5))
        col = g.mul(col, g.mr(tw, 0, 0.5, 1.12, 0.65))
        height = g.add(height, g.m("MULTIPLY", tw, -0.8))
    if P["tape"]:
        tape = g.m("MULTIPLY", g.mr(g.m("ABSOLUTE", v), 0.12, 0.15, 1, 0), g.mr(nz, 0.7, 0.8))
        col = g.mixc(tape, col, g.rgb((186, 160, 116)))
        rough = g.mixf(tape, rough, 0.35)
    if P["holes"]:
        hx = g.m("ABSOLUTE", g.m("SUBTRACT", g.m("FRACT", g.m("DIVIDE", u, 0.25)), 0.5))
        hy = g.m("ABSOLUTE", g.m("SUBTRACT", g.m("FRACT", g.m("DIVIDE", v, 0.25)), 0.5))
        hole = g.mr(g.m("POWER", g.add(g.m("MULTIPLY", hx, hx), g.m("MULTIPLY", hy, hy)), 0.5), 0.17, 0.21, 1, 0)
        hole = g.m("MULTIPLY", hole, g.mr(g.m("ABSOLUTE", g.sep(N)["Y"]), 0.7, 0.8))
        col = g.mixc(hole, col, g.rgb((16, 14, 12)))
        height = g.add(height, g.m("MULTIPLY", hole, -1.0))
    if P["slats"]:   # roll-up slats on a flat face: ridge height and dark grooves at the slat pitch (PL v = height)
        ph = g.m("FRACT", g.m("DIVIDE", v, P["slats"]))
        ridge = g.mr(g.m("ABSOLUTE", g.m("SUBTRACT", ph, 0.5)), 0.12, 0.36, 1.0, 0.0)
        groove = g.mr(g.m("ABSOLUTE", g.m("SUBTRACT", ph, 0.5)), 0.4, 0.5, 0.0, 1.0)
        col = g.mixc(g.m("MULTIPLY", groove, 0.55), col, g.rgb((40, 42, 42)))
        height = g.add(height, g.m("MULTIPLY", ridge, 1.6))
    if P["tread"]:
        side = g.m("GREATER_THAN", v, 0.0)
        blk = g.m("LESS_THAN", g.m("FRACT", g.m("MULTIPLY_ADD", side, 0.5, g.m("DIVIDE", u, 0.32))), 0.55)
        blk = g.m("MULTIPLY", blk, g.mr(g.m("ABSOLUTE", v), 0.0, 0.04, 0.4, 1.0))
        tread = g.m("MULTIPLY", blk, grv)
        col = g.mixc(g.m("MULTIPLY", g.m("SUBTRACT", grv, tread), 0.5), col, g.rgb((10, 10, 10)))
        height = g.add(height, g.m("MULTIPLY", tread, 1.0))

    if P["stones"]:   # rough fieldstone: voronoi stones (object space, size ~1/stones studs) with dark mortar and shaded faces
        vo = g.n("ShaderNodeTexVoronoi", feature="DISTANCE_TO_EDGE"); g.put(vo.inputs["Vector"], g.xyz(o["X"], o["Y"], g.m("MULTIPLY", o["Z"], 1.4)))
        vo.inputs["Scale"].default_value = P["stones"]
        vc = g.n("ShaderNodeTexVoronoi"); g.put(vc.inputs["Vector"], g.xyz(o["X"], o["Y"], g.m("MULTIPLY", o["Z"], 1.4)))
        vc.inputs["Scale"].default_value = P["stones"]
        cell = g.sep(vc.outputs["Color"])["X"]
        col = g.mul(col, g.mr(cell, 0, 1, 0.72, 1.25))
        mort = g.mr(vo.outputs["Distance"], 0.03, 0.08, 1.0, 0.0)
        col = g.mul(col, g.mr(vo.outputs["Distance"], 0.0, 0.3, 0.75, 1.05))
        col = g.mixc(mort, col, g.rgb((70, 64, 54)))
        height = g.add(height, g.m("MULTIPLY", g.mr(vo.outputs["Distance"], 0.0, 0.25, 0.0, 1.0), 1.5))
        rough = g.mixf(mort, rough, 1.0)
    if P["bricks"]:   # running-bond bricks on the PL coordinates (studs): 1 x 0.33, offset rows, pale mortar
        bh_ = P["bricks"] / 3.0
        row = g.m("FLOOR", g.m("DIVIDE", v, bh_))
        uu = g.add(g.m("DIVIDE", u, P["bricks"]), g.m("MULTIPLY", g.m("FRACT", g.m("MULTIPLY", row, 0.5)), 1.0))
        fu = g.m("FRACT", uu); fv = g.m("FRACT", g.m("DIVIDE", v, bh_))
        e = g.m("MINIMUM", g.m("MULTIPLY", g.m("MINIMUM", fu, g.m("SUBTRACT", 1.0, fu)), 3.0), g.m("MINIMUM", fv, g.m("SUBTRACT", 1.0, fv)))
        mort = g.mr(e, 0.05, 0.09, 1.0, 0.0)
        wn = g.n("ShaderNodeTexWhiteNoise", noise_dimensions="2D"); g.put(wn.inputs["Vector"], g.xyz(g.m("FLOOR", uu), row, 0.0))
        col = g.mul(col, g.mr(wn.outputs["Value"], 0, 1, 0.8, 1.15))
        col = g.mixc(mort, col, g.rgb((196, 186, 168)))
        height = g.add(height, g.m("MULTIPLY", mort, -1.0))
    if P["tile"]:   # square tiles with grout lines, on the PL coordinates (studs)
        t = P["tile"]
        fu = g.m("FRACT", g.m("DIVIDE", u, t)); fv = g.m("FRACT", g.m("DIVIDE", v, t))
        e = g.m("MINIMUM", g.m("MINIMUM", fu, g.m("SUBTRACT", 1.0, fu)), g.m("MINIMUM", fv, g.m("SUBTRACT", 1.0, fv)))
        gr = g.mr(e, 0.018 / t, 0.03 / t, 1.0, 0.0)
        col = g.mixc(gr, col, g.rgb(P["grout"]))
        rough = g.mixf(gr, rough, 0.9)
        height = g.add(height, g.m("MULTIPLY", gr, -1.0))
    if P["vein"]:   # stone veins (quartz / marble) and fine speckle
        vn = g.noise(g.xyz(g.m("MULTIPLY", o["X"], 0.7), g.m("MULTIPLY", o["Y"], 0.7), g.m("MULTIPLY", o["Z"], 0.7)), 1.3, 8, 0.7)
        vein = g.m("MULTIPLY", g.mr(g.m("ABSOLUTE", g.m("SUBTRACT", vn, 0.5)), 0.0, 0.018, 1.0, 0.0), P["vein"])
        col = g.mixc(vein, col, g.rgb(P["vein_col"]))
        speck = g.mr(g.noise(obj, 40.0, 2), 0.66, 0.7, 0.0, 0.25)
        col = g.mixc(speck, col, g.rgb((120, 118, 114)))
    if P["stitch"]:   # piping seam: darken along every edge (bevel-normal edge mask)
        bev3 = g.n("ShaderNodeBevel", samples=8); bev3.inputs["Radius"].default_value = 0.1
        dp3 = g.n("ShaderNodeVectorMath", operation="DOT_PRODUCT")
        g.put(dp3.inputs[0], bev3.outputs["Normal"]); g.put(dp3.inputs[1], N)
        seam = g.mr(dp3.outputs["Value"], 0.985, 0.9)
        col = g.mul(col, g.mr(seam, 0, 1, 1.0, 0.8))

    # stencils / labels: sprayed on the paint, so they wear with it
    late = []   # dark stencils go on after the dirt/dust mixes: grime toward (46,40,32) would lift black letters to brown
    for i, d in decals:
        im = bpy.data.images.load(os.path.join(DEC, d["img"] + ".png"), check_existing=True)
        im.alpha_mode = "STRAIGHT"
        tx = g.n("ShaderNodeTexImage", image=im, extension="CLIP", interpolation="Linear")
        g.put(tx.inputs[0], g.uv(f"D{i}"))
        a = g.m("MULTIPLY", tx.outputs["Alpha"], d["op"])
        a = g.m("MULTIPLY", a, g.mr(g.noise(obj, 2.2, 3), 0.35, 0.65, 0.75, 1.0))
        dc = g.rgb(d["col"]) if d["col"] else tx.outputs["Color"]
        if d["col"] and sum(d["col"]) < 150:
            late.append((a, dc, d))
            continue
        col = g.mixc(a, col, dc)
        if d["rough"] is not None:
            rough = g.mixf(a, rough, d["rough"])
        if d["img"] == "fx_drip":
            col = g.mixc(a, col, g.rgb((26, 12, 8)), "MULTIPLY")
            height = g.add(height, g.m("MULTIPLY", a, 0.4))

    # rust patches (more toward the bottom) and streaks running down
    rmask = 0.0
    if P["rust"]:
        t = 0.74 - 0.26 * P["rust"]
        rn = g.noise(obj, 1.3, 8, 0.62)
        low = g.mr(zr, 0.0, 0.3, 0.12, 0.0)
        rmask = g.m("MULTIPLY", g.mr(g.add(rn, low), t, t + 0.06), min(1.0, P["rust"] * 1.6))
        rc = g.mixc(g.noise(obj, 6.0, 4), g.rgb(P["rust_col"][0]), g.rgb(P["rust_col"][1]))
        col = g.mixc(rmask, col, rc)
        height = g.add(height, g.m("MULTIPLY", rmask, g.m("MULTIPLY", g.noise(obj, 20.0, 3), 0.6)))
        rough = g.mixf(rmask, rough, 0.9)
        metal = g.mixf(rmask, metal, 0.0)
    if P["streak"]:
        sn = g.noise(g.xyz(g.m("MULTIPLY", o["X"], 7.0), g.m("MULTIPLY", o["Y"], 7.0), g.m("MULTIPLY", o["Z"], 0.35)), 1.5, 4)
        sm = g.m("MULTIPLY", g.mr(sn, 0.56, 0.78), P["streak"] * 0.55)
        col = g.mixc(sm, col, g.rgb((70, 42, 24)))
    # chipped paint on edges (bevel-normal edge mask) and a few scratches on faces
    chip = 0.0
    if P["chip"]:
        bev = g.n("ShaderNodeBevel", samples=8); bev.inputs["Radius"].default_value = 0.09
        dp = g.n("ShaderNodeVectorMath", operation="DOT_PRODUCT")
        g.put(dp.inputs[0], bev.outputs["Normal"]); g.put(dp.inputs[1], N)
        edge = g.mr(dp.outputs["Value"], 0.995, 0.86)
        cn = g.noise(obj, 6.5, 8, 0.65)
        chip = g.mr(g.add(edge, g.m("MULTIPLY", g.m("SUBTRACT", cn, 0.5), 1.1)), 0.52, 0.58)
        scr = g.mr(g.noise(obj, 13.0, 2), 0.79, 0.81, 0.0, 0.6)
        chip = g.m("MULTIPLY", g.m("MAXIMUM", chip, scr), P["chip"], clamp=True)
        col = g.mixc(chip, col, under)
        rough = g.mixf(chip, rough, P["under_rough"])
        metal = g.mixf(chip, metal, P["metal_under"])
        height = g.add(height, g.m("MULTIPLY", g.m("SUBTRACT", 1.0, chip), 0.35))
    if P["heat"]:
        hb = g.mr(g.add(zr, g.m("MULTIPLY", g.noise(obj, 2.0, 3), 0.3)), 0.72, 0.95)
        col = g.mixc(g.m("MULTIPLY", hb, 0.55), col, g.mixc(g.noise(obj, 3.0, 2), g.rgb((62, 52, 70)), g.rgb((112, 76, 48))))
        soot = g.mr(g.noise(obj, 1.1, 4), 0.45, 0.7)
        col = g.mixc(g.m("MULTIPLY", soot, 0.5), col, g.rgb((8, 8, 8)))
    # dirt in creases and along the floor, dust on top faces
    if P["dirt"]:
        ao = g.n("ShaderNodeAmbientOcclusion", only_local=True, samples=16)
        ao.inputs["Distance"].default_value = 0.5
        dm = g.add(g.m("MULTIPLY", g.m("SUBTRACT", 1.0, ao.outputs["AO"]), P["dirt"] * 1.3),
                   g.m("MULTIPLY", g.mr(zr, 0.0, 0.12, 1.0, 0.0), P["dirt"] * 0.5))
        dm = g.m("MULTIPLY", dm, g.mr(g.noise(obj, 2.5, 4), 0.3, 0.7, 0.5, 1.2), clamp=True)
        col = g.mixc(dm, col, g.rgb((46, 40, 32)))
        rough = g.mixf(g.m("MULTIPLY", dm, 0.5), rough, 0.95)
        metal = g.mixf(dm, metal, 0.0)
    if P["dust"]:
        du = g.m("MULTIPLY", g.mr(nz, 0.6, 0.95), g.m("MULTIPLY", g.mr(g.noise(obj, 3.0, 5), 0.35, 0.7), P["dust"]))
        col = g.mixc(du, col, g.rgb((150, 145, 134)))
        rough = g.mixf(du, rough, 0.95)
    if P["bleach"]:
        col = g.mixc(g.m("MULTIPLY", g.mr(nz, 0.3, 0.9), P["bleach"]), col, g.rgb((150, 150, 146)))   # neutral sun-bleach (olive-tinted bleach kept the tarp green)
    for a, dc, d in late:
        col = g.mixc(a, col, dc)
        if d["rough"] is not None:
            rough = g.mixf(a, rough, d["rough"])

    bsdf = g.n("ShaderNodeBsdfPrincipled")
    g.put(bsdf.inputs["Base Color"], col)
    g.put(bsdf.inputs["Roughness"], rough)
    # Metallic stays 0 here: a DIFFUSE colour bake of a metallic BSDF comes out black (fridge, mirror). Metalness is baked via Emission.
    g.put(bsdf.inputs["Emission Color"], g.xyz(metal, metal, metal) if isinstance(metal, bpy.types.NodeSocket) else (metal, metal, metal, 1))
    bsdf.inputs["Emission Strength"].default_value = 1.0
    bev2 = g.n("ShaderNodeBevel", samples=8); bev2.inputs["Radius"].default_value = 0.05
    bump = g.n("ShaderNodeBump"); bump.inputs["Strength"].default_value = P["bump"]; bump.inputs["Distance"].default_value = 0.02
    g.put(bump.inputs["Height"], height); g.put(bump.inputs["Normal"], bev2.outputs["Normal"])
    g.put(bsdf.inputs["Normal"], bump.outputs["Normal"])
    out = g.n("ShaderNodeOutputMaterial")
    g.put(out.inputs["Surface"], bsdf.outputs[0])
    return mat


# ----------------------------------------------------------------------------------------------------------- objects
COLL = {}
def coll(name):
    if name not in COLL:
        c = bpy.data.collections.new(name); bpy.context.scene.collection.children.link(c); COLL[name] = c
    return COLL[name]

MASTERS = []   # (object, mb atlas)
def mark_buried(bm):
    """face attribute 'bur' = 1 for faces whose whole area lies inside another closed shell of the same object
    (hidden by construction). They keep their geometry (meshes stay closed) but get no UV space, so the visible
    faces get the texels."""
    from mathutils.bvhtree import BVHTree
    lay = bm.faces.layers.float.get("bur") or bm.faces.layers.float.new("bur")
    bm.faces.ensure_lookup_table()
    seen, shells = set(), []
    for f in bm.faces:
        if f.index in seen:
            continue
        stack, comp = [f], []
        seen.add(f.index)
        while stack:
            g = stack.pop(); comp.append(g)
            for e in g.edges:
                for h in e.link_faces:
                    if h.index not in seen:
                        seen.add(h.index); stack.append(h)
        shells.append(comp)
    info = []
    for comp in shells:
        vs = {v.index: v for g in comp for v in g.verts}
        idx = {k: i for i, k in enumerate(vs)}
        tree = BVHTree.FromPolygons([vs[k].co.copy() for k in vs], [[idx[v.index] for v in g.verts] for g in comp])
        lo = Vector((min(v.co.x for v in vs.values()), min(v.co.y for v in vs.values()), min(v.co.z for v in vs.values())))
        hi = Vector((max(v.co.x for v in vs.values()), max(v.co.y for v in vs.values()), max(v.co.z for v in vs.values())))
        info.append((tree, lo, hi))
    dirs = [Vector(v).normalized() for v in ((0.31, 0.57, 0.76), (-0.71, 0.23, 0.53), (0.43, -0.83, -0.29))]
    def inside(p, k):
        tree, lo, hi = info[k]
        if not all(lo[i] - 1e-4 <= p[i] <= hi[i] + 1e-4 for i in range(3)):
            return False
        votes = 0
        for d in dirs:      # ray parity in 3 directions, majority vote (a ray through a shared edge counts twice)
            n, q = 0, p.copy()
            for _ in range(64):
                hit = tree.ray_cast(q, d)
                if hit[0] is None:
                    break
                n += 1; q = hit[0] + d * 1e-3
            votes += n % 2
        return votes >= 2
    count = 0
    for si, comp in enumerate(shells):
        for f in comp:
            c = f.calc_center_median()
            vs = [v.co for v in f.verts]
            mids = [(vs[i] + vs[(i + 1) % len(vs)]) / 2 for i in range(len(vs))]
            pts = [c] + [c + (q - c) * t for q in vs + mids for t in (0.5, 0.97)]
            pts = [p + f.normal * 0.004 for p in pts]
            bur = all(any(inside(p, k) for k in range(len(shells)) if k != si) for p in pts)
            f[lay] = 1.0 if bur else 0.0
            count += bur
    return count


def resolve_coplanar(bm, step=0.03, passes=7):
    """A19 fix at build time: inside one mesh, coplanar same-facing faces of two different loose parts that overlap
    z-fight. Pull the face of the SMALLER part (bbox volume) `step` inward along its normal; the larger part keeps the
    plane, so the outer extents (and the cover boxes derived from them) never change. Same overlap test as
    roblox_kits blender_check.coplanar_overlaps. Returns the number of faces moved."""
    from collections import defaultdict
    from mathutils import geometry
    moved = 0
    for _ in range(passes):
        bm.normal_update()
        bm.verts.ensure_lookup_table()
        part, comps = {}, []
        seen = set()
        for f in bm.faces:
            if f in seen:
                continue
            stack, comp = [f], []
            seen.add(f)
            while stack:
                g = stack.pop(); comp.append(g)
                for v in g.verts:
                    for h in v.link_faces:
                        if h not in seen:
                            seen.add(h); stack.append(h)
            for g in comp:
                part[g] = len(comps)
            comps.append(comp)
        vol = []
        for comp in comps:
            vs = {v for g in comp for v in g.verts}
            lo = Vector((min(v.co.x for v in vs), min(v.co.y for v in vs), min(v.co.z for v in vs)))
            hi = Vector((max(v.co.x for v in vs), max(v.co.y for v in vs), max(v.co.z for v in vs)))
            d = hi - lo
            vol.append(max(d.x, 1e-3) * max(d.y, 1e-3) * max(d.z, 1e-3))
        tris = defaultdict(list)
        for lt in bm.calc_loop_triangles():
            tris[lt[0].face].append([l.vert.co.copy() for l in lt])
        planes = defaultdict(list)
        for f in bm.faces:
            n = f.normal
            if n.length < 0.5 or f.calc_area() < 1e-5:
                continue
            planes[(round(n.x, 3), round(n.y, 3), round(n.z, 3), round(n.dot(f.verts[0].co), 3))].append(f)
        push = {}
        for key, fs in planes.items():
            if len(fs) < 2 or len({part[f] for f in fs}) < 2:
                continue
            drop = max(range(3), key=lambda i: abs(key[i]))
            keep = [i for i in range(3) if i != drop]
            flat = lambda v: Vector((v[keep[0]], v[keep[1]]))
            t2 = {f: [[flat(v) for v in t] for t in tris[f]] for f in fs}
            b2 = {f: (min(p.x for t in ts for p in t), min(p.y for t in ts for p in t), max(p.x for t in ts for p in t), max(p.y for t in ts for p in t)) for f, ts in t2.items() if ts}
            def overlap(f, g):
                if f not in b2 or g not in b2:
                    return False
                a, b = b2[f], b2[g]
                if a[0] >= b[2] - 1e-6 or b[0] >= a[2] - 1e-6 or a[1] >= b[3] - 1e-6 or b[1] >= a[3] - 1e-6:
                    return False
                for small, big in ((f, g), (g, f)):
                    for t in t2[small]:
                        c = (t[0] + t[1] + t[2]) / 3
                        for p in (c, (c + t[0]) / 2, (c + t[1]) / 2, (c + t[2]) / 2):
                            if any(geometry.intersect_point_tri_2d(p, *u) for u in t2[big]):
                                return True
                return False
            for i in range(len(fs)):
                for j in range(i + 1, len(fs)):
                    f, g = fs[i], fs[j]
                    if part[f] != part[g] and overlap(f, g):
                        loser = f if (vol[part[f]], part[f]) < (vol[part[g]], part[g]) else g
                        n_ = loser.normal.copy()
                        ds = [v.co.dot(n_) for g_ in comps[part[loser]] for v in g_.verts]
                        push[loser] = (n_, min(step, 0.3 * (max(ds) - min(ds))))     # never through a thin part
        if not push:
            break
        disp = defaultdict(lambda: Vector((0, 0, 0)))
        for f, (n, st) in push.items():
            for v in f.verts:
                d = disp[v]
                for k in range(3):
                    c = -n[k] * st
                    if abs(c) > abs(d[k]):
                        d[k] = c
        for v, d in disp.items():
            v.co += d
        moved += len(push)
    return moved


def finish(mb, loc=(0, 0, 0)):
    apply_decals(mb)
    bm = mb.bm
    bm.normal_update()
    mb.coplanar_moved = resolve_coplanar(bm)
    # ship triangles: the importer must not pick the other diagonal of a concave or non-planar quad
    bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="BEAUTY", ngon_method="BEAUTY")
    bm.normal_update()
    mb.buried = mark_buried(bm)
    for f in bm.faces:
        f.smooth = True
    for e in bm.edges:
        e.smooth = len(e.link_faces) == 2 and e.calc_face_angle(math.pi) < math.radians(35)
    me = bpy.data.meshes.new(mb.name)
    bm.to_mesh(me); bm.free()
    ob = bpy.data.objects.new(mb.name, me)
    coll("Masters").objects.link(ob)
    ob.location = loc
    for i, kind in enumerate(mb.kinds):
        decs = [(j, d) for j, d in enumerate(mb.decals) if i in d["slots"]]
        mt = make_mat(f"{mb.name}|{kind}", kind, mb, decs)
        mt.diffuse_color = srgb(K[kind]["paint"] or K[kind]["under"])
        me.materials.append(mt)
    ob["atlas"] = mb.atlas
    MASTERS.append(ob)
    return ob
def setup_cycles():
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    try:
        pr = bpy.context.preferences.addons["cycles"].preferences
        for dt in DEVICES:
            try:
                pr.compute_device_type = dt
                pr.get_devices()
                gpus = [d for d in pr.devices if d.type == dt]
                if gpus:
                    for d in pr.devices:
                        d.use = d.type == dt
                    sc.cycles.device = "GPU"
                    log("cycles device", dt, [d.name for d in gpus])
                    break
            except Exception as ex:
                log("device", dt, "failed", ex)
    except Exception as ex:
        log("GPU setup failed, CPU", ex)
    sc.cycles.samples = SAMPLES
    sc.cycles.use_denoising = False
    sc.render.bake.margin = 6
    sc.render.bake.margin_type = "EXTEND"


def unwrap(objs, angle=60):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
        o.data.uv_layers.active = o.data.uv_layers["UVMap"]
    bpy.context.view_layer.objects.active = objs[0]
    for o in objs:   # unwrap only the faces a player can see; buried faces keep a zero-area UV and take no texels
        bur = o.data.attributes.get("bur")
        for p in o.data.polygons:
            p.select = not (bur and bur.data[p.index].value > 0.5)
        for l in o.data.uv_layers["UVMap"].data:
            l.uv = (0.0, 0.0)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(angle), island_margin=0.004, area_weight=0.0, correct_aspect=True, scale_to_bounds=False)
    bpy.ops.uv.pack_islands(rotate=True, margin=0.003)
    bpy.ops.object.mode_set(mode="OBJECT")


ATLAS_RES = {}      # atlas name -> bake resolution (default RES)


def bake_atlas(atl, objs):
    RES = ATLAS_RES.get(atl, globals()["RES"])
    log("bake", atl, [o.name for o in objs])
    unwrap(objs)
    imgs = {}
    for p in ("color", "rough", "metal", "normal", "ao"):
        im = bpy.data.images.new(f"{PREFIX}{atl}_{p}", RES, RES, alpha=False)
        im.colorspace_settings.name = "sRGB" if p == "color" else "Non-Color"
        imgs[p] = im
    targets = []
    for o in objs:
        o.data.uv_layers["UVMap"].active_render = True
        o.data.uv_layers.active = o.data.uv_layers["UVMap"]
        for m in o.data.materials:
            t = m.node_tree.nodes.new("ShaderNodeTexImage"); t.name = "BakeTarget"
            targets.append((m, t))
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    def run(p, typ, **kw):
        for m, t in targets:
            t.image = imgs[p]
            for nd in m.node_tree.nodes:
                nd.select = False
            t.select = True
            m.node_tree.nodes.active = t
        t0 = time.time()
        bpy.ops.object.bake(type=typ, use_clear=True, margin=6, **kw)
        log("  ", atl, p, f"{time.time() - t0:.1f}s")
        if p in ("color", "normal", "ao"):   # a failed GPU kernel bakes black without raising: stop instead of shipping it
            px = np.empty(RES * RES * 4, np.float32); imgs[p].pixels.foreach_get(px)
            if float(px.reshape(-1, 4)[:, :3].max()) < 0.02:
                raise RuntimeError(f"bake {atl} {p} is black: the render device failed (try --device CUDA)")
    run("color", "DIFFUSE", pass_filter={"COLOR"})
    run("rough", "ROUGHNESS")
    run("metal", "EMIT")
    run("normal", "NORMAL", normal_space="TANGENT")
    run("ao", "AO")
    # AO into the colour map (gentle), then save
    n = RES * RES * 4
    c = np.empty(n, np.float32); imgs["color"].pixels.foreach_get(c)
    a = np.empty(n, np.float32); imgs["ao"].pixels.foreach_get(a)
    c = c.reshape(-1, 4); a = a.reshape(-1, 4)[:, :1]
    c[:, :3] *= (0.55 + 0.45 * a) ** 0.6
    imgs["color"].pixels.foreach_set(c.ravel())
    out = {}
    for p in ("color", "normal", "rough", "metal"):
        im = imgs[p]
        if p in ("rough", "metal"):
            im.scale(RES // 2, RES // 2)
        path = os.path.join(TEX, f"{PREFIX}{atl}_{p}.png")
        im.filepath_raw = path; im.file_format = "PNG"; im.save()
        im.filepath = path
        out[p] = im
    bpy.data.images.remove(imgs["ao"])
    return out


def atlas_material(atl, imgs):
    mat = bpy.data.materials.new(f"{PREFIX}{atl}")
    g = G(mat)
    bsdf = g.n("ShaderNodeBsdfPrincipled")
    uvn = g.uv("UVMap")
    def tex(p):
        t = g.n("ShaderNodeTexImage", image=imgs[p]); g.put(t.inputs[0], uvn); return t
    g.put(bsdf.inputs["Base Color"], tex("color").outputs[0])
    g.put(bsdf.inputs["Roughness"], tex("rough").outputs[0])
    g.put(bsdf.inputs["Metallic"], tex("metal").outputs[0])
    nm = g.n("ShaderNodeNormalMap", uv_map="UVMap"); g.put(nm.inputs["Color"], tex("normal").outputs[0])
    g.put(bsdf.inputs["Normal"], nm.outputs[0])
    out = g.n("ShaderNodeOutputMaterial"); g.put(out.inputs["Surface"], bsdf.outputs[0])
    return mat


def finalize(objs, mat):
    for o in objs:
        me = o.data
        for nm in [l.name for l in me.uv_layers if l.name != "UVMap"]:
            me.uv_layers.remove(me.uv_layers[nm])
        for nm in ("grv", "pid", "bur"):
            if nm in me.attributes:
                me.attributes.remove(me.attributes[nm])
        old = [m for m in me.materials]
        me.materials.clear()
        me.materials.append(mat)
        for p in me.polygons:
            p.material_index = 0
        for m in old:
            if m and m.users == 0:
                bpy.data.materials.remove(m)


def bbox(objs):
    pts = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def studio(v):
    return [round(-v[0], 3), round(v[2], 3), round(v[1], 3)]


def studio_size(v):
    return [round(abs(v[0]), 3), round(abs(v[2]), 3), round(abs(v[1]), 3)]


def tris(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)


def scale_cube_marker():
    k = coll("Markers")
    me = bpy.data.meshes.new("K_ScaleCube")
    bm = bmesh.new(); bmesh.ops.create_cube(bm, size=10.0); bm.to_mesh(me); bm.free()
    cube = bpy.data.objects.new("K_ScaleCube", me); k.objects.link(cube); cube.location = (0, 30, 5)
    me = bpy.data.meshes.new("K_Marker")
    bm = bmesh.new()
    for c, s in (((5, 0, 1), (10, 2, 2)), ((1, 0, 4), (2, 2, 6)), ((1, 3, 1), (2, 4, 2))):  # long arm +X, upright +Z, short arm +Y
        r = bmesh.ops.create_cube(bm, size=1.0)
        bmesh.ops.scale(bm, vec=s, verts=r["verts"]); bmesh.ops.translate(bm, vec=c, verts=r["verts"])
    bm.to_mesh(me); bm.free()
    mk = bpy.data.objects.new("K_Marker", me); k.objects.link(mk); mk.location = (8, 30, 0)
    grey = bpy.data.materials.new("K_Grey")
    for o in (cube, mk):
        o.data.materials.append(grey)
    return cube, mk


def export_fbx(path, objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH"}, path_mode="COPY", embed_textures=True,
                             apply_unit_scale=True, axis_forward="-Z", axis_up="Y", add_leaf_bones=False, bake_anim=False,
                             mesh_smooth_type="OFF", use_mesh_modifiers=True)


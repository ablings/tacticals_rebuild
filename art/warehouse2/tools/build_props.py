"""Warehouse 2 prop kit: one-run generator. Runs inside Blender 4.5 or 5.2 (headless):
  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python art/warehouse2/tools/build_props.py -- [--nobake] [--res 1024] [--samples 16]

Builds every prop as low-poly closed meshes (1 unit = 1 stud, Z up, front = -Y), gives each a layered procedural material
(paint, wood planks, chips, rust, streaks, dirt, stencils from tex/decals), bakes them into one atlas per prop family
(colour with AO, roughness, metalness, tangent normal), swaps in the atlas material, lays the kit out as the assemblies the
map uses, and writes:
  art/warehouse2/warehouse2_props.blend
  art/warehouse2/tex/W2_<atlas>_{color,normal,rough,metal}.png
  art/warehouse2/fbx/W2_Props_kit.fbx (all assemblies + 10-stud scale cube + asymmetric marker), fbx/<assembly>.fbx (each at the origin)
  art/warehouse2/warehouse2_props.json (bbox centres and sizes, Blender and Studio axes, collision, what each replaces)
Blender (x, y, z) -> Studio (-x, z, y).
"""
import bpy, bmesh, math, random, json, os, sys, time
from mathutils import Vector, Matrix
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))
TEX = os.path.join(ROOT, "tex")
DEC = os.path.join(TEX, "decals")
FBXD = os.path.join(ROOT, "fbx")
BLEND = os.path.join(ROOT, "warehouse2_props.blend")
ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
def arg(k, d):
    return type(d)(ARGV[ARGV.index(k) + 1]) if k in ARGV else d
RES = arg("--res", 1024)
SAMPLES = arg("--samples", 16)
NOBAKE = "--nobake" in ARGV
DEVICES = arg("--device", "OPTIX,CUDA").split(",")   # OptiX fails silently on some driver/Blender pairs (black bakes): --device CUDA
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
DEF = dict(paint=None, under=(130, 130, 126), rust_col=((78, 40, 20), (128, 66, 30)), wood=False, groove=False, chip=0.0,
           rust=0.0, streak=0.0, stain=0.0, rough=0.6, under_rough=0.38, metal_paint=0.0, metal_under=0.0, dirt=0.45,
           dust=0.25, mottle=0.1, spangle=False, weave=False, bleach=0.0, tape=False, holes=False, tread=False, rope=False,
           heat=0.0, paintable=False, bump=0.5, slats=0.0)
K = {
    "wood_olive": dict(paint=(78, 82, 56), under=(120, 92, 60), wood=True, groove=True, chip=0.55, stain=0.3, rough=0.8,
                       under_rough=0.85, dirt=0.55, dust=0.15, mottle=0.09, paintable=True),
    "wood_raw": dict(under=(140, 118, 88), wood=True, groove=True, stain=0.45, rough=0.85, dirt=0.5, dust=0.3, mottle=0.16),
    "wood_top": dict(under=(104, 76, 50), wood=True, groove=True, stain=0.5, rough=0.62, dirt=0.6, mottle=0.12),
    "wood_pine": dict(under=(150, 118, 80), wood=True, groove=True, stain=0.45, rough=0.85, dirt=0.55, dust=0.2, mottle=0.14,
                      paintable=True),
    "wood_dark": dict(under=(96, 70, 46), wood=True, groove=True, stain=0.5, rough=0.82, dirt=0.55, dust=0.25, mottle=0.12,
                      paintable=True),
    "wood_grey": dict(paint=(104, 106, 104), under=(120, 92, 60), wood=True, groove=True, chip=0.55, stain=0.3, rough=0.8,
                      under_rough=0.85, dirt=0.55, dust=0.2, mottle=0.1, paintable=True),
    "steel_grey": dict(paint=(76, 79, 82), under=(140, 140, 136), chip=0.5, rust=0.32, streak=0.35, rough=0.58,
                       metal_under=1.0, dirt=0.5, dust=0.3, paintable=True),
    "fork_paint": dict(paint=(70, 68, 64), under=(140, 140, 136), chip=0.55, rust=0.35, streak=0.4, rough=0.55,
                       metal_under=1.0, dirt=0.55, dust=0.35, paintable=True),
    "plywood": dict(under=(150, 124, 88), wood=True, groove=False, stain=0.35, rough=0.8, dirt=0.4, dust=0.45),
    "steel_olive": dict(paint=(70, 74, 52), under=(140, 140, 136), chip=0.5, rust=0.3, streak=0.35, rough=0.6,
                        metal_under=1.0, dirt=0.5, dust=0.3, paintable=True),
    "steel_cap": dict(paint=(92, 92, 88), under=(152, 152, 148), chip=0.6, rust=0.45, streak=0.3, rough=0.5, metal_paint=0.6,
                      metal_under=1.0, dirt=0.5),
    "red_drum": dict(paint=(160, 30, 22), under=(130, 128, 124), chip=0.5, rust=0.42, streak=0.45, rough=0.5, metal_under=1.0,
                     dirt=0.5, mottle=0.1, paintable=True),
    "olive_drum": dict(paint=(74, 82, 50), under=(130, 128, 124), chip=0.5, rust=0.45, streak=0.4, rough=0.6, metal_under=1.0,
                       dirt=0.5, paintable=True),
    "grey_drum": dict(paint=(96, 100, 104), under=(140, 140, 138), chip=0.55, rust=0.5, streak=0.45, rough=0.55,
                      metal_under=1.0, dirt=0.5, paintable=True),
    "charred": dict(paint=(20, 18, 16), under=(84, 46, 24), rust_col=((44, 26, 16), (82, 42, 22)), chip=0.55, rust=0.28,
                    rough=0.92, dirt=0.3, heat=1.0, mottle=0.25, bump=0.8),
    "charred_in": dict(paint=(12, 11, 10), under=(46, 28, 16), chip=0.4, rust=0.3, rough=0.95, dirt=0.7, mottle=0.2),
    "fuel": dict(paint=(14, 10, 6), rough=0.05, dirt=0.0, dust=0.0, mottle=0.06, bump=0.1),
    "galv": dict(paint=(156, 158, 158), under=(176, 176, 174), chip=0.15, rust=0.22, streak=0.45, rough=0.5, metal_paint=0.55,
                 metal_under=1.0, spangle=True, dirt=0.5, dust=0.3, paintable=True),
    "gunmetal": dict(paint=(56, 58, 60), under=(140, 140, 136), chip=0.45, rust=0.18, streak=0.2, rough=0.55, metal_paint=0.2,
                     metal_under=1.0, dirt=0.5, dust=0.3, paintable=True),
    "steel_bare": dict(paint=(100, 100, 98), under=(152, 152, 150), chip=0.3, rust=0.35, rough=0.4, metal_paint=1.0,
                       metal_under=1.0, dirt=0.5, mottle=0.15),
    "rubber": dict(paint=(26, 26, 26), under=(26, 26, 26), rough=0.88, dirt=0.2, dust=0.6, tread=True, mottle=0.06, bump=0.8),
    "rope": dict(paint=(150, 126, 86), rope=True, rough=0.95, dirt=0.5, mottle=0.1, bump=0.8),
    "canvas": dict(paint=(98, 100, 98), weave=True, bleach=0.35, rough=0.9, dirt=0.55, dust=0.3, mottle=0.16, paintable=True),
    "burlap": dict(paint=(146, 124, 86), weave=True, rough=0.95, dirt=0.5, dust=0.2, mottle=0.12, paintable=True),
    "cardboard": dict(paint=(150, 112, 70), tape=True, rough=0.8, dirt=0.4, mottle=0.1, dust=0.3),
    "enamel_out": dict(paint=(64, 66, 68), under=(130, 130, 126), chip=0.45, rust=0.2, rough=0.35, metal_under=1.0, dirt=0.4, dust=0.5),
    "enamel_in": dict(paint=(214, 208, 192), under=(130, 130, 126), chip=0.2, rust=0.05, rough=0.3, dirt=0.75, dust=0.0),
    "black_drum": dict(paint=(34, 34, 33), under=(130, 128, 124), chip=0.55, rust=0.4, streak=0.4, rough=0.55,
                       metal_under=1.0, dirt=0.45, dust=0.45, paintable=True),
    "filler": dict(paint=(26, 24, 21), rough=0.95, dirt=0.2, dust=0.0, mottle=0.05),
    "galv_slat": dict(paint=(156, 158, 158), under=(176, 176, 174), chip=0.15, rust=0.22, streak=0.45, rough=0.5, metal_paint=0.55,
                      metal_under=1.0, spangle=True, dirt=0.5, dust=0.3, slats=0.42, bump=0.9),
    "alu": dict(paint=(178, 180, 180), under=(196, 196, 194), chip=0.1, rust=0.05, streak=0.2, rough=0.38, metal_paint=0.75,
                metal_under=1.0, dirt=0.45, dust=0.55, mottle=0.06),
    "wood_ply": dict(under=(168, 136, 96), wood=True, groove=False, stain=0.4, rough=0.82, dirt=0.5, dust=0.25, mottle=0.12,
                     paintable=True),
    "bulb": dict(paint=(250, 236, 205), rough=0.15, dirt=0.1, dust=0.0, mottle=0.02),
    "vinyl": dict(paint=(30, 30, 29), under=(72, 62, 46), chip=0.3, rough=0.5, dirt=0.4, mottle=0.08),
    "pegboard": dict(paint=(118, 98, 70), holes=True, rough=0.8, dirt=0.4, mottle=0.1),
    "lens": dict(paint=(204, 200, 186), rough=0.08, dirt=0.3, dust=0.2, mottle=0.02),
    "btn_red": dict(paint=(120, 26, 20), rough=0.4, dirt=0.3),
    "btn_green": dict(paint=(40, 80, 40), rough=0.4, dirt=0.3),
}
for k_ in K:
    d_ = dict(DEF); d_.update(K[k_]); K[k_] = d_


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

    # stencils / labels: sprayed on the paint, so they wear with it
    for i, d in decals:
        im = bpy.data.images.load(os.path.join(DEC, d["img"] + ".png"), check_existing=True)
        im.alpha_mode = "STRAIGHT"
        tx = g.n("ShaderNodeTexImage", image=im, extension="CLIP", interpolation="Linear")
        g.put(tx.inputs[0], g.uv(f"D{i}"))
        a = g.m("MULTIPLY", tx.outputs["Alpha"], d["op"])
        a = g.m("MULTIPLY", a, g.mr(g.noise(obj, 2.2, 3), 0.35, 0.65, 0.75, 1.0))
        dc = g.rgb(d["col"]) if d["col"] else tx.outputs["Color"]
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

    bsdf = g.n("ShaderNodeBsdfPrincipled")
    g.put(bsdf.inputs["Base Color"], col)
    g.put(bsdf.inputs["Roughness"], rough)
    g.put(bsdf.inputs["Metallic"], metal)
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


def finish(mb, loc=(0, 0, 0)):
    apply_decals(mb)
    bm = mb.bm
    bm.normal_update()
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


# --- barrels --------------------------------------------------------------------------------------------------------
def drum_profile(bulge=0.0, H=3.4):
    """55-gallon drum lathe profile for height H: chimes top and bottom, two rolling hoops"""
    k = H / 3.4
    P = [(0.0, 0.0), (0.97, 0.0), (1.04, 0.05), (1.04, 0.16), (1.0, 0.2)]
    body = [0.45, 0.75, 1.08, None, 1.3, 1.55, 1.8, 2.05, 2.15, None, 2.37, 2.6, 2.85, 3.1, 3.2]
    for z in body:
        if z is None:
            zz = P[-1][1]
            P += [(1.05, zz + 0.05), (1.05, zz + 0.17), (1.0, zz + 0.22)]
            continue
        z *= k
        if z > P[-1][1] + 0.01 and z < H - 0.2:
            P.append((1.0 + bulge * math.sin(math.pi * z / (3.3 * k)), z))
    P += [(1.04, H - 0.16), (1.04, H), (0.95, H), (0.93, H - 0.1), (0.0, H - 0.1)]
    return P

def dents(spec):
    def f(v):
        r = math.hypot(v.x, v.y)
        if r < 0.9 or v.z < 0.25 or v.z > 3.15:
            return v
        a = math.atan2(v.y, v.x)
        d = 0.0
        for (a0, z0, depth, sa, sz) in spec:
            da = (a - a0 + math.pi) % (2 * math.pi) - math.pi
            d += depth * math.exp(-(da * 1.0) ** 2 / (2 * sa * sa) - (v.z - z0) ** 2 / (2 * sz * sz))
        k = max(0.0, r - d) / r
        return Vector((v.x * k, v.y * k, v.z))
    return f

FRONT = -math.pi / 2  # angle of the -Y side

def fire_barrel():
    mb = MB("W2_FireBarrel", "Barrels", 3.4)
    prof = drum_profile()
    mb.lathe(prof, 24, "red_drum", deform=dents([(0.9, 1.75, 0.2, 0.32, 0.3), (-2.4, 0.8, 0.15, 0.3, 0.25), (2.6, 2.75, 0.12, 0.3, 0.2),
                                                 (-0.6, 2.9, 0.1, 0.25, 0.15)]),
             kindfn=lambda f: "steel_cap" if f.calc_center_median().z > 3.2 else "red_drum")
    mb.lathe([(0.0, 3.26), (0.19, 3.26), (0.19, 3.38), (0.0, 3.38)], 10, "steel_cap", M=Matrix.Translation((0.42, -0.42, 0)))
    mb.decal_cyl("lbl_flammable", FRONT, 1.75, 1.0, 0.95, 0.95, rough=0.4)
    mb.decal_cyl("lbl_flammable", math.pi / 2, 1.75, 1.0, 0.95, 0.95, rough=0.4)
    mb.decal_cyl("st_fuel", 0.0, 1.75, 1.0, 1.5, 0.62, col=(236, 232, 218))
    mb.decal_cyl("st_fuel", math.pi, 1.75, 1.0, 1.5, 0.62, col=(236, 232, 218))
    mb.decal_cyl("fx_drip", -math.pi / 4, 2.65, 1.0, 0.75, 1.5, col=(30, 14, 8), op=0.8, rough=0.08, kinds=["red_drum"])
    return finish(mb)

def puddle():
    """spilled fuel lens: a thin rounded edge rising to 0.12, so the top stays 0.12 off the floor (A8)"""
    mb = MB("W2_FireBarrel_Puddle", "Barrels", 0.12)
    rnd = random.Random(5)
    pts = []
    for i in range(36):
        a = 2 * math.pi * i / 36
        r = 1.45 + 0.3 * math.sin(3 * a + 1) + 0.12 * math.sin(5 * a + 2) + rnd.uniform(-0.03, 0.03)
        r += 0.75 * max(0.0, math.cos(a - (-math.pi / 4))) ** 3
        pts.append((r * math.cos(a), r * math.sin(a)))
    rings = [(1.0, 0.0), (0.985, 0.05), (0.955, 0.1), (0.92, 0.12)]
    n = len(pts)
    verts = []
    for sc, z in rings:
        verts += [Vector((x * sc, y * sc, z)) for x, y in pts]
    faces = [tuple(range(n))[::-1], tuple(range(3 * n, 4 * n))]
    for k in range(3):
        faces += [(k * n + i, k * n + (i + 1) % n, (k + 1) * n + (i + 1) % n, (k + 1) * n + i) for i in range(n)]
    mb.raw(verts, faces, "fuel")
    return finish(mb)

def burnt_barrel():
    """the fire barrel after the blast: bulged, hoops kept, a crumple on one side, the top torn in uneven tongues with
    three petals peeled outward; double wall so the torn edge has thickness and the inside reads charred"""
    mb = MB("W2_FireBarrel_Burnt", "Barrels", 3.2)
    segs, rnd = 28, random.Random(17)
    zs = [0.2, 0.6, 1.0, 1.08, 1.13, 1.25, 1.3, 1.7, 2.1, 2.15, 2.2, 2.32, 2.37, 2.5]
    def hoop(z):
        return 0.05 if (1.13 <= z <= 1.25 or 2.2 <= z <= 2.32) else 0.0
    def rad(z, a):
        r = 1.0 + 0.04 * math.sin(math.pi * z / 2.7)
        da = (a - 2.2 + math.pi) % (2 * math.pi) - math.pi
        r -= 0.17 * math.exp(-da * da / 0.2 - (z - 1.6) ** 2 / 0.45)
        db = (a - 5.0 + math.pi) % (2 * math.pi) - math.pi
        r += 0.12 * math.exp(-db * db / 0.35 - (z - 1.4) ** 2 / 0.6)     # blast bulge
        return r
    petals = {4: 0.6, 5: 0.95, 6: 0.55, 19: 0.75, 20: 0.5}
    split = {11: 1.35, 10: 2.05, 12: 2.15}          # one tall tear down the side
    tops, flare = [], []
    for i in range(segs):
        p = petals.get(i, 0.0)
        t = 2.62 + 0.07 * math.sin(i * 0.9) + rnd.uniform(0.0, 0.06) + 0.4 * p
        tops.append(split.get(i, t))
        flare.append(0.04 + 0.45 * p + (0.12 if i in split else 0.0))
    verts, faces = [], []
    def ring(z, off=0.0, top=False, outer=True):
        ids = []
        for i in range(segs):
            a = 2 * math.pi * i / segs
            if top:
                zz = tops[i]; r = rad(2.5, a) + flare[i] - off
            else:
                zz = z if z <= 0.6 else 0.6 + (z - 0.6) * min(1.0, (tops[i] - 0.72) / 1.9); r = rad(zz, a) + (hoop(zz) if outer else 0.0) - off
            ids.append(len(verts)); verts.append(Vector((r * math.cos(a), r * math.sin(a), zz)))
        return ids
    bot = len(verts); verts.append(Vector((0, 0, 0.0)))
    chime = []
    for (r, z) in [(0.97, 0.0), (1.04, 0.05), (1.04, 0.16)]:
        ids = []
        for i in range(segs):
            a = 2 * math.pi * i / segs
            ids.append(len(verts)); verts.append(Vector((r * math.cos(a), r * math.sin(a), z)))
        chime.append(ids)
    outer = [ring(z) for z in zs] + [ring(0, top=True)]
    inner = [ring(0, off=0.07, top=True, outer=False)] + [ring(z, off=0.07, outer=False) for z in reversed(zs[1:])]
    floor_c = len(verts); verts.append(Vector((0, 0, 0.6)))
    rings = chime + outer + inner
    for i in range(segs):
        faces.append((bot, chime[0][(i + 1) % segs], chime[0][i]))
    for A, B in zip(rings, rings[1:]):
        faces += [(A[i], A[(i + 1) % segs], B[(i + 1) % segs], B[i]) for i in range(segs)]
    last = inner[-1]
    for i in range(segs):
        faces.append((last[i], last[(i + 1) % segs], floor_c))
    def kind(f):
        c = f.calc_center_median()
        r = math.hypot(c.x, c.y)
        return "charred_in" if (f.normal.x * c.x + f.normal.y * c.y) < -0.1 or (f.normal.z > 0.5 and r < 0.9 and c.z < 0.7) else "charred"
    mb.raw(verts, faces, "charred", pl="cyl", center=(0, 0, 0), kindfn=kind)
    return finish(mb)

def burnt_lid():
    mb = MB("W2_FireBarrel_BurntLid", "Barrels", 0.4)
    def bend(v):
        return Vector((v.x, v.y, v.z + 0.16 * (v.x / 0.95) ** 2 - 0.05 * v.y))
    mb.lathe([(0.0, 0.0), (0.9, 0.0), (0.98, 0.04), (0.98, 0.12), (0.9, 0.1), (0.0, 0.08)], 20, "charred", deform=bend)
    return finish(mb)

def oil_drum(name, kind, dent, decals, H=3.0):
    """plain (not shootable) drum: 3.0 high (kit brief) so its outline differs from the 3.4 fire barrel; black or olive"""
    mb = MB(name, "Barrels", H)
    mb.lathe(drum_profile(H=H), 24, kind, deform=dents(dent))
    mb.lathe([(0.0, H - 0.14), (0.19, H - 0.14), (0.19, H - 0.02), (0.0, H - 0.02)], 10, kind, M=Matrix.Translation((-0.42, 0.42, 0)))
    for d in decals:
        mb.decal_cyl(*d[0], **d[1])
    return finish(mb)

# --- crates ---------------------------------------------------------------------------------------------------------
def wood_crate(name, L, D, H, cleats_x=(), band_z=(), diagonals=False, rope_z=None, caps=True, atlas="CratesWood",
               wood="wood_olive", skids=False):
    mb = MB(name, atlas, H)
    z_base, SK = 0.0, 0.4
    if skids:      # build the box SK shorter, lift it onto two runners at the end
        H = H - SK
    ct, bt, w = 0.06, 0.14, 0.34       # cap thickness (frame plane 0.08 inside the cover box: brief allows 0.1), batten thickness, frame bar width
    X, Y = L / 2, D / 2
    o = ct + bt                        # panel face inset from the bbox
    pr = o + 0.02                      # panel recess: cleats 0.03, bands 0.06, braces 0.09 behind the frame plane, all proud of it
    mb.boxr((-X + pr, -Y + pr, pr), (X - pr, Y - pr, H - 0.09), wood, grain=0, groove=1.0)   # lid boards just under the frame top (no open-tray look)
    e = ct                             # battens' outer faces
    # 12 frame bars
    for sy in (-1, 1):
        for sz in (0, 1):
            z0 = 0.0 if sz == 0 else H - w
            y0 = -Y + e if sy < 0 else Y - e - w
            mb.boxr((-X + e + 0.02, y0, z0), (X - e - 0.02, y0 + w, z0 + w), wood, grain=0)
    for sx in (-1, 1):
        for sz in (0, 1):
            z0 = 0.0 if sz == 0 else H - w
            x0 = -X + e if sx < 0 else X - e - w
            mb.boxr((x0, -Y + e + w, z0), (x0 + w, Y - e - w, z0 + w), wood, grain=1)   # butts the front/back boards
    for sx in (-1, 1):
        for sy in (-1, 1):
            x0 = -X + e if sx < 0 else X - e - w
            y0 = -Y + e if sy < 0 else Y - e - w
            mb.boxr((x0, y0, e), (x0 + w, y0 + w, H - e), wood, grain=2)
    for cx in cleats_x:   # vertical cleats on the long faces
        for sy in (-1, 1):
            y0, y1 = (-Y + e + 0.03, -Y + e + bt + 0.03) if sy < 0 else (Y - e - bt - 0.03, Y - e - 0.03)
            mb.boxr((cx - w / 2, y0, w - 0.05), (cx + w / 2, y1, H - w + 0.05), wood, grain=2)
    for bz in band_z:     # horizontal bands all round
        for sy in (-1, 1):
            y0, y1 = (-Y + e + 0.06, -Y + e + bt + 0.03) if sy < 0 else (Y - e - bt - 0.03, Y - e - 0.06)
            mb.boxr((-X + e + w - 0.05, y0, bz - w / 2), (X - e - w + 0.05, y1, bz + w / 2), wood, grain=0)
        for sx in (-1, 1):
            x0, x1 = (-X + e + 0.06, -X + e + bt + 0.03) if sx < 0 else (X - e - bt - 0.03, X - e - 0.06)
            mb.boxr((x0, -Y + e + w - 0.05, bz - w / 2), (x1, Y - e - w + 0.05, bz + w / 2), wood, grain=1)
    if diagonals:         # Z braces on the long faces, one per panel between bands
        levels = [w] + [b for b in band_z] + [H - w]
        for k in range(len(levels) - 1):
            z0 = levels[k] + (w / 2 if k > 0 else 0)
            z1 = levels[k + 1] - (w / 2 if k + 1 < len(levels) - 1 else 0)
            x0, x1 = -X + e + w, X - e - w
            dx, dz = x1 - x0, z1 - z0
            ln = math.hypot(dx, dz) - w * 0.9
            ang = math.atan2(dz, dx) * (1 if k % 2 == 0 else -1)
            R = Matrix.Rotation(-ang, 3, "Y")
            for sy in (-1, 1):
                yc = -Y + e + 0.09 + bt / 2 if sy < 0 else Y - e - 0.09 - bt / 2
                mb.box(((x0 + x1) / 2, yc, (z0 + z1) / 2), (ln, bt, w * 0.9), wood, R=R, grain=0)
    if caps:              # one solid steel corner block per corner (a single closed box: nothing coplanar)
        cs = 0.5
        for sx in (-1, 1):
            for sy in (-1, 1):
                for sz in (0, 1):
                    xo, yo = X * sx, Y * sy
                    z0c, z1c = (H - cs, H - 0.03) if sz else (0.03, cs)   # 0.03 inside the top/bottom battens: crates stack on boards
                    mb.boxr((min(xo, xo - sx * cs), min(yo, yo - sy * cs), z0c), (max(xo, xo - sx * cs), max(yo, yo - sy * cs), z1c), "steel_cap")
    if rope_z is not None:  # rope handles on the short ends: two cleats and a sagging loop
        for sx in (-1, 1):
            xf = sx * (X - o)
            for sy in (-1, 1):
                mb.boxr((min(xf - sx * 0.06, xf + sx * 0.2), sy * 0.42 - 0.13, rope_z - 0.12), (max(xf - sx * 0.06, xf + sx * 0.2), sy * 0.42 + 0.13, rope_z + 0.16), wood)
            path = []
            for k in range(9):
                t = k / 8
                yy = -0.42 + 0.84 * t
                path.append((xf + sx * (0.06 + 0.06 * math.sin(math.pi * t)), yy, rope_z + 0.02 - 0.34 * math.sin(math.pi * t)))
            mb.tube(path, 0.07, "rope", segs=6)
    if skids:
        bmesh.ops.translate(mb.bm, vec=(0, 0, SK), verts=mb.bm.verts[:])
        for sy in (-1, 1):
            yc = sy * (D / 2 - 0.39)          # runners along the long edges (0.03 inside the frame plane)
            mb.boxr((-L / 2 + 0.11, yc - 0.3, 0.0), (L / 2 - 0.11, yc + 0.3, SK + 0.03), "wood_raw", grain=0)
        for sx in (-1, 1):   # end boards between the runners close the space under the crate
            x0, x1 = sorted((sx * (L / 2 - 0.15), sx * (L / 2 - 0.45)))
            mb.boxr((x0, -(D / 2 - 0.63), 0.03), (x1, D / 2 - 0.63, SK + 0.05), "wood_raw", grain=1)
        mb.height = H + SK
    return mb


def steel_crate(name, L, D, H):
    mb = MB(name, "CratesSteel", H)
    X, Y = L / 2, D / 2
    lid = 0.58
    mb.boxr((-X + 0.1, -Y + 0.1, 0.14), (X - 0.1, Y - 0.1, H - lid + 0.05), "steel_grey", grain=0)
    mb.boxr((-X, -Y, H - lid), (X, Y, H), "steel_grey", grain=0)
    for sy in (-1, 1):   # skids
        mb.boxr((-X + 0.06, sy * Y * 0.55 - 0.22, 0.0), (X - 0.06, sy * Y * 0.55 + 0.22, 0.18), "gunmetal", grain=0)
    for z in (1.0, H - lid - 0.95):   # pressed stiffening ribs all round
        mb.boxr((-X + 0.06, -Y + 0.06, z - 0.09), (X - 0.06, Y - 0.06, z + 0.09), "steel_grey", grain=0)
    for sx in (-1, 1):   # corner posts
        for sy in (-1, 1):
            x0, x1 = sorted((sx * (X - 0.3), sx * (X - 0.03)))
            y0, y1 = sorted((sy * (Y - 0.3), sy * (Y - 0.03)))
            mb.boxr((x0, y0, 0.11), (x1, y1, H - lid + 0.03), "gunmetal", grain=2)
    for sy in (-1, 1):   # latches under the lid lip
        for lx in (-L / 4, L / 4):
            y0, y1 = (-(Y - 0.03), -(Y - 0.16)) if sy < 0 else (Y - 0.16, Y - 0.03)
            mb.boxr((lx - 0.2, min(y0, y1), H - lid - 0.42), (lx + 0.2, max(y0, y1), H - lid + 0.12), "gunmetal")
    for sx in (-1, 1):   # folding handles on the ends
        xf = sx * (X - 0.1)
        hz = H - lid - 0.6
        mb.tube([(xf - sx * 0.02, -0.5, hz), (xf + sx * 0.045, -0.5, hz - 0.05), (xf + sx * 0.045, 0.5, hz - 0.05), (xf - sx * 0.02, 0.5, hz)], 0.05, "gunmetal")
    return mb


def ammo_can():
    mb = MB("W2_AmmoCan", "CratesSteel", 1.2)
    X, Y = 1.2, 0.9
    mb.boxr((-X + 0.06, -Y + 0.06, 0.0), (X - 0.06, Y - 0.06, 0.95), "steel_olive", grain=0)
    mb.boxr((-X, -Y, 0.88), (X, Y, 1.06), "steel_olive", grain=0)
    for z in (0.3,):
        mb.boxr((-X + 0.02, -Y + 0.02, z - 0.07), (X - 0.02, Y - 0.02, z + 0.07), "steel_olive", grain=0)
    mb.tube([(-0.35, 0, 1.03), (-0.3, 0, 1.155), (0.3, 0, 1.155), (0.35, 0, 1.03)], 0.04, "gunmetal")
    mb.boxr((X - 0.09, -0.22, 0.55), (X - 0.03, 0.22, 1.0), "gunmetal")
    mb.decal("st_ammocan", (0, -1, 0), (0, -Y, 0.62), 1.9, 0.5, col=(236, 232, 218))
    mb.decal("st_ammocan", (0, 1, 0), (0, Y, 0.62), 1.9, 0.5, col=(236, 232, 218))
    mb.decal("st_id103", (0, 0, 1), (0, -0.45, 1.06), 1.0, 0.25, col=(20, 20, 18), depth=0.2)
    return finish(mb)


# --- roll-up door ---------------------------------------------------------------------------------------------------
DOOR_HW, DOOR_H = 10.0, 14.0   # Warehouse 2 openings 20 x 14 (fix/map_warehouse2.lua DOOR_HALF, DOOR_H)
CTRL_DX = -12.2                 # control box: left of the opening

def door_frame():
    """side guides (the jambs), drum housing over the opening, end brackets. Origin: opening centre on the floor,
    y = 0 = the end wall's inside face (back faces sit 0.05 into the wall), room side = -Y."""
    mb = MB("W2_RollDoor_Frame", "Door", 16.2)
    HW, H = DOOR_HW, DOOR_H
    for sx in (-1, 1):
        x0, x1 = sorted((sx * HW, sx * (HW + 0.6)))
        mb.boxr((x0, -0.62, 0.0), (x1, 0.08, H + 0.55), "galv", grain=2)
        mb.boxr((min(sx * (HW + 0.55), sx * (HW + 0.95)), -0.12, 0.3), (max(sx * (HW + 0.55), sx * (HW + 0.95)), 0.05, H + 0.5), "galv", grain=2)
    R, z0 = 1.1, H
    prof = [(0.02, z0), (-1.3, z0)]
    for k in range(1, 13):
        a = -math.pi / 2 + math.pi * k / 12
        prof.append((-1.3 - R * math.cos(a), z0 + R + R * math.sin(a)))
    prof.append((0.02, z0 + 2 * R))
    mb.prism(prof, "X", -(HW + 0.75), HW + 0.75, "galv", grain=0)
    big = [((y - 0.08) if y < -0.1 else 0.11, z + (0.08 if z > z0 + R else -0.08)) for y, z in prof]   # end plates: back 0.05 into the wall
    for sx in (-1, 1):
        a0, a1 = sorted((sx * (HW + 0.65), sx * (HW + 0.9)))
        mb.prism(big, "X", a0, a1, "gunmetal")
    mb.decal("hz_stripes_v", (0, -1, 0), (-(HW + 0.3), -0.62, 0.8), 0.6, 1.6, rough=0.5, kinds=["galv"], depth=0.1)
    mb.decal("hz_stripes_v", (0, -1, 0), (HW + 0.3, -0.62, 0.8), 0.6, 1.6, rough=0.5, kinds=["galv"], depth=0.1)
    mb.decal("st_bay02", (0, -1, 0), (-5.5, -2.4, z0 + R), 4.0, 1.0, col=(236, 232, 218), kinds=["galv"], depth=0.6)
    return finish(mb)

def door_bar(name, z0):
    return [((-(DOOR_HW + 0.25), -0.5, z0), (DOOR_HW + 0.25, -0.24, z0 + 0.4))]

def door_bottom_bar():
    mb = MB("W2_RollDoor_BottomBar", "Door", 0.5)
    for lo, hi in door_bar("", 0.0):
        mb.boxr(lo, hi, "gunmetal", grain=0)
    mb.tube([(-0.35, -0.5, 0.06), (-0.3, -0.68, 0.06), (0.3, -0.68, 0.06), (0.35, -0.5, 0.06)], 0.05, "steel_bare")
    ob = finish(mb)
    return ob

def door_curtain_half():
    """corrugated slat curtain (real ridges) with its bottom bar; the top runs up into the housing"""
    mb = MB("W2_RollDoor_Curtain_Half", "DoorCurtain", 7.6)
    z0, z1, per = 0.36, 7.6, 0.42
    front = []
    z = z0
    while z < z1 - 0.01:
        front += [(-0.31, z), (-0.31, z + 0.06), (-0.43, z + 0.12), (-0.43, z + per - 0.12), (-0.31, z + per - 0.06)]
        z += per
    front.append((-0.31, z1))
    F = clean_poly(front)
    if F[-1][1] < z1 - 1e-6:
        F.append((-0.31, z1))
    n = len(F)
    X = DOOR_HW + 0.28
    verts = []
    for x in (-X, X):
        verts += [Vector((x, y, z)) for (y, z) in F] + [Vector((x, -0.27, z)) for (y, z) in F]
    o = 2 * n
    faces = []
    for i in range(n - 1):
        faces.append((i, i + 1, o + i + 1, o + i))
        faces.append((n + i, n + i + 1, o + n + i + 1, o + n + i))
        faces.append((i, i + 1, n + i + 1, n + i))
        faces.append((o + i, o + i + 1, o + n + i + 1, o + n + i))
    faces.append((0, n, o + n, o)); faces.append((n - 1, 2 * n - 1, o + 2 * n - 1, o + n - 1))
    # the yard side is flat geometry with the slats baked in (ridge bump + groove shading, same 0.42 pitch)
    mb.raw(verts, faces, "galv", grain=0, kindfn=lambda f: "galv_slat" if f.normal.y > 0.9 else "galv")
    for lo, hi in door_bar("", 0.0):
        mb.boxr(lo, hi, "gunmetal", grain=0)
    mb.tube([(-0.35, -0.5, 0.06), (-0.3, -0.68, 0.06), (0.3, -0.68, 0.06), (0.35, -0.5, 0.06)], 0.05, "steel_bare")
    mb.decal("st_keepclear", (0, -1, 0), (4.0, -0.43, 1.3), 5.0, 0.95, col=(236, 232, 218), op=0.8, kinds=["galv"], depth=0.3)
    return finish(mb)

def door_control():
    mb = MB("W2_RollDoor_Control", "Door", 15.2)
    mb.boxr((-0.45, -0.38, 0.0), (0.45, 0.03, 1.3), "gunmetal", grain=2)
    mb.boxr((-0.38, -0.44, 0.08), (0.38, -0.36, 1.22), "gunmetal", grain=2)
    for z, kd in ((0.85, "btn_green"), (0.5, "btn_red")):
        mb.lathe([(0.0, 0.0), (0.15, 0.0), (0.15, 0.12), (0.0, 0.12)], 10, kd,
                 M=Matrix.Translation((0, -0.4, z)) @ Matrix.Rotation(math.pi / 2, 4, "X"))
    zc = DOOR_H + 1.1 - 4.25
    mb.tube([(0.0, -0.15, 1.25), (0.0, -0.15, zc), (-CTRL_DX - DOOR_HW - 0.68, -0.15, zc)], 0.07, "galv", segs=8)
    return finish(mb)

# --- clutter --------------------------------------------------------------------------------------------------------
def wall_filler():
    """dark block in the joint between the two lower crates of the wall stack: the gap between their recessed
    bodies would otherwise be a see-through slit in tall cover"""
    mb = MB("W2_WallJoint", "CratesSteel", 3.3)
    mb.boxr((-0.34, -1.37, 0.06), (0.34, 1.37, 3.53), "filler", grain=2)
    return finish(mb)


def pallet(name="W2_Pallet"):
    mb = MB(name, "ClutterA", 0.6)
    for y in (-1.45, 0.0, 1.45):
        mb.boxr((-2.0 + 0.02, y - 0.25, 0.0), (2.0 - 0.02, y + 0.25, 0.12), "wood_raw", grain=0)
    for x in (-1.72, 0.0, 1.72):
        for y in (-1.45, 0.0, 1.45):
            mb.boxr((x - 0.22, y - 0.18, 0.1), (x + 0.22, y + 0.18, 0.42), "wood_raw", grain=2)
        mb.boxr((x - 0.25, -1.66, 0.4), (x + 0.25, 1.66, 0.5), "wood_raw", grain=1)
    for y in (-1.45, -0.725, 0.0, 0.725, 1.45):
        mb.boxr((-2.0, y - 0.25, 0.48), (2.0, y + 0.25, 0.6), "wood_raw", grain=0)
    return finish(mb)

def sack_geo(c, size, rnd):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=2, use_grid_fill=True)
    vs, fs = [], []
    idx = {}
    for v in bm.verts:
        p = v.co * 2.0   # -1..1
        q = Vector((p.x * (1 - 0.12 * p.y * p.y - 0.25 * p.z * p.z), p.y * (1 - 0.12 * p.x * p.x - 0.3 * p.z * p.z), p.z * (1 - 0.18 * p.x * p.x - 0.18 * p.y * p.y)))
        q.z -= 0.08 * (1 - p.x * p.x)
        idx[v] = len(vs)
        vs.append(Vector((c[0] + q.x * size[0] / 2 + rnd.uniform(-0.02, 0.02), c[1] + q.y * size[1] / 2, c[2] + q.z * size[2] / 2)))
    for f in bm.faces:
        fs.append(tuple(idx[v] for v in f.verts))
    bm.free()
    return vs, fs

def pallet_sacks():
    mb = MB("W2_PalletSacks_Load", "ClutterA", 2.3)
    rnd = random.Random(21)
    sw, sd, sh = 1.99, 1.13, 0.52
    sacks = []
    for layer in range(3):
        z = 0.58 + sh / 2 + layer * (sh - 0.06)
        rot = layer % 2
        for i in range(2):
            for j in range(3):
                if rot == 0:
                    c = (-0.98 + i * 1.96 + rnd.uniform(-0.04, 0.04), -1.1 + j * 1.1, z)
                    vs, fs = sack_geo(c, (sw, sd, sh), rnd)
                else:
                    c = (-0.98 + i * 1.96, -1.1 + j * 1.1 + rnd.uniform(-0.04, 0.04), z)
                    vs, fs = sack_geo(c, (sw - 0.05, sd, sh), rnd)
                sacks.append((vs, fs, layer))
    for vs, fs, layer in sacks:
        mb.raw(vs, fs, "burlap", center=sum(vs, Vector()) / len(vs))
    # tarp: a subdivided box shrink-wrapped over the top two layers, relaxed so it bridges the dips, hem flared
    tmp_me = bpy.data.meshes.new("_sacks")
    allv, allf = [], []
    for vs, fs, layer in sacks:
        if layer >= 1:
            o = len(allv); allv += vs; allf += [tuple(i + o for i in f) for f in fs]
    tmp_me.from_pydata([tuple(v) for v in allv], [], allf)
    tgt = bpy.data.objects.new("_sacks", tmp_me); bpy.context.scene.collection.objects.link(tgt)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(4.2, 3.6, 1.25), verts=bm.verts)
    bmesh.ops.translate(bm, vec=(0, 0, 1.12 + 0.625), verts=bm.verts)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=9, use_grid_fill=True)
    tme = bpy.data.meshes.new("_tarp"); bm.to_mesh(tme); bm.free()
    tarp = bpy.data.objects.new("_tarp", tme); bpy.context.scene.collection.objects.link(tarp)
    m1 = tarp.modifiers.new("sw", "SHRINKWRAP"); m1.target = tgt; m1.wrap_method = "NEAREST_SURFACEPOINT"; m1.wrap_mode = "OUTSIDE_SURFACE"; m1.offset = 0.05
    m2 = tarp.modifiers.new("sm", "SMOOTH"); m2.factor = 0.8; m2.iterations = 6
    m3 = tarp.modifiers.new("sw2", "SHRINKWRAP"); m3.target = tgt; m3.wrap_method = "NEAREST_SURFACEPOINT"; m3.wrap_mode = "OUTSIDE_SURFACE"; m3.offset = 0.09
    dg = bpy.context.evaluated_depsgraph_get()
    ev = tarp.evaluated_get(dg)
    em = bpy.data.meshes.new_from_object(ev)
    rnd2 = random.Random(3)
    tv, tf = [], []
    for v in em.vertices:
        p = v.co.copy()
        n = v.normal
        wr = 0.05 * math.sin(p.x * 5.3 + p.y * 2.1) * math.sin(p.y * 4.7 - p.z * 3.0)
        p += n * wr
        if p.z < 1.3:
            flare = (1.3 - p.z) / 0.25
            p.x *= 1 + 0.025 * flare; p.y *= 1 + 0.03 * flare
        tv.append(p)
    tf = [tuple(poly.vertices) for poly in em.polygons]
    for ob in (tarp, tgt):
        bpy.data.objects.remove(ob)
    for me in (tme, tmp_me, em):
        bpy.data.meshes.remove(me)
    mb.raw(tv, tf, "canvas", center=(0, 0, 1.5))
    mb.decal("st_emblem", (0, -1, 0), (0.9, -1.8, 1.75), 0.9, 0.9, col=(20, 20, 18), op=0.7, kinds=["canvas"], depth=0.6)
    mb.decal("st_sandbag", (0, -1, 0), (-1.0, -1.7, 0.85), 0.8, 0.4, col=(40, 34, 26), op=0.75, kinds=["burlap"], depth=0.3)
    return finish(mb)

TYRE = [(0.62, -0.30), (0.75, -0.40), (0.95, -0.43), (1.10, -0.40), (1.18, -0.33), (1.2, -0.15), (1.2, 0.15), (1.18, 0.33),
        (1.10, 0.40), (0.95, 0.43), (0.75, 0.40), (0.62, 0.30), (0.58, 0.15), (0.58, -0.15)]

def tyre():
    mb = MB("W2_Tyre", "ClutterA", 0.86)
    mb.revolve(TYRE, 28, "rubber", M=Matrix.Translation((0, 0, 0.43)), r_ref=1.2,
               groovefn=lambda f: 1.0 if math.hypot(*f.calc_center_median().xy) > 1.16 else 0.0)
    return finish(mb)

def shelf_rack():
    mb = MB("W2_ShelfRack", "Rack", 8.0)
    xs = (-3.875, 0.0, 3.875)
    for x in xs:
        for y in (-1.0, 1.0):
            mb.boxr((x - 0.125, y - 0.125, 0.0), (x + 0.125, y + 0.125, 8.0), "gunmetal", grain=2)
        for z in (0.25, 7.8):
            mb.boxr((x - 0.07, -0.92, z - 0.08), (x + 0.07, 0.92, z + 0.08), "gunmetal", grain=1)
        for k in range(3):
            z0, z1 = 0.4 + k * 2.4, 2.6 + k * 2.4
            ang = math.atan2(z1 - z0, 1.85) * (1 if k % 2 == 0 else -1)
            mb.box((x, 0, (z0 + z1) / 2), (0.1, math.hypot(1.85, z1 - z0) - 0.1, 0.12), "gunmetal", R=Matrix.Rotation(ang, 3, "X"), grain=1)
    levels = (0.55, 2.95, 5.35, 7.65)
    for z in levels:
        for y in (-1, 1):
            y0, y1 = sorted((y * 1.12, y * 1.25))
            mb.boxr((-3.97, y0, z - 0.3), (3.97, y1, z), "galv", grain=0)
        for bx in ((-3.85, 3.85),):
            mb.boxr((bx[0] - 0.03, -1.16, z - 0.03), (bx[1] + 0.03, 1.16, z + 0.09), "plywood", grain=0)
    mb.decal("st_capacity", (0, -1, 0), (-1.95, -1.25, 2.8), 1.5, 0.3, col=(20, 20, 18), kinds=["galv"], depth=0.2)
    mb.decal("st_capacity", (0, -1, 0), (1.95, -1.25, 5.2), 1.5, 0.3, col=(20, 20, 18), kinds=["galv"], depth=0.2)
    return finish(mb)

def rack_load():
    mb = MB("W2_ShelfRack_Load", "Rack", 7.6)
    rnd = random.Random(8)
    levels = (0.55, 2.95, 5.35)
    for li, z in enumerate(levels):
        for bx0, bx1 in ((-3.6, -0.3), (0.3, 3.6)):
            x = bx0
            while x < bx1 - 0.7:
                w = min(rnd.uniform(0.8, 1.5), bx1 - x)
                d = rnd.uniform(1.0, 1.9)
                h = rnd.uniform(0.6, 1.4) if li < 2 else rnd.uniform(0.5, 1.0)
                if rnd.random() < 0.82:
                    yc = rnd.uniform(-1.05 + d / 2, 1.05 - d / 2)
                    mb.box((x + w / 2, yc, z + 0.09 + h / 2), (w - 0.04, d, h), "cardboard", grain=0)
                    if h < 0.9 and rnd.random() < 0.5:
                        w2, d2, h2 = w * 0.8, d * 0.7, rnd.uniform(0.4, 0.7)
                        mb.box((x + w / 2 + rnd.uniform(-0.05, 0.05), yc, z + 0.09 + h + h2 / 2 - 0.03), (w2, d2, h2), "cardboard", grain=0)
                x += w + rnd.uniform(0.15, 0.4)
    return finish(mb)

def workbench():
    mb = MB("W2_Workbench", "ClutterB", 4.75)
    mb.boxr((-3.0, -1.2, 2.6), (3.0, 1.0, 2.86), "wood_top", grain=0, groove=1.0)
    for x in (-2.75, 2.75):
        mb.boxr((x - 0.11, -1.06, 0.0), (x + 0.11, -0.84, 2.62), "gunmetal", grain=2)
        mb.boxr((x - 0.11, 0.98, 0.0), (x + 0.11, 1.2, 4.75), "gunmetal", grain=2)
        mb.boxr((x - 0.08, -0.95, 0.38), (x + 0.08, 1.0, 0.5), "gunmetal", grain=1)
    for y in (-0.95, 1.09):
        mb.boxr((-2.75, y - 0.08, 0.41), (2.75, y + 0.08, 0.53), "gunmetal", grain=0)
    mb.boxr((-2.68, -0.93, 0.48), (2.68, 1.04, 0.58), "plywood", grain=0)
    mb.boxr((-2.97, 0.95, 2.82), (2.97, 1.08, 4.7), "pegboard", grain=0)
    # drawer unit
    mb.boxr((1.15, -1.1, 1.55), (2.67, 0.75, 2.62), "gunmetal", grain=0)
    for z in (1.65, 2.12):
        mb.boxr((1.22, -1.17, z), (2.53, -1.08, z + 0.4), "gunmetal", grain=0)
        mb.boxr((1.67, -1.2, z + 0.16), (2.08, -1.15, z + 0.24), "steel_bare", grain=0)
    # bench vice
    mb.boxr((-2.75, -1.12, 2.84), (-2.1, -0.55, 3.02), "gunmetal")
    mb.boxr((-2.7, -1.15, 2.98), (-2.15, -0.95, 3.48), "gunmetal")
    mb.boxr((-2.7, -0.78, 2.98), (-2.15, -0.6, 3.48), "gunmetal")
    mb.boxr((-2.67, -0.96, 3.36), (-2.18, -0.77, 3.45), "steel_bare")
    mb.tube([(-2.425, -0.98, 3.15), (-2.425, -1.18, 3.15)], 0.06, "steel_bare", segs=6)
    mb.tube([(-2.75, -1.16, 3.15), (-2.1, -1.16, 3.15)], 0.035, "steel_bare", segs=5)
    # toolbox
    mb.boxr((-0.2, -0.45, 2.84), (1.1, 0.25, 3.36), "steel_grey", grain=0)
    mb.boxr((-0.23, -0.48, 3.32), (1.13, 0.28, 3.48), "steel_grey", grain=0)
    mb.tube([(0.2, -0.1, 3.46), (0.25, -0.1, 3.6), (0.65, -0.1, 3.6), (0.7, -0.1, 3.46)], 0.04, "gunmetal")
    # tools hanging on the pegboard
    wrench = [(-0.06, 0.0), (0.06, 0.0), (0.06, 1.05), (0.17, 1.12), (0.15, 1.32), (0.075, 1.22), (-0.075, 1.22), (-0.15, 1.32), (-0.17, 1.12), (-0.06, 1.05)]
    for (x0, z0, sc) in ((-2.2, 3.05, 1.0), (-1.8, 3.15, 0.85), (-1.45, 3.25, 0.7)):
        mb.prism([(x0 + x * sc, z0 + z * sc) for x, z in wrench], "Y", 0.84, 0.98, "steel_bare", grain=2)
    mb.boxr((-0.75, 0.87, 3.2), (-0.62, 0.98, 4.25), "wood_raw", grain=2)
    mb.boxr((-0.95, 0.84, 4.12), (-0.42, 0.98, 4.35), "steel_bare", grain=0)
    mb.boxr((0.2, 0.86, 3.55), (1.6, 0.98, 4.4), "steel_grey", grain=0)  # a hanging tool cabinet: two doors, two handles
    for hx in (0.82, 0.98):
        mb.boxr((hx - 0.03, 0.8, 3.85), (hx + 0.03, 0.89, 4.1), "steel_bare", grain=2)
    mb.boxr((0.88, 0.83, 3.58), (0.92, 0.89, 4.37), "gunmetal", grain=2)
    # clamp lamp
    mb.boxr((2.35, 0.5, 2.84), (2.7, 0.97, 3.04), "gunmetal")
    mb.tube([(2.52, 0.7, 3.0), (2.3, 0.35, 3.95), (1.85, -0.1, 4.3)], 0.05, "gunmetal", segs=6)
    M = Matrix.Translation((1.85, -0.1, 4.3)) @ Matrix.Rotation(math.radians(140), 4, "X")
    mb.lathe([(0.0, 0.0), (0.12, 0.0), (0.2, 0.15), (0.38, 0.5), (0.34, 0.5), (0.17, 0.18), (0.0, 0.18)], 12, "enamel_out", M=M,
             kindfn=lambda f: "enamel_out")
    mb.decal("st_tacsupply", (0, -1, 0), (0.9, -0.48, 3.12), 1.25, 0.2, col=(236, 232, 218), kinds=["steel_grey"], depth=0.1)
    return finish(mb)

def hang_lamp():
    """high-bay lamp (kit brief): spun aluminium bell 2.6 dia under a finned driver box, frosted lens disc (the light
    source: SpotLight down from it), separate drop rod (scale it on its length)"""
    out = []
    mb = MB("W2_HighBayLamp_Bell", "ClutterB", 1.8)
    loop = [(0.42, 1.12), (0.6, 1.02), (0.95, 0.75), (1.18, 0.4), (1.27, 0.12), (1.3, 0.0), (1.24, 0.0), (1.2, 0.12),
            (1.11, 0.38), (0.9, 0.7), (0.57, 0.95), (0.38, 1.04)]
    def kind(f):
        c = f.calc_center_median()
        r = math.hypot(c.x, c.y)
        nr = (f.normal.x * c.x + f.normal.y * c.y) / max(r, 1e-4)
        return "alu" if f.normal.z > 0.05 or nr > 0.3 else "enamel_in"
    mb.revolve(loop, 28, "alu", kindfn=kind)
    mb.lathe([(0.0, 1.0), (0.45, 1.0), (0.45, 1.2), (0.0, 1.2)], 16, "alu")
    mb.boxr((-0.48, -0.48, 1.18), (0.48, 0.48, 1.72), "gunmetal", grain=0)
    for x in (-0.24, 0.24):
        mb.boxr((x - 0.04, -0.56, 1.24), (x + 0.04, 0.56, 1.66), "gunmetal", grain=1)
    mb.lathe([(0.0, 1.7), (0.12, 1.7), (0.12, 1.8), (0.0, 1.8)], 8, "gunmetal")
    out.append(finish(mb))
    mb = MB("W2_HighBayLamp_Lens", "ClutterB", 0.3)
    mb.lathe([(0.0, 0.14), (1.17, 0.14), (1.17, 0.2), (0.0, 0.2)], 28, "bulb")
    out.append(finish(mb))
    mb = MB("W2_HighBayLamp_Rod", "ClutterB", 4.0)
    mb.lathe([(0.0, 1.74), (0.06, 1.74), (0.06, 5.75), (0.0, 5.75)], 8, "gunmetal")
    out.append(finish(mb))
    return out

# --- forklift (non-colliding art; every moving part its own object) ------------------------------------------------
def forklift():
    """counterbalance forklift at real proportions: a 2.5 t LPG truck (about 1.15 m wide, 2.5 m to the fork face,
    1.6 m wheelbase, 2.1 m overhead guard, 1.07 m forks, 0.65 / 0.55 m tyres) at 1 stud = 0.35 m.
    Front = -Y. Body, mast, forks, steering wheel and each wheel are separate objects (animatable)."""
    obs = []
    FY, FR, RR = -2.25, 0.93, 0.79
    mb = MB("W2_Forklift_Body", "Forklift", 6.05)
    chassis = [(-2.95, 0.45), (3.2, 0.45), (3.2, 2.95), (0.45, 2.95), (0.25, 2.75), (0.1, 1.55), (-1.85, 1.55),
               (-2.1, 2.75), (-2.95, 2.75)]
    mb.prism(chassis, "X", -1.05, 1.05, "fork_paint", grain=1)
    cw = [(2.0, 1.78), (3.32, 1.78), (3.32, 0.45), (3.5, 0.45), (3.62, 0.8), (3.62, 3.0), (3.35, 3.3), (2.0, 3.3)]
    mb.prism(cw, "X", -1.55, 1.55, "fork_paint", grain=0)
    for sx in (-1, 1):
        x0, x1 = sorted((sx * 1.0, sx * 1.72))
        mb.boxr((x0, FY - 0.85, 2.06), (x1, FY + 0.85, 2.2), "fork_paint", grain=1)
    mb.boxr((-1.38, -1.2, 0.95), (-1.0, -0.5, 1.06), "steel_bare", grain=1)
    mb.boxr((-0.62, 0.55, 2.93), (0.62, 1.5, 3.18), "vinyl", grain=0)
    mb.boxr((-0.59, 1.4, 3.1), (0.59, 1.62, 4.15), "vinyl", grain=2)
    mb.tube([(0.0, -2.0, 2.6), (0.0, -1.55, 3.4)], 0.08, "gunmetal", segs=8)
    for sx in (-1, 1):
        mb.boxr((sx * 1.02 - 0.06, -2.48, 2.7), (sx * 1.02 + 0.06, -2.32, 6.0), "gunmetal", grain=2)
        mb.boxr((sx * 1.02 - 0.06, 2.03, 3.25), (sx * 1.02 + 0.06, 2.19, 6.0), "gunmetal", grain=2)
        mb.boxr((sx * 1.02 - 0.09, -2.55, 5.88), (sx * 1.02 + 0.09, 2.22, 6.05), "gunmetal", grain=1)
        mb.boxr((sx * 1.02 - 0.15, -2.64, 5.3), (sx * 1.02 + 0.15, -2.47, 5.55), "gunmetal")
        mb.boxr((sx * 1.02 - 0.12, -2.68, 5.33), (sx * 1.02 + 0.12, -2.6, 5.52), "lens")
    for y in (-2.2, -1.1, 0.0, 1.1, 2.0):
        mb.boxr((-1.08, y - 0.07, 5.92), (1.08, y + 0.07, 6.01), "gunmetal", grain=0)
    mb.decal("hz_stripes", (0, 1, 0), (0, 3.62, 1.9), 2.9, 0.7, rough=0.5, kinds=["fork_paint"], depth=0.2)
    # stencils clipped to the one flat side panel behind the cab opening (y 0.45-2.0), so no letters fall into the cab
    mb.decal("st_motorpool", (1, 0, 0), (1.05, 1.22, 2.05), 1.45, 0.36, col=(236, 232, 218), kinds=["fork_paint"], depth=0.1)
    mb.decal("st_motorpool", (-1, 0, 0), (-1.05, 1.22, 2.05), 1.45, 0.36, col=(236, 232, 218), kinds=["fork_paint"], depth=0.1)
    obs.append(finish(mb))

    mb = MB("W2_Forklift_Mast", "Forklift", 5.75)
    for sx in (-1, 1):
        mb.boxr((sx * 0.75 - 0.12, -3.4, 0.35), (sx * 0.75 + 0.12, -2.92, 5.75), "gunmetal", grain=2)
    for z in (1.0, 3.4, 5.55):
        mb.boxr((-0.84, -3.35, z - 0.1), (0.84, -2.89, z + 0.1), "gunmetal", grain=0)
    mb.lathe([(0.0, 0.5), (0.11, 0.5), (0.11, 4.0), (0.07, 4.0), (0.07, 5.1), (0.0, 5.1)], 10, "steel_bare", M=Matrix.Translation((0, -3.04, 0)))
    mb.decal("hz_stripes", (0, -1, 0), (0, -3.35, 1.0), 1.2, 0.2, rough=0.5, kinds=["gunmetal"], depth=0.1)
    mb.decal("st_capacity", (0, -1, 0), (0, -3.35, 5.55), 1.15, 0.19, col=(236, 232, 218), kinds=["gunmetal"], depth=0.1)
    obs.append(finish(mb))

    mb = MB("W2_Forklift_Forks", "Forklift", 3.0)
    for z0 in (0.5, 1.6):
        mb.boxr((-1.15, -3.6, z0), (1.15, -3.38, z0 + 0.3), "gunmetal", grain=0)
    mb.boxr((-1.1, -3.57, 0.75), (1.1, -3.32, 1.65), "gunmetal", grain=0)   # carriage back plate: no slit between forks and mast
    for x in (-1.0, -0.5, 0.0, 0.5, 1.0):
        mb.boxr((x - 0.05, -3.53, 0.75), (x + 0.05, -3.43, 2.9), "gunmetal", grain=2)
    mb.boxr((-1.15, -3.57, 2.85), (1.15, -3.43, 3.0), "gunmetal", grain=0)
    for sx in (-1, 1):
        x0, x1 = sx * 0.6 - 0.15, sx * 0.6 + 0.15
        mb.boxr((x0, -3.78, 0.15), (x1, -3.54, 1.95), "steel_bare", grain=2)
        mb.prism([(-3.63, 0.12), (-6.45, 0.12), (-6.65, 0.17), (-6.65, 0.21), (-3.63, 0.3)], "X", x0 + 0.03, x1 - 0.03, "steel_bare", grain=1)
    obs.append(finish(mb))

    mb = MB("W2_Forklift_Steer", "Forklift", 3.6)
    M = Matrix.Translation((0, -1.5, 3.45)) @ Matrix.Rotation(math.radians(-35), 4, "X")
    mb.revolve([(0.3, -0.05), (0.37, -0.06), (0.42, 0.0), (0.37, 0.06), (0.3, 0.05)], 20, "vinyl", M=M)
    mb.lathe([(0.0, -0.09), (0.13, -0.09), (0.13, 0.07), (0.0, 0.07)], 10, "gunmetal", M=M)
    for a in (0, 2.1, 4.2):
        p0 = M @ Vector((0, 0, 0)); p1 = M @ Vector((0.34 * math.cos(a), 0.34 * math.sin(a), 0))
        mb.tube([p0, p1], 0.05, "gunmetal", segs=5)
    mb.tube([(0.0, -1.58, 3.35), (0.0, -1.47, 3.5)], 0.08, "gunmetal", segs=8)
    obs.append(finish(mb))

    for nm, ro, ri, hw in (("W2_Forklift_WheelF", FR, 0.52, 0.31), ("W2_Forklift_WheelR", RR, 0.42, 0.26)):
        mb = MB(nm, "Forklift", ro * 2)
        sc = ro / 1.2
        loop = [(r * sc, z * hw / 0.43) for r, z in TYRE]
        M = Matrix.Translation((0, 0, ro)) @ Matrix.Rotation(math.pi / 2, 4, "Y")
        mb.revolve(loop, 18, "rubber", M=M, r_ref=ro, groovefn=lambda f, ro=ro: 1.0 if math.hypot(f.calc_center_median().y, f.calc_center_median().z - ro) > ro * 0.96 else 0.0)
        mb.lathe([(0.0, -hw * 0.75), (ri * 1.05, -hw * 0.75), (ri * 1.05, hw * 0.75), (0.17, hw * 0.75), (0.17, hw * 0.95), (0.0, hw * 0.95)], 16, "fork_paint", M=M)
        mb.lathe([(0.0, -hw * 0.75 - 0.3), (0.15, -hw * 0.75 - 0.3), (0.15, -hw * 0.6), (0.0, -hw * 0.6)], 8, "gunmetal", M=M)
        obs.append(finish(mb))
    return obs

def human():
    """5-stud R15-proportioned stand-in for scale (not exported)."""
    mb = MB("R15_Human_5stud", "None", 5.0)
    mb.boxr((-0.5, -0.25, 0.0), (-0.05, 0.25, 2.0), "gunmetal"); mb.boxr((0.05, -0.25, 0.0), (0.5, 0.25, 2.0), "gunmetal")
    mb.boxr((-0.75, -0.3, 2.0), (0.75, 0.3, 3.8), "steel_grey")
    mb.boxr((-1.2, -0.25, 2.1), (-0.78, 0.25, 3.8), "steel_grey"); mb.boxr((0.78, -0.25, 2.1), (1.2, 0.25, 3.8), "steel_grey")
    mb.boxr((-0.4, -0.38, 3.82), (0.4, 0.38, 5.0), "enamel_in")
    return mb


# ----------------------------------------------------------------------------------------------------------- bake
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


def bake_atlas(atl, objs):
    log("bake", atl, [o.name for o in objs])
    unwrap(objs)
    imgs = {}
    for p in ("color", "rough", "metal", "normal", "ao"):
        im = bpy.data.images.new(f"W2_{atl}_{p}", RES, RES, alpha=False)
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
        path = os.path.join(TEX, f"W2_{atl}_{p}.png")
        im.filepath_raw = path; im.file_format = "PNG"; im.save()
        im.filepath = path
        out[p] = im
    bpy.data.images.remove(imgs["ao"])
    return out


def atlas_material(atl, imgs):
    mat = bpy.data.materials.new(f"W2_{atl}")
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


# ----------------------------------------------------------------------------------------------------------- assemblies
# name: [(master, (dx, dy, dz), rot_z_deg)], replaces, collision (Studio axes X, Y up, Z), notes
# name: [(master, (dx, dy, dz), rot_z_deg)], replaces, collision. The FIRST part's origin is the assembly pivot
# (bottom centre of the gameplay piece: barrel axis, crate centre, door opening centre on the wall's inside face).
ART = "art CanCollide/CanQuery/CanTouch off"
ASM = [
    ("W2_FireBarrel", [("W2_FireBarrel", (0, 0, 0), 0), ("W2_FireBarrel_Puddle", (0.0, 0.0, 0.0), 0)],
     "Shootables/FireBarrel_F1-F4 .Look (2.1 x 3.4 x 2.1)",
     "keep the existing Body cylinder Part (2.1 dia x 3.0, the shootable hit part, centred on the pivot); " + ART),
    ("W2_FireBarrel_Burnt", [("W2_FireBarrel_Burnt", (0, 0, 0), 0), ("W2_FireBarrel_BurntLid", (2.6, -1.1, 0.0), 25)],
     "the FireBarrel after it explodes (swap the Look; same pivot)", "none, or the Body cylinder 2.1 x 3.0 if it should stay low cover; " + ART),
    ("W2_OilDrum_Grey", [("W2_OilDrum_Grey", (0, 0, 0), 0)], "new clutter, not shootable (kit brief OilDrum 2.1 x 3.0 x 2.1)", "none (kit brief: clutter, no collision); " + ART),
    ("W2_OilDrum_Black", [("W2_OilDrum_Black", (0, 0, 0), 0)], "new clutter, not shootable (kit brief OilDrum)", "none; " + ART),
    ("W2_Cover_Low", [("W2_RifleCrate", (0, 0, 0), 0), ("W2_RifleCrate", (0, 0, 1.67), 180, (0.98833, 0.965, 1.0))],
     "Visuals/Arena_L01-L14 (6 x 3.4 x 2), cover proxy COLP_Lxx", "existing COLP_Lxx box 6 x 3.4 x 2 (unchanged); " + ART),
    ("W2_Cover_Tall", [("W2_TallCrate", (0, 0, 0), 0)],
     "Visuals/Arena_C01-C10 (5 x 7 x 4), cover proxy COLP_Cxx", "existing COLP_Cxx box 5 x 7 x 4 (unchanged); " + ART),
    ("W2_Cover_TallPly", [("W2_TallCrate_Ply", (0, 0, 0), 0)],
     "Visuals/Arena_C01-C10, second variant (kit brief TallCrate: plywood on skids)", "existing COLP_Cxx box 5 x 7 x 4 (unchanged); " + ART),
    ("W2_Cover_Wall", [("W2_LongCrate", (0, 0, 3.47), 0, (0.993, 0.97667, 1.0)), ("W2_SupplyCrate", (-2.5, 0, 0), 0), ("W2_SteelCrate", (2.5, 0, 0), 0),
                       ("W2_WallJoint", (0, 0, 0), 0)],
     "Visuals/Arena_W01-W04 (10 x 7 x 3), cover proxy COLP_Wxx (the stacked set: two crates under one long crate); pivot = the wall's bottom centre",
     "existing COLP_Wxx box 10 x 7 x 3 (unchanged); " + ART),
    ("W2_SupplyCrate", [("W2_SupplyCrate", (0, 0, 0), 0)], "loose crate for dressing (half a wall stack)", "box 5 x 3.5 x 3 if in the play area; " + ART),
    ("W2_SteelCrate", [("W2_SteelCrate", (0, 0, 0), 0)], "loose crate for dressing (half a wall stack)", "box 5 x 3.5 x 3 if in the play area; " + ART),
    ("W2_LongCrate", [("W2_LongCrate", (0, 0, 0), 0)], "loose long crate for dressing (top of a wall stack)", "box 10 x 3.5 x 3 if in the play area; " + ART),
    ("W2_AmmoCan", [("W2_AmmoCan", (0, 0, 0), 0)], "Visuals/Arena_PropCrate01-04 (2.4 x 1.2 x 1.8)", "none (clutter); " + ART),
    ("W2_RollDoor_Open", [("W2_RollDoor_Frame", (0, 0, 0), 0), ("W2_RollDoor_BottomBar", (0, 0, 13.6), 0), ("W2_RollDoor_Control", (-12.2, 0, 4.25), 0)],
     "the end openings of Warehouse 2 (20 x 14, kit brief RollUpDoor; old Warehouse Shutter was 16 x 9); pivot = opening centre on the floor, on the wall's inside face",
     "none (end walls, headers and OutOfBounds collide); " + ART),
    ("W2_RollDoor_HalfOpen", [("W2_RollDoor_Frame", (0, 0, 0), 0), ("W2_RollDoor_Curtain_Half", (0, 0, 7.0), 0), ("W2_RollDoor_Control", (-12.2, 0, 4.25), 0)],
     "same as Open, curtain down to 7.0 (half of 14)", "optional box 20.6 x 7.6 x 0.5 at the curtain if it must block; else none; " + ART),
    ("W2_Pallet", [("W2_Pallet", (0, 0, 0), 0)], "Props/Pallet (4 x 0.6 x 3.4)", "none (clutter); " + ART),
    ("W2_PalletSacks", [("W2_Pallet", (0, 0, 0), 0), ("W2_PalletSacks_Load", (0, 0, 0), 0)], "Props/Pallet + Cardboard piles", "box 4.1 x 2.1 x 3.5 if in the play area; " + ART),
    ("W2_Tyre", [("W2_Tyre", (0, 0, 0), 0)], "new clutter (no old piece)", "none (lean it on a wall, rotate 90 deg); " + ART),
    ("W2_TyreStack", [("W2_Tyre", (0, 0, 0), 0), ("W2_Tyre", (0.07, -0.05, 0.83), 40), ("W2_Tyre", (-0.05, 0.06, 1.66), 75)],
     "new clutter (no old piece)", "cylinder 2.5 dia x 2.5 if in the play area; " + ART),
    ("W2_ShelfRack", [("W2_ShelfRack", (0, 0, 0), 0), ("W2_ShelfRack_Load", (0, 0, 0), 0)],
     "new wall storage for the yards or the hall walls (old Arena_Cabinet was only 0.65 x 3 x 2: keep the rack out of the play area or the hall metrics drift)",
     "box 8 x 8 x 2.5; " + ART),
    ("W2_Workbench", [("W2_Workbench", (0, 0, 0), 0)], "Props/Workbench (6 x 4.75 x 2.4)", "box 6 x 2.86 x 2.4 (bench top) if in the play area; " + ART),
    ("W2_HighBayLamp", [("W2_HighBayLamp_Bell", (0, 0, 0), 0), ("W2_HighBayLamp_Lens", (0, 0, 0), 0), ("W2_HighBayLamp_Rod", (0, 0, 0), 0)],
     "kit brief HighBayLamp (2.6 x 1.8 x 2.6 bell + rod); old Visuals/Arena_Detail_Light strips",
     "none; SpotLight down from the lens (0.17 above the rim); scale the rod on its length; " + ART),
    ("W2_Forklift", [("W2_Forklift_Body", (0, 0, 0), 0), ("W2_Forklift_Mast", (0, 0, 0), 0), ("W2_Forklift_Forks", (0, 0, 0), 0),
                     ("W2_Forklift_Steer", (0, 0, 0), 0), ("W2_Forklift_WheelF", (-1.35, -2.25, 0), 180), ("W2_Forklift_WheelF", (1.35, -2.25, 0), 0),
                     ("W2_Forklift_WheelR", (-1.3, 2.32, 0), 180), ("W2_Forklift_WheelR", (1.3, 2.32, 0), 0)],
     "new yard dressing (kit brief Forklift)", "none (behind the map's own collider, as briefed); " + ART),
]


PIVOT = {}

def layout_assemblies(by_name):
    asm_coll = coll("Kit")
    placed = {}
    x = 0.0
    manifest = []
    used = set()
    for name, parts, replaces, collision in ASM:
        objs = []
        for part in parts:
            mname, (dx, dy, dz), rz = part[:3]
            scl = part[3] if len(part) > 3 else (1.0, 1.0, 1.0)
            m = by_name[mname]
            if mname not in used:
                o = m; used.add(mname)
                for c in o.users_collection:
                    c.objects.unlink(o)
            else:
                o = m.copy()
            o.name = f"{name}__{mname}" if (name != mname or len(parts) > 1) else name
            asm_coll.objects.link(o)
            o.rotation_euler = (0, 0, math.radians(rz))
            o.scale = scl
            o.location = (dx, dy, dz)
            objs.append(o)
        bpy.context.view_layer.update()
        lo, hi = bbox(objs)
        x += -lo.x + 0.0
        for o in objs:
            o.location.x += x
            o.location.y += 0
        bpy.context.view_layer.update()
        lo, hi = bbox(objs)
        x = hi.x + 6.0
        placed[name] = objs
        piv = objs[0].location.copy(); piv.z = 0.0   # the first part's bottom centre (it sits on the floor or its z is dropped)
        PIVOT[name] = piv
        manifest.append(dict(assembly=name, replaces=replaces, collision=collision, objects=[o.name for o in objs]))
    return placed, manifest


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


# ----------------------------------------------------------------------------------------------------------- main
def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(TEX, exist_ok=True); os.makedirs(FBXD, exist_ok=True)
    sc = bpy.context.scene
    sc.unit_settings.system = "METRIC"; sc.unit_settings.scale_length = 1.0
    builders = [
        fire_barrel, puddle, burnt_barrel, burnt_lid,
        lambda: oil_drum("W2_OilDrum_Grey", "grey_drum", [(1.4, 1.6, 0.1, 0.3, 0.3), (-0.4, 2.7, 0.06, 0.3, 0.2)],
                         [((("st_id044", FRONT, 1.55, 1.0, 1.4, 0.36), dict(col=(236, 232, 218)))),
                          ((("st_emblem", math.pi / 2, 1.5, 1.0, 0.75, 0.75), dict(col=(236, 232, 218))))]),
        lambda: oil_drum("W2_OilDrum_Black", "black_drum", [(-1.0, 2.1, 0.11, 0.35, 0.3), (2.0, 0.7, 0.07, 0.3, 0.2)],
                         [((("st_id103", FRONT, 1.55, 1.0, 1.4, 0.36), dict(col=(236, 232, 218))))]),
    ]
    obs = [b() for b in builders]
    # crates
    mb = wood_crate("W2_RifleCrate", 6.0, 2.0, 1.7, cleats_x=(-1.55, 1.55), rope_z=0.95, atlas="CratesCover", wood="wood_pine")
    mb.decal("st_rifle", (0, -1, 0), (0, -1.0, 0.85), 2.7, 0.68, col=(16, 16, 14), op=1.0)
    mb.decal("st_tacsupply", (0, 1, 0), (0, 1.0, 0.85), 2.6, 0.4, col=(16, 16, 14), op=1.0)
    mb.decal("st_handle", (0, 0, 1), (0, 0, 1.7), 3.0, 0.38, col=(22, 22, 20), depth=0.4)
    mb.decal("st_id017", (0, -1, 0), (-2.35, -1.0, 0.88), 0.62, 0.17, col=(22, 22, 20))
    obs.append(finish(mb))
    mb = wood_crate("W2_SupplyCrate", 5.0, 3.0, 3.5, diagonals=True, rope_z=2.4, wood="wood_grey")
    mb.decal("st_tacsupply", (0, -1, 0), (0, -1.5, 2.6), 3.6, 0.55, col=(236, 232, 218))
    mb.decal("st_weight", (0, -1, 0), (0.6, -1.5, 1.05), 2.2, 0.72, col=(22, 22, 20))
    mb.decal("st_rations", (0, 1, 0), (0, 1.5, 1.8), 3.6, 0.9, col=(236, 232, 218))
    mb.decal("st_upright", (1, 0, 0), (2.5, 0, 1.25), 1.3, 1.3, col=(236, 232, 218))
    mb.decal("st_upright", (-1, 0, 0), (-2.5, 0, 1.25), 1.3, 1.3, col=(236, 232, 218))
    mb.decal("st_id103", (0, 0, 1), (0, 0, 3.5), 2.0, 0.5, col=(236, 232, 218), depth=0.4)
    obs.append(finish(mb))
    mb = wood_crate("W2_TallCrate", 5.0, 4.0, 7.0, band_z=(3.5,), diagonals=True, rope_z=None, atlas="CratesCover", wood="wood_dark")
    mb.decal("st_engine", (0, -1, 0), (0, -2.0, 5.2), 3.8, 1.2, col=(236, 232, 218))
    mb.decal("st_emblem", (0, -1, 0), (0, -2.0, 1.75), 1.9, 1.9, col=(236, 232, 218))
    mb.decal("st_id017", (0, 1, 0), (0, 2.0, 5.2), 2.6, 0.65, col=(236, 232, 218))
    mb.decal("st_upright", (0, 1, 0), (0, 2.0, 1.75), 1.8, 1.8, col=(236, 232, 218))
    mb.decal("st_handle", (1, 0, 0), (2.5, 0, 3.5), 3.2, 0.36, col=(236, 232, 218))
    mb.decal("st_weight", (-1, 0, 0), (-2.5, 0, 5.2), 2.6, 0.85, col=(236, 232, 218))
    obs.append(finish(mb))
    mb = wood_crate("W2_TallCrate_Ply", 5.0, 4.0, 7.0, band_z=(3.7,), diagonals=False, cleats_x=(-0.8, 0.8), rope_z=None,
                    atlas="CratesPly", wood="wood_ply", skids=True)
    mb.decal("st_tacsupply", (0, -1, 0), (0, -2.0, 5.6), 3.8, 0.6, col=(22, 22, 20))
    mb.decal("st_upright", (0, -1, 0), (-1.6, -2.0, 2.2), 1.2, 1.2, col=(22, 22, 20))
    mb.decal("st_weight", (0, 1, 0), (0, 2.0, 5.4), 2.8, 0.9, col=(22, 22, 20))
    mb.decal("st_id103", (1, 0, 0), (2.5, 0, 5.6), 2.2, 0.55, col=(22, 22, 20))
    mb.decal("st_handle", (-1, 0, 0), (-2.5, 0, 2.3), 3.0, 0.36, col=(22, 22, 20))
    obs.append(finish(mb))
    mb = wood_crate("W2_LongCrate", 10.0, 3.0, 3.5, cleats_x=(-1.8, 1.8), rope_z=2.3, wood="wood_dark")
    mb.decal("st_tacsupply", (0, -1, 0), (0, -1.5, 2.35), 3.2, 0.5, col=(236, 232, 218))
    mb.decal("st_rifle", (0, -1, 0), (-3.4, -1.5, 1.6), 2.6, 0.65, col=(236, 232, 218))
    mb.decal("st_id044", (0, -1, 0), (3.4, -1.5, 1.6), 2.0, 0.5, col=(236, 232, 218))
    mb.decal("st_handle", (0, 1, 0), (0, 1.5, 1.75), 3.2, 0.4, col=(236, 232, 218))
    mb.decal("st_upright", (1, 0, 0), (5.0, 0, 1.2), 1.2, 1.2, col=(236, 232, 218))
    mb.decal("st_emblem", (0, 0, 1), (2.5, 0, 3.5), 1.6, 1.6, col=(236, 232, 218), depth=0.4)
    obs.append(finish(mb))
    mb = steel_crate("W2_SteelCrate", 5.0, 3.0, 3.5)
    mb.decal("st_ammo762", (0, -1, 0), (0, -1.4, 1.6), 3.3, 0.95, col=(236, 232, 218))
    mb.decal("st_id044", (0, 1, 0), (0, 1.4, 1.6), 2.4, 0.6, col=(236, 232, 218))
    mb.decal("st_emblem", (1, 0, 0), (2.4, 0, 1.6), 1.0, 1.0, col=(236, 232, 218))
    mb.decal("st_tacsupply", (0, 0, 1), (0, 0, 3.5), 3.6, 0.45, col=(236, 232, 218), depth=0.3)
    obs.append(finish(mb))
    obs.append(ammo_can())
    obs.append(wall_filler())
    obs += [door_frame(), door_bottom_bar(), door_curtain_half(), door_control()]
    obs += [pallet(), pallet_sacks(), tyre(), shelf_rack(), rack_load(), workbench()]
    obs += hang_lamp()
    obs += forklift()
    by_name = {o.name: o for o in obs}
    # spread masters for baking (AO must not see the neighbours)
    x = 0.0
    for o in obs:
        lo, hi = bbox([o])
        o.location.x += x - lo.x
        o.location.y = 60.0
        bpy.context.view_layer.update()
        x = bbox([o])[1].x + 8.0
    log("built", len(obs), "masters", sum(tris(o) for o in obs), "tris")
    atlases = {}
    for o in obs:
        atlases.setdefault(o["atlas"], []).append(o)
    atl_files = {}
    if not NOBAKE:
        setup_cycles()
        for atl, objs in atlases.items():
            imgs = bake_atlas(atl, objs)
            finalize(objs, atlas_material(atl, imgs))
            atl_files[atl] = {p: f"tex/W2_{atl}_{p}.png" for p in imgs}
            bpy.ops.wm.save_as_mainfile(filepath=BLEND); bpy.ops.file.make_paths_relative(); bpy.ops.wm.save_mainfile()
    placed, manifest = layout_assemblies(by_name)
    cube, mk = scale_cube_marker()
    for c in list(bpy.data.collections):
        if c.name == "Masters" and not c.objects:
            bpy.data.collections.remove(c)
    bpy.context.view_layer.update()
    # manifest + FBX
    allobjs = [o for objs in placed.values() for o in objs]
    for e in manifest:
        objs = placed[e["assembly"]]
        lo, hi = bbox(objs)
        piv = PIVOT[e["assembly"]]
        e["pivot_blender_in_kit"] = [round(v, 3) for v in piv]
        e["pivot"] = "bottom centre of " + objs[0].name.split("__")[-1] + " (the per-assembly FBX has this point at the origin)"
        e["bbox_centre_blender"] = [round(v, 3) for v in (lo + hi) / 2]
        a_, b_ = studio(lo - piv), studio(hi - piv)
        e["bbox_min_rel_pivot_studio"] = [min(p, q) for p, q in zip(a_, b_)]
        e["bbox_max_rel_pivot_studio"] = [max(p, q) for p, q in zip(a_, b_)]
        e["size_blender"] = [round(v, 3) for v in hi - lo]
        e["size_studio"] = studio_size(hi - lo)
        e["bottom_centre_studio_offset"] = "art bottom = floor top; size_studio is X, Y(up), Z"
        e["parts"] = []
        for o in objs:
            l2, h2 = bbox([o])
            e["parts"].append(dict(object=o.name, mesh=o.data.name, atlas=o.get("atlas"), tris=tris(o),
                                   centre_studio_rel_pivot=studio((l2 + h2) / 2 - piv),
                                   size_studio=studio_size(h2 - l2), rot_z_deg=round(math.degrees(o.rotation_euler.z), 1)))
        e["tris"] = sum(p["tris"] for p in e["parts"])
        e["textures"] = sorted({f for o in objs for f in atl_files.get(o.get("atlas"), {}).values()})
        e["fbx"] = f"fbx/{e['assembly']}.fbx"
    if not NOBAKE:
        export_fbx(os.path.join(FBXD, "W2_Props_kit.fbx"), allobjs + [cube, mk])
        for e in manifest:
            objs = placed[e["assembly"]]
            off = PIVOT[e["assembly"]].copy()
            for o in objs:
                o.location -= off
            bpy.context.view_layer.update()
            export_fbx(os.path.join(FBXD, e["assembly"] + ".fbx"), objs)
            for o in objs:
                o.location += off
        bpy.context.view_layer.update()
    man = dict(note="Blender (x, y, z) -> Studio (-x, z, y). 1 unit = 1 stud. Kit FBX has K_ScaleCube (10 studs, Blender (0,30,5)) and "
                    "K_Marker (long arm +X, upright +Z, short arm +Y); measure the cube after Import 3D and divide sizes by it.",
               atlases=atl_files, assemblies=manifest, total_tris=sum(tris(o) for o in by_name.values()))
    json.dump(man, open(os.path.join(ROOT, "warehouse2_props.json"), "w"), indent=1)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    bpy.ops.file.make_paths_relative(); bpy.ops.wm.save_mainfile()   # relative image paths: the .blend opens on either PC
    log("DONE", len(allobjs), "objects in kit;", man["total_tris"], "unique tris")


main()

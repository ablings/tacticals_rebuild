"""Checks the kit's blender_check does not do, per assembly (all objects AND all loose parts of each mesh together,
in world space). Runs inside Blender on the kit:
  blender -b art/warehouse2/warehouse2_props.blend --python art/warehouse2/tools/assembly_check.py [-- --only W2_Cover_Wall]

LAYER  A8: two parts' faces facing the same way, less than 0.03 apart (coplanar included), overlapping. The overlap is
       sampled on a grid; only overlap that is VISIBLE (the front face not inside a third part) counts.
GAPIN  GAP: two parts' faces looking at each other 0.001-0.15 apart, overlapping, where the parts don't intersect
       (a slit). Visible area only.
CAPS   A1 the volume test misses: one plane of one loose part holding faces of both orientations (flipped cap triangles).
SEE    rays through every cover assembly, front-back and end-end, on an offset 0.01 grid from 0.11 inside its box:
       any ray that crosses without a hit is a slit you can see through.
Prints per-assembly visible areas (sq studs) and ray counts; exit summary line "ASSEMBLY CHECK".
"""
import bpy, bmesh, sys
from collections import defaultdict
from mathutils import Vector, geometry
from mathutils.bvhtree import BVHTree

DIRS = [Vector(d).normalized() for d in ((0.31, 0.57, 0.76), (-0.71, 0.23, 0.53), (0.43, -0.83, -0.29))]
ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ONLY = ARGV[ARGV.index("--only") + 1] if "--only" in ARGV else None


def shells(bm):
    comp, seen, out = {}, set(), 0
    for f in bm.faces:
        if f in seen:
            continue
        stack = [f]; seen.add(f)
        while stack:
            g = stack.pop(); comp[g] = out
            for e in g.edges:
                for h in e.link_faces:
                    if h not in seen:
                        seen.add(h); stack.append(h)
        out += 1
    return comp, out


def in_poly(p, f):
    vs = [v.co for v in f.verts]
    return any(geometry.intersect_point_tri(p, vs[0], vs[i], vs[i + 1]) for i in range(1, len(vs) - 1))


def grid(f, n=7):
    vs = [v.co for v in f.verts]
    pts = []
    for i in range(1, len(vs) - 1):
        a, b, c = vs[0], vs[i], vs[i + 1]
        for u in range(n + 1):
            for v in range(n + 1 - u):
                w = n - u - v
                pts.append((a * (u + 0.33) + b * (v + 0.33) + c * (w + 0.34)) / (n + 1.0))   # weights sum to 1
    return pts


def merged(objs):
    bm = bmesh.new()
    for o in objs:
        t = bmesh.new(); t.from_mesh(o.data); t.transform(o.matrix_world)
        me = bpy.data.meshes.new("_t"); t.to_mesh(me); t.free()
        bm.from_mesh(me); bpy.data.meshes.remove(me)
    bm.normal_update()
    return bm


class Parts:
    def __init__(s, bm):
        s.comp, n = shells(bm)
        s.faces = defaultdict(list)
        for f in bm.faces:
            s.faces[s.comp[f]].append(f)
        s.tree, s.box = {}, {}
        for k, fs in s.faces.items():
            vs = list({v for f in fs for v in f.verts}); ix = {v: i for i, v in enumerate(vs)}
            s.tree[k] = BVHTree.FromPolygons([v.co.copy() for v in vs], [[ix[v] for v in f.verts] for f in fs])
            s.box[k] = (Vector((min(v.co.x for v in vs), min(v.co.y for v in vs), min(v.co.z for v in vs))),
                        Vector((max(v.co.x for v in vs), max(v.co.y for v in vs), max(v.co.z for v in vs))))

    def inside(s, p, k):
        lo, hi = s.box[k]
        if not all(lo[i] - 1e-4 <= p[i] <= hi[i] + 1e-4 for i in range(3)):
            return False
        votes = 0
        for d in DIRS:        # ray parity, 3 directions, majority (a ray through a shared edge counts twice)
            c, q = 0, p.copy()
            for _ in range(64):
                hit = s.tree[k].ray_cast(q, d)
                if hit[0] is None:
                    break
                c += 1; q = hit[0] + d * 1e-3
            votes += c % 2
        return votes >= 2

    def hidden(s, p, skip):
        return any(s.inside(p, k) for k in s.tree if k not in skip)

    def intersect(s, a, b):
        return bool(s.tree[a].overlap(s.tree[b]))


def face_box(f):
    vs = [v.co for v in f.verts]
    return (Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs))),
            Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs))))


def near(b1, b2, pad):
    return all(b1[0][i] - pad <= b2[1][i] and b2[0][i] - pad <= b1[1][i] for i in range(3))


def layers_and_gaps(bm, P):
    zmin = min(v.co.z for v in bm.verts)
    # faces lying on the floor plane and facing down are never seen
    faces = [f for f in bm.faces if f.calc_area() > 2e-4 and not (f.normal.z < -0.99 and f.calc_center_median().z < zmin + 0.005)]
    boxes = {f: face_box(f) for f in faces}
    buckets = defaultdict(list)
    for f in faces:
        n = f.normal
        a = max(range(3), key=lambda i: abs(n[i]))
        buckets[(a, round(abs(n[a]), 2) > 0.995)].append(f)
    layer, gap, worst_l, worst_g = 0.0, 0.0, [], []
    inter = {}
    for fs in buckets.values():
        for i, a in enumerate(fs):
            for b in fs[i + 1:]:
                ca, cb = P.comp[a], P.comp[b]
                if ca == cb or not near(boxes[a], boxes[b], 0.16):
                    continue
                dot = a.normal.dot(b.normal)
                if abs(dot) < 0.999:
                    continue
                da = a.normal.dot(a.verts[0].co)
                dist = abs(a.normal.dot(b.verts[0].co) - da)
                small, big = (a, b) if a.calc_area() <= b.calc_area() else (b, a)
                if dot > 0 and dist < 0.0295:
                    pts = grid(small)
                    vis = 0
                    for p in pts:
                        q = p - big.normal * (big.normal.dot(p) - big.normal.dot(big.verts[0].co))
                        if not in_poly(q, big):
                            continue
                        front = p if small.normal.dot(p) >= small.normal.dot(q) else q
                        if not P.hidden(front + small.normal * 0.004, (ca, cb)):
                            vis += 1
                    ar = small.calc_area() * vis / len(pts)
                    if ar > 0.001:
                        layer += ar; worst_l.append((round(ar, 3), round(dist, 3), tuple(round(c, 2) for c in small.calc_center_median())))
                elif dot < 0 and 0.001 < dist < 0.149:
                    # facing each other: is the gap between them real (in front of both, parts not intersecting)?
                    if small.normal.dot(big.verts[0].co) - small.normal.dot(small.verts[0].co) < 0:
                        continue  # big is behind small: they don't face each other
                    key = (min(ca, cb), max(ca, cb))
                    if key not in inter:
                        inter[key] = P.intersect(ca, cb)
                    if inter[key]:
                        continue
                    pts = grid(small)
                    vis = 0
                    for p in pts:
                        q = p - big.normal * (big.normal.dot(p) - big.normal.dot(big.verts[0].co))
                        if in_poly(q, big) and not P.hidden((p + q) / 2, (ca, cb)):
                            vis += 1
                    ar = small.calc_area() * vis / len(pts)
                    if ar > 0.001:
                        gap += ar; worst_g.append((round(ar, 3), round(dist, 3), tuple(round(c, 2) for c in small.calc_center_median())))
    return layer, gap, sorted(worst_l, reverse=True), sorted(worst_g, reverse=True)


def broken_caps(bm, P):
    """A1 that whole-volume tests miss: inside one loose part, one plane holding faces of BOTH orientations
    (a cap triangulated into overlapping, partly flipped triangles). Returns the flipped area."""
    bad, where = 0.0, []
    for k, fs in P.faces.items():
        planes = defaultdict(lambda: [0.0, 0.0, []])
        for f in fs:
            n = f.normal
            if n.length < 0.5:
                continue
            a = max(range(3), key=lambda i: abs(n[i]))
            sgn = 1 if n[a] > 0 else -1
            nn = n * sgn
            key = (round(nn.x, 3), round(nn.y, 3), round(nn.z, 3), round(nn.dot(f.verts[0].co), 3))
            planes[key][0 if sgn > 0 else 1] += f.calc_area()
            planes[key][2].append(f)
        for key, (pos, neg, fl) in planes.items():
            if pos > 1e-4 and neg > 1e-4:
                bad += min(pos, neg); where.append((round(min(pos, neg), 3), key))
    return bad, sorted(where, reverse=True)


def seethrough(bm, step=0.01, inset=0.11):   # inset past the brief's 0.1 allowance
    tree = BVHTree.FromBMesh(bm)
    vs = [v.co for v in bm.verts]
    lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    holes = []
    for axis, (ua, va) in ((1, (0, 2)), (0, (1, 2))):
        d = Vector((0, 0, 0)); d[axis] = 1.0
        u = lo[ua] + inset + step * 0.37
        while u < hi[ua] - inset:
            v = lo[va] + inset + step * 0.61
            while v < hi[va] - inset:
                p = Vector((0, 0, 0)); p[ua] = u; p[va] = v; p[axis] = lo[axis] - 1.0
                if tree.ray_cast(p, d, (hi[axis] - lo[axis]) + 2.0)[0] is None:
                    holes.append(("YX"[axis == 0], round(u, 3), round(v, 3)))
                v += step
            u += step
    return holes


kit = [o for o in bpy.data.collections["Kit"].objects if o.type == "MESH"]
groups = defaultdict(list)
for o in kit:
    groups[o.name.split("__")[0]].append(o)
TL = TG = TS = 0
for name in sorted(groups):
    if ONLY and name != ONLY:
        continue
    bm = merged(groups[name])
    P = Parts(bm)
    l, g, wl, wg = layers_and_gaps(bm, P)
    s = seethrough(bm) if name.startswith("W2_Cover_") else []
    bc, bw = broken_caps(bm, P)
    TC = globals().get("TC", 0.0) + bc; globals()["TC"] = TC
    if bc > 0:
        print(f"CAPS {name:22s} flipped area {bc:.3f}", bw[:3], flush=True)
    TL += l; TG += g; TS += len(s)
    piv = min(groups[name], key=lambda o: o.name).location if False else None
    import json as _j
    try:
        man = {e["assembly"]: e for e in _j.load(open(bpy.path.abspath("//warehouse2_props.json")))["assemblies"]}
        piv = Vector(man[name]["pivot_blender_in_kit"])
    except Exception:
        piv = Vector((0, 0, 0))
    rel = lambda lst: [(a_, d_, tuple(round(c - piv[i], 2) for i, c in enumerate(p_))) for a_, d_, p_ in lst]
    print(f"ASM {name:22s} LAYER {l:.3f}  GAPIN {g:.3f}  SEE {len(s)}", "| L", rel(wl[:4]), "| G", rel(wg[:4]), "| S", s[:3], flush=True)
    bm.free()
print(f"ASSEMBLY CHECK: LAYER {TL:.3f} sq studs, GAPIN {TG:.3f} sq studs, SEE {TS} rays, BROKEN CAPS {globals().get('TC', 0.0):.3f} sq studs")

"""House map exterior TREES (and a softer front hedge): realistic-leaning suburban trees that replace the faceted Tree_XX blobs
of H_Exterior.fbx at the same 15 trunk bases and heights.
  python art/house/tools/make_tree_atlas.py            (paints tex/H_Trees_color|normal|rough.png, 1024, one atlas for the set)
  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python art/house/tools/build_trees.py
Writes art/house/house_trees.blend, fbx/H_Trees.fbx (+ K_ScaleCube / K_Marker at the same spots as H_Exterior), house_trees.json.

Same plan coordinates as build_exterior.py (x east, y north, z up, outside ground z = -1). Each tree = 2 objects sharing one
material (H_Trees): Tree_NN (trunk + branches, bark cells of the atlas) and Tree_NN_Crown (leaf clumps + leaf fringe).
Construction (vault Asset Library, Anime Card-Leaf Broadleaf Tree / Lobed-Crown Tree recipes, made realistic):
  broadleaf = lofted trunk with root flare + 5-8 lofted limbs (+ a twig each); crown = ~30 jittered closed clumps (icosphere,
  80 tris) clustered on the limb tips and an ellipsoid shell, 4 dark inner clumps so the crown never shows sky through its
  core, and 2 small closed leaf solids per clump on the silhouette. Clumps pick a light / mid / dark leaf cell by height and
  sun side, so the crown has a lit top and a shaded underside in the texture itself (no alpha, nothing transparent).
  conifer = tiers of closed star-shaped skirts (drooping bough tips, notches between) + a closed needle spray at every tip.
  Custom normals: blend of the clump / face normal with the crown's radial direction (soft ball shading), each face's normals
  kept within 66 degrees of the face (A13). Every mesh is built from triangles, each oriented outward from its own solid."""
import bpy, bmesh, math, random, json, os, sys
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import hcore as hc
from make_tree_atlas import CELLS

ROOT = hc.ROOT
BLEND = os.path.join(ROOT, "house_trees.blend")
GZ = -1.0
SUN = Vector((-0.45, -0.55, 0.7)).normalized()      # leaf cells: the lit side of a crown
CONIFER = False
LOC = (0, 0, 0)        # the tree being built (keep_out needs world coordinates)
LEAF_CELL = 5.6        # studs covered by one 256 px leaf cell (46 px/stud)
NEEDLE_CELL = 6.5
HEDGE_CELL = (3.0, 6.0)
ZERO_UV = None         # caps buried in the ground / in a clump: zero-area UV (A18)

# the same 15 spots and heights as build_exterior.py main() (trunk base = (x, y), h = random.Random(i).uniform(14, 20))
SPOTS = [(-30, -46, "broad"), (36, -48, "broad"), (-34, 58, "broad"), (6, 66, "cone"), (-60, -98, "broad"), (24, -98, "cone"),
         (60, -96, "broad"), (-110, -50, "cone"), (112, -50, "broad"), (-70, 70, "broad"), (78, 72, "cone"), (-140, -96, "broad"),
         (140, -98, "cone"), (-20, 92, "cone"), (20, 92, "broad")]
BROAD_FORMS = ["round", "oval", "spread"]
CONE_FORMS = ["spruce", "fir"]


# neighbour houses (plan footprints from house_exterior.json, walls up to the roof) and our fences (x0, y0, x1, y1, top z)
HOUSES = [(-116, -26, -52, 14), (52, -26, 116, 14), (-33, -140, 33, -100), (-119, -141, -57, -103), (57, -141, 119, -103),
          (-70, 90, -10, 126), (10, 90, 70, 126)]
FENCES = [(-46, -40, -46, 75, GZ + 7), (46, -40, 46, 75, GZ + 7), (-160, 75, 160, 75, GZ + 7), (-46, -92, 46, -92, GZ + 4)]
CLEAR = 0.5


def limits(base, conifer):
    """one-sided limits (axis, sign, distance from the trunk) for the neighbour houses this trunk faces and, for conifers
    (whose skirts reach the ground), our fences. Houses that contain the trunk base itself are skipped (reported)."""
    out = []
    for (x0, y0, x1, y1) in HOUSES:
        if x0 <= base.x <= x1 and y0 <= base.y <= y1:
            continue
        for (ax, lo, hi, a0, a1) in ((1, y0, y1, x0, x1), (0, x0, x1, y0, y1)):
            other = base[1 - ax]
            if a0 - 12 <= other <= a1 + 12:
                if base[ax] < lo: out.append((ax, 1, lo - CLEAR - base[ax]))
                elif base[ax] > hi: out.append((ax, -1, base[ax] - hi - CLEAR))
    if conifer:
        for (x0, y0, x1, y1, top) in FENCES:
            ax = 0 if x0 == x1 else 1
            line = x0 if ax == 0 else y0
            span = (min(y0, y1), max(y0, y1)) if ax == 0 else (min(x0, x1), max(x0, x1))
            if span[0] - 4 <= base[1 - ax] <= span[1] + 4:
                sd = 1 if line > base[ax] else -1
                out.append((ax, sd, abs(line - base[ax]) - CLEAR))
    return [l for l in out if l[2] < 14]


def squeeze(p, base, lims):
    """smooth monotone squeeze of a world point toward the trunk along each limit's axis: offsets up to 55% of the limit stay,
    beyond that they approach the limit and never reach it. Monotone, so no face folds over another (A1c)."""
    for (ax, sd, D) in lims:
        D = max(D, 0.6)
        o = (p[ax] - base[ax]) * sd
        s0 = 0.55 * D
        if o > s0:
            o = s0 + (D - s0) * (1.0 - math.exp(-(o - s0) / (D - s0)))
            p[ax] = base[ax] + o * sd
    return p


class Mesh:
    """triangle accumulator: per-loop UVs and custom normals; every tri oriented away from a given inside point."""
    def __init__(self, name):
        self.name = name; self.v = []; self.t = []; self.uv = []; self.n = []

    def vert(self, p):
        self.v.append(Vector(p)); return len(self.v) - 1

    def tri(self, a, b, c, inside, uvs, nfun, min_dot=0.4):
        A, B, C = self.v[a], self.v[b], self.v[c]
        fn = (B - A).cross(C - A)
        if fn.length < 1e-9:
            return
        if fn.dot((A + B + C) / 3 - Vector(inside)) < 0:
            b, c = c, b; uvs = (uvs[0], uvs[2], uvs[1]); B, C = C, B; fn = -fn
        fn.normalize()
        self.t.append((a, b, c)); self.uv.extend(uvs)
        for i in (a, b, c):
            n = nfun(self.v[i], fn) if nfun else fn
            d = n.dot(fn)
            if d < min_dot:      # A13: never let a loop normal turn away from its face (white glints, black patches)
                n = (n + fn * (min_dot - d) * 2.0).normalized()
            self.n.append(n)

    def build(self, mat, loc):
        L = Vector(loc)
        lims = limits(L, CONIFER)
        if lims:
            hc.log("  ", self.name, "squeezed toward", [(("x", "y")[a], s_, round(d, 1)) for a, s_, d in lims])
        self.v = [squeeze(p + L, L, lims) - L for p in self.v]
        me = bpy.data.meshes.new(self.name)
        me.from_pydata([tuple(p) for p in self.v], [], self.t)
        uvl = me.uv_layers.new(name="UVMap")
        for i, l in enumerate(uvl.data):
            l.uv = self.uv[i]
        me.validate(clean_customdata=False)
        me.shade_smooth()
        me.normals_split_custom_set([tuple(n) for n in self.n])
        me.materials.append(mat)
        ob = bpy.data.objects.new(self.name, me)
        hc.coll("Trees").objects.link(ob)
        ob.location = loc
        return ob


def cell_uv(cell, a, b):
    """(a, b) in 0..1 inside a named atlas cell -> atlas UV (inset 2 px so mip bleeding stays inside the cell)."""
    u0, v0, u1, v1 = CELLS[cell]
    e = 2.0 / 1024
    a = min(max(a, 0.0), 1.0); b = min(max(b, 0.0), 1.0)
    return (u0 + e + (u1 - u0 - 2 * e) * a, v0 + e + (v1 - v0 - 2 * e) * b)


def corner_uv(cell):
    return cell_uv(cell, 0.5, 0.02)


# ----------------------------------------------------------------------------------------------------------- wood
def loft(M, pts, radii, sides, cell, cap0=True, cap1=True, vspan=10.0, twist=0.0):
    """tube along pts (parallel-transport frames), bark UV: u around (whole cell width, wraps), v along (vspan studs per cell)."""
    pts = [Vector(p) for p in pts]
    n = len(pts)
    tans = []
    for i in range(n):
        t = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized(); tans.append(t)
    ref = Vector((1, 0, 0)) if abs(tans[0].x) < 0.9 else Vector((0, 1, 0))
    nrm = (ref - tans[0] * ref.dot(tans[0])).normalized()
    rings, s, arc = [], [], 0.0
    for i in range(n):
        t = tans[i]
        nrm = (nrm - t * nrm.dot(t)).normalized(); bi = t.cross(nrm)
        if i:
            arc += (pts[i] - pts[i - 1]).length
        s.append(arc)
        ring = []
        for j in range(sides):
            a = 2 * math.pi * j / sides + twist * i
            ring.append(M.vert(pts[i] + (nrm * math.cos(a) + bi * math.sin(a)) * radii[i]))
        rings.append(ring)
    def radial(i):
        c = pts[i]
        return lambda p, fn: (p - c - tans[i] * (p - c).dot(tans[i])).normalized() if (p - c).length > 1e-6 else fn
    for i in range(n - 1):
        c = (pts[i] + pts[i + 1]) / 2
        va, vb = s[i] / vspan, s[i + 1] / vspan
        def nf(p, fn, i=i):
            ax = tans[i]; cc = pts[i]
            r = (p - cc) - ax * (p - cc).dot(ax)
            return r.normalized() if r.length > 1e-6 else fn
        for j in range(sides):
            j2 = (j + 1) % sides
            ua, ub = j / sides, (j + 1) / sides
            a, b, cq, d = rings[i][j], rings[i][j2], rings[i + 1][j2], rings[i + 1][j]
            M.tri(a, b, cq, c, (cell_uv(cell, ua, va), cell_uv(cell, ub, va), cell_uv(cell, ub, vb)), nf)
            M.tri(a, cq, d, c, (cell_uv(cell, ua, va), cell_uv(cell, ub, vb), cell_uv(cell, ua, vb)), nf)
    z = corner_uv(cell)
    for (cap, i, inward) in ((cap0, 0, 1), (cap1, n - 1, -1)):
        if not cap:
            continue
        cc = M.vert(pts[i])
        inside = pts[i] + tans[i] * inward * 0.3 * radii[i]
        for j in range(sides):
            M.tri(cc, rings[i][j], rings[i][(j + 1) % sides], inside, (z, z, z), None)


def bend_path(a, b, k, rng, bow=0.25):
    """k points from a to b with a gentle upward bow and a little wander (limbs are never straight dowels)."""
    a, b = Vector(a), Vector(b)
    side = (b - a).cross(Vector((0, 0, 1)))
    side = side.normalized() if side.length > 1e-6 else Vector((1, 0, 0))
    L = (b - a).length
    out = []
    for i in range(k):
        t = i / (k - 1)
        p = a.lerp(b, t) + Vector((0, 0, 1)) * math.sin(math.pi * t) * bow * L * 0.3
        if 0 < i < k - 1:
            p += side * rng.uniform(-0.08, 0.08) * L
        out.append(p)
    return out


# ----------------------------------------------------------------------------------------------------------- leaves
def clump(M, c, r, cell, crown_c, crown_r, rng, ico=None, fringe=2, fringe_len=(0.9, 1.3)):
    """one closed leaf clump: a jittered, squashed icosphere (80 tris) + `fringe` small closed leaf solids on its outer side."""
    c = Vector(c)
    base = ico
    idx = []
    for p in base["v"]:
        q = Vector(p) * rng.uniform(0.86, 1.14)
        idx.append(M.vert(c + Vector((q.x * r[0], q.y * r[1], q.z * r[2]))))
    def nf(p, fn):
        d = Vector(((p - c).x / r[0] ** 2, (p - c).y / r[1] ** 2, (p - c).z / r[2] ** 2)).normalized()
        g = p - crown_c
        g = Vector((g.x / crown_r[0], g.y / crown_r[1], g.z / crown_r[2])).normalized()
        return (d * 0.3 + g * 0.7).normalized()
    for (a, b, cc) in base["f"]:
        A, B, C = M.v[idx[a]], M.v[idx[b]], M.v[idx[cc]]
        fn = (B - A).cross(C - A)
        ax = max(range(3), key=lambda k: abs(fn[k]))
        o = [k for k in range(3) if k != ax]
        uvs = tuple(cell_uv(cell, (P[o[0]] - c[o[0]]) / LEAF_CELL + 0.5, (P[o[1]] - c[o[1]]) / LEAF_CELL + 0.5) for P in (A, B, C))
        M.tri(idx[a], idx[b], idx[cc], c, uvs, nf, min_dot=0.1)
    # silhouette fringe: small closed leaf solids half out of the clump, on its outward / upper side
    out = (c - crown_c); out.z *= 0.5
    out = out.normalized() if out.length > 1e-6 else Vector((0, 0, 1))
    for k in range(fringe):
        sd = (out + Vector((rng.uniform(-0.9, 0.9), rng.uniform(-0.9, 0.9), rng.uniform(-0.2, 0.9)))).normalized()
        p = c + Vector((sd.x * r[0], sd.y * r[1], sd.z * r[2])) * 0.9
        tg = sd.cross(Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1)))).normalized()
        d = (tg + sd * 0.45).normalized()          # mostly along the surface, tip lifted a little off it
        L = rng.uniform(*fringe_len)
        leaf_solid(M, p, d, L, L * 0.62, cell, crown_c, crown_r, rng, droop=0.08, flat_to=sd)


def leaf_solid(M, p, d, L, W, cell, crown_c, crown_r, rng, droop=0.0, flat_to=None):
    """a closed, flat bipyramid leaf (8 tris): rim of 4 (stem, tip, two sides) + a top and a bottom apex 0.07 off.
    flat_to: the blade's face turns toward this direction (a leaf lying on its clump), else a random roll."""
    tw = flat_to if flat_to is not None else Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1)))
    w = d.cross(tw).normalized()
    nn = w.cross(d).normalized()
    tip = p + d * L * 0.7 - nn * droop * L
    stem = p - d * L * 0.3
    mid = p + d * L * 0.12
    rim = [stem, mid + w * W * 0.5, tip, mid - w * W * 0.5]
    top = mid + nn * 0.07; bot = mid - nn * 0.07
    ids = [M.vert(q) for q in rim]; it, ib = M.vert(top), M.vert(bot)
    ox, oy = rng.uniform(0.15, 0.85), rng.uniform(0.15, 0.85)
    def uv(q):
        return cell_uv(cell, ox + (q - mid).dot(w) / LEAF_CELL, oy + (q - mid).dot(d) / LEAF_CELL)
    def nf(q, fn):
        g = q - crown_c
        g = Vector((g.x / crown_r[0], g.y / crown_r[1], g.z / crown_r[2])).normalized()
        return (fn * 0.6 + g * 0.4).normalized()
    for j in range(4):
        a, b = ids[j], ids[(j + 1) % 4]
        M.tri(it, a, b, mid, (uv(top), uv(M.v[a]), uv(M.v[b])), nf)
        M.tri(ib, b, a, mid, (uv(bot), uv(M.v[b]), uv(M.v[a])), nf)


def ico_template():
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=7, v_segments=4, radius=1.0)   # 42 tris: many small clumps beat a few big balls
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    bm.verts.ensure_lookup_table()
    v = [tuple(x.co) for x in bm.verts]
    f = [tuple(x.index for x in fc.verts) for fc in bm.faces]
    bm.free()
    return dict(v=v, f=f)


def tone(fam, c, crown_c, R, rng):
    rel = (Vector(c) - crown_c)
    s = 0.65 * rel.z / R[2] + 0.35 * Vector((rel.x / R[0], rel.y / R[1], 0)).dot(Vector((SUN.x, SUN.y, 0)).normalized()) + rng.uniform(-0.25, 0.25)
    return f"{fam}_" + ("light" if s > 0.3 else "dark" if s < -0.3 else "mid")


# ----------------------------------------------------------------------------------------------------------- trees
FORM = {
    #        crown radii (x h)      limbs  limb start z (x h)  bark          leaves  clumps
    "round": dict(R=(0.30, 0.29, 0.25), limbs=5, lz=(0.30, 0.46), bark="bark_oak", fam="broadA", clumps=52, trunk_top=0.50, r0=0.045),
    "oval": dict(R=(0.21, 0.20, 0.34), limbs=7, lz=(0.28, 0.66), bark="bark_smooth", fam="broadB", clumps=50, trunk_top=0.74, r0=0.038),
    "spread": dict(R=(0.38, 0.35, 0.22), limbs=6, lz=(0.30, 0.30), bark="bark_oak", fam="broadA", clumps=52, trunk_top=0.30, r0=0.05),
}


def broadleaf(name, form, h, seed, mat, ico):
    rng = random.Random(seed)
    F = FORM[form]
    R = Vector(F["R"]) * h
    cz = GZ + h - R.z - 1.2
    lean = Vector((rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5), 0))
    C = Vector((0, 0, cz)) + lean * 1.4
    W = Mesh(name); L = Mesh(name + "_Crown")
    r0 = F["r0"] * h
    ttop = GZ + F["trunk_top"] * h
    # trunk with a root flare (ends inside the crown's dark core, or at the fork for "spread")
    zs = [GZ - 0.4, GZ + 0.25, GZ + 1.2] + [GZ + 1.2 + (ttop - GZ - 1.2) * k / 4 for k in range(1, 5)]
    tp = [Vector((0, 0, z)) + lean * max(0.0, (z - GZ) / h) * 2.0 for z in zs]
    tr = [r0 * 1.55, r0 * 1.25, r0 * 1.02] + [r0 * (1.0 - 0.38 * k / 4) for k in range(1, 5)]
    loft(W, tp, tr, 9, F["bark"], vspan=max(9.0, ttop - GZ))
    def trunk_at(z):
        z = min(max(z, zs[0]), zs[-1])
        for i in range(len(zs) - 1):
            if zs[i] <= z <= zs[i + 1]:
                t = (z - zs[i]) / (zs[i + 1] - zs[i]); return tp[i].lerp(tp[i + 1], t), tr[i] + (tr[i + 1] - tr[i]) * t
        return tp[-1], tr[-1]
    tips = []
    az0 = rng.uniform(0, 2 * math.pi)
    if form == "spread":      # low fork: 3 leaders, limbs from their ends
        top, _ = trunk_at(ttop)
        heads = []
        for k in range(3):
            a = az0 + 2 * math.pi * k / 3 + rng.uniform(-0.3, 0.3)
            e = C + Vector((math.cos(a) * R.x * 0.42, math.sin(a) * R.y * 0.42, -R.z * 0.35))
            loft(W, bend_path(top - Vector((0, 0, 0.6)), e, 5, rng, bow=0.15), [r0 * 0.85, r0 * 0.75, r0 * 0.62, r0 * 0.52, r0 * 0.45], 7,
                 F["bark"], cap0=True, vspan=9.0)
            heads.append((e, a))
        starts = [(heads[k % 3][0], heads[k % 3][1] + rng.uniform(-0.9, 0.9), r0 * 0.4) for k in range(F["limbs"])]
    else:
        starts = []
        for k in range(F["limbs"]):
            z = F["lz"][0] * h + (F["lz"][1] - F["lz"][0]) * h * (k / max(1, F["limbs"] - 1)) + GZ
            p, rr = trunk_at(z)
            starts.append((p, az0 + k * 2.39996 + rng.uniform(-0.25, 0.25), rr * 0.55))
    for (p, a, rr) in starts:
        el = rng.uniform(0.05, 0.55) if form != "oval" else rng.uniform(0.35, 0.8)
        e = C + Vector((math.cos(a) * R.x * 0.62, math.sin(a) * R.y * 0.62, R.z * el))
        path = bend_path(p, e, 5, rng)
        loft(W, path, [rr, rr * 0.82, rr * 0.62, rr * 0.45, rr * 0.32], 6, F["bark"], vspan=9.0)
        tips.append(e)
        # one twig off the limb's middle toward the shell
        a2 = a + rng.choice((-1, 1)) * rng.uniform(0.5, 0.9)
        e2 = C + Vector((math.cos(a2) * R.x * 0.7, math.sin(a2) * R.y * 0.7, R.z * rng.uniform(0.0, 0.6)))
        loft(W, bend_path(path[2], e2, 4, rng, bow=0.15), [rr * 0.5, rr * 0.38, rr * 0.28, rr * 0.2], 5, F["bark"], vspan=9.0)
        tips.append(e2)
    # crown: a clump on every limb / twig tip (hides the capped ends), shell clumps, a dark core
    centres = [(t, 1.0) for t in tips]
    while len(centres) < F["clumps"]:
        d = Vector((rng.gauss(0, 1), rng.gauss(0, 1), rng.gauss(0, 1))).normalized()
        if d.z < -0.6:
            continue
        centres.append((C + Vector((d.x * R.x, d.y * R.y, d.z * R.z)) * rng.uniform(0.62, 0.92), 1.0))
    for k in range(4):
        a = az0 + k * math.pi / 2
        centres.append((C + Vector((math.cos(a) * R.x * 0.3, math.sin(a) * R.y * 0.3, -R.z * 0.15 + k * 0.4)), 1.25))
    ttp, _ = trunk_at(ttop)
    # the trunk's capped top hides in a dark clump; a low fork ("spread") caps inside its leaders, so that clump goes to the core
    centres.append(((ttp + Vector((0, 0, 0.6))) if form != "spread" else (C - Vector((0, 0, R.z * 0.3))), 1.1))
    rmax = min(1.9, 0.3 * min(R.x, R.z) + 0.5)
    for i, (c, scale) in enumerate(centres):
        core = i >= len(centres) - 5
        r = rng.uniform(rmax * 0.72, rmax) * scale
        rr = (r, r * rng.uniform(0.9, 1.1), r * rng.uniform(0.72, 0.85))
        if core:
            rr = tuple(min(x * 1.3, 2.4) for x in rr)
        cell = f"{F['fam']}_dark" if core else tone(F["fam"], c, C, R, rng)
        clump(L, c, rr, cell, C, R, rng, ico=ico, fringe=0 if core else 2)
    return W.build(mat, LOC), L.build(mat, LOC)


def conifer(name, form, h, seed, mat):
    rng = random.Random(seed)
    Rmax = (0.27 if form == "spruce" else 0.2) * h
    n = 11 if form == "spruce" else 12
    W = Mesh(name); L = Mesh(name + "_Crown")
    r0 = 0.04 * h
    ztop = GZ + h
    zb = GZ + (0.14 if form == "spruce" else 0.11) * h
    loft(W, [Vector((0, 0, GZ - 0.4)), Vector((0, 0, GZ + 0.3)), Vector((0, 0, zb + 1.5)), Vector((0, 0, GZ + 0.7 * h))],
         [r0 * 1.4, r0 * 1.1, r0 * 0.95, r0 * 0.4], 8, "bark_pine", vspan=10.0)
    axis_c = Vector((0, 0, (zb + ztop) / 2))
    crown_r = (Rmax, Rmax, (ztop - zb) / 2)
    gap = (ztop - 1.6 - zb) / (n - 1)
    def nf_for(apex_z):
        def nf(p, fn):
            g = Vector((p.x, p.y, 0)); g = g.normalized() if g.length > 1e-6 else Vector((0, 0, 0))
            return (fn * 0.3 + (g + Vector((0, 0, 0.6))).normalized() * 0.7).normalized()
        return nf
    for k in range(n):
        t = k / (n - 1)
        zr = zb + gap * k * (1.0 - 0.06 * t)
        r = Rmax * (1 - t) ** 0.9 + 0.7
        N = 16 if r > 2.6 else 10 if r > 1.6 else 7
        apex = Vector((0, 0, zr + gap * 1.15)); bot = Vector((0, 0, zr - gap * 0.4))
        a0 = rng.uniform(0, 2 * math.pi)
        rim, ang = [], []
        for i in range(2 * N):
            a = a0 + math.pi * i / N + rng.uniform(-0.08, 0.08)
            if i % 2 == 0:
                rr = r * rng.uniform(0.82, 1.08); z = zr - 0.3 * rr
            else:
                rr = r * 0.68; z = zr - 0.05 * r
            rim.append(Vector((math.cos(a) * rr, math.sin(a) * rr, z))); ang.append(a)
        mid = [Vector((q.x * 0.5, q.y * 0.5, (apex.z + q.z) / 2 + 0.08 * r)) for q in rim]
        ir = [L.vert(q) for q in rim]; im = [L.vert(q) for q in mid]; ia = L.vert(apex); ib = L.vert(bot)
        top_cell = "needle_dark" if (k == 0 or rng.random() < 0.2) else "needle_light"
        def uvb(q, a, cell):
            er = Vector((math.cos(a), math.sin(a), 0)); el = Vector((-math.sin(a), math.cos(a), 0))
            return cell_uv(cell, q.dot(el) / NEEDLE_CELL + 0.5, Vector((q.x, q.y, 0)).dot(er) / NEEDLE_CELL + 0.04)
        nf = nf_for(apex.z)
        ins_top = (bot + apex) / 2
        for i in range(2 * N):
            j = (i + 1) % (2 * N)
            a = ang[i - (i % 2)]          # the bough this wedge belongs to
            tri_uv = lambda *ids_: tuple(uvb(L.v[x], a, top_cell) for x in ids_)
            L.tri(ia, im[i], im[j], ins_top, tri_uv(ia, im[i], im[j]), nf)
            L.tri(im[i], ir[i], ir[j], ins_top, tri_uv(im[i], ir[i], ir[j]), nf)
            L.tri(im[i], ir[j], im[j], ins_top, tri_uv(im[i], ir[j], im[j]), nf)
            L.tri(ib, ir[j], ir[i], apex, tuple(uvb(L.v[x], a, "needle_dark") for x in (ib, ir[j], ir[i])), nf)
        # a drooping needle spray past every bough tip
        for i in range(0, 2 * N, 2):
            q = rim[i]
            d = (Vector((q.x, q.y, 0)).normalized() + Vector((0, 0, -0.25))).normalized()
            Ls = min(2.0, max(0.9, 0.34 * r))
            leaf_solid(L, q + d * Ls * 0.1, d, Ls, Ls * 0.7, top_cell, axis_c, crown_r, rng, droop=0.22, flat_to=Vector((0, 0, 1)))
    # leader spike on top, inside the top tier
    spike = [L.vert(Vector((math.cos(a) * 0.35, math.sin(a) * 0.35, ztop - 1.9))) for a in (0, 2.1, 4.2)]
    it = L.vert(Vector((0, 0, ztop))); ib2 = L.vert(Vector((0, 0, ztop - 2.2)))
    cc = Vector((0, 0, ztop - 1.8))
    for j in range(3):
        a, b = spike[j], spike[(j + 1) % 3]
        L.tri(it, a, b, cc, tuple(cell_uv("needle_light", 0.4 + 0.1 * x, 0.5) for x in range(3)), None)
        L.tri(ib2, b, a, cc, tuple(cell_uv("needle_dark", 0.4 + 0.1 * x, 0.5) for x in range(3)), None)
    return W.build(mat, LOC), L.build(mat, LOC)


def hedge(mat, ico, rng):
    """the front hedge (same three runs as Ext_Yard_Hedge: x -44..0, 6..15.5, 30.5..44, y -55.6..-54, top z 1.4) as a TRIMMED
    hedge: a rounded-top section swept along each run with a small surface wobble and the privet cell. The texture can't repeat
    past its atlas cell, so each run is cut into ~3-stud segments whose UVs each span the whole (left-right tiling) cell."""
    M = Mesh("Hedge_Front")
    yc = -54.8
    prof = [(-0.85, -0.1), (0.85, -0.1), (0.9, 0.9), (0.86, 1.8), (0.7, 2.22), (0.36, 2.4), (0.0, 2.44), (-0.36, 2.4),
            (-0.7, 2.22), (-0.86, 1.8), (-0.9, 0.9)]
    per = [0.0]
    for i in range(1, len(prof) + 1):
        a_, b_ = prof[i - 1], prof[i % len(prof)]
        per.append(per[-1] + math.hypot(b_[0] - a_[0], b_[1] - a_[1]))
    total = per[-1]
    def pnormal(i):
        a_, b_ = prof[i - 1], prof[(i + 1) % len(prof)]
        t = Vector((0, b_[0] - a_[0], b_[1] - a_[1])).normalized()
        return Vector((0, t.z, -t.y))          # outward for a CCW (y, z) profile
    for (x0, x1) in ((-44.0, 0.0), (6.0, 15.5), (30.5, 44.0)):
        nseg = max(1, int(round((x1 - x0) / 3.0)))
        sub = 2                                   # rings per segment (1.5 studs apart)
        xs = [x0 + (x1 - x0) * k / (nseg * sub) for k in range(nseg * sub + 1)]
        rings = []
        for k, x in enumerate(xs):
            ring = []
            for i, (py, pz) in enumerate(prof):
                q = Vector((x, yc + py, GZ + pz))
                if pz > 0 and 0 < k < len(xs) - 1:     # soft, clipped-leaf wobble; ends and the buried bottom stay true
                    q += pnormal(i) * rng.uniform(-0.07, 0.09)
                ring.append(M.vert(q))
            rings.append(ring)
        axis = lambda x: Vector((x, yc, GZ + 1.1))
        def nf(p, fn):
            r = Vector((0, p.y - yc, p.z - (GZ + 1.1))).normalized()
            return (r * 0.55 + fn * 0.45).normalized()
        n = len(prof)
        for k in range(len(xs) - 1):
            ua, ub = (k % sub) / sub, (k % sub + 1) / sub
            for i in range(n):
                j = (i + 1) % n
                va, vb = per[i] / total, per[i + 1] / total
                A, B, Cc, D = rings[k][i], rings[k][j], rings[k + 1][j], rings[k + 1][i]
                ins = axis((xs[k] + xs[k + 1]) / 2)
                uv = lambda u, v: cell_uv("hedge", u, v)
                M.tri(A, B, Cc, ins, (uv(ua, va), uv(ua, vb), uv(ub, vb)), nf)
                M.tri(A, Cc, D, ins, (uv(ua, va), uv(ub, vb), uv(ub, va)), nf)
        for (ring, x, sgn) in ((rings[0], xs[0], 1), (rings[-1], xs[-1], -1)):     # flat trimmed ends
            c = M.vert(Vector((x, yc, GZ + 1.1)))
            ins = Vector((x + sgn * 0.5, yc, GZ + 1.1))
            for i in range(n):
                P1, P2 = M.v[ring[i]], M.v[ring[(i + 1) % n]]
                uvs = tuple(cell_uv("hedge", (q.y - yc) / HEDGE_CELL[0] + 0.5, (q.z - GZ) / HEDGE_CELL[1] + 0.05) for q in (M.v[c], P1, P2))
                M.tri(c, ring[i], ring[(i + 1) % n], ins, uvs, None)
    return M.build(mat, (0, 0, 0))


def tree_material():
    mat = bpy.data.materials.new("H_Trees")
    pass
    nt = mat.node_tree; nt.nodes.clear()
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled"); out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(out.inputs["Surface"], bsdf.outputs[0])
    bsdf.inputs["Metallic"].default_value = 0.0
    def img(p, cs):
        im = bpy.data.images.load(os.path.join(hc.TEX, f"H_Trees_{p}.png")); im.colorspace_settings.name = cs
        t = nt.nodes.new("ShaderNodeTexImage"); t.image = im; return t
    nt.links.new(bsdf.inputs["Base Color"], img("color", "sRGB").outputs[0])
    nt.links.new(bsdf.inputs["Roughness"], img("rough", "Non-Color").outputs[0])
    nm = nt.nodes.new("ShaderNodeNormalMap"); nm.uv_map = "UVMap"
    nt.links.new(nm.inputs["Color"], img("normal", "Non-Color").outputs[0])
    nt.links.new(bsdf.inputs["Normal"], nm.outputs[0])
    mat.diffuse_color = hc.srgb((70, 98, 48))
    return mat


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    mat = tree_material()
    ico = ico_template()
    obs, man = [], dict(
        note="Plan coordinates, same as H_Exterior.fbx (outside ground z = -1); import scale from K_ScaleCube (10 studs). Each "
             "Tree_NN here replaces H_Exterior's Tree_NN, Tree_NN_Leaves and Tree_NN_LeavesDark (hide those); Hedge_Front replaces "
             "Ext_Yard_Hedge. All art: CanCollide off, CastShadow on for trunks, crowns may keep shadows (realistic). One "
             "SurfaceAppearance for every object: ColorMap/NormalMap/RoughnessMap = the three H_Trees_* images, AlphaMode Overlay "
             "(no transparency used).",
        atlas={p: f"tex/H_Trees_{p}.png" for p in ("color", "normal", "rough")}, objects=[])
    bi = ci = 0
    for i, (x, y, k) in enumerate(SPOTS):
        h = random.Random(i).uniform(14, 20)
        nm = f"Tree_{i + 1:02d}"
        global LOC, CONIFER
        LOC = (x, y, 0); CONIFER = k == "cone"
        if k == "broad":
            form = BROAD_FORMS[bi % 3]; bi += 1
            pair = broadleaf(nm, form, h, 500 + i, mat, ico)
        else:
            form = CONE_FORMS[ci % 2]; ci += 1
            pair = conifer(nm, form, h, 700 + i, mat)
        for o in pair:
            o.location = (x, y, 0); o["form"] = form; o["height"] = round(h, 2)
            obs.append(o)
        hc.log(nm, form, round(h, 1), [hc.tris(o) for o in pair])
    hg = hedge(mat, ico, random.Random(9))
    hg["form"] = "hedge"
    obs.append(hg)
    cube, mk = hc.scale_cube_marker()
    cube.location = (0, -120, 30); mk.location = (12, -120, 25)      # same spots as in H_Exterior.fbx
    bpy.context.view_layer.update()
    for o in obs:
        lo, hi = hc.bbox([o])
        man["objects"].append(dict(name=o.name, form=o["form"], tris=hc.tris(o), material=[m.name for m in o.data.materials],
                                   location_plan=[round(v, 2) for v in o.location],
                                   bbox_plan=[[round(v, 2) for v in lo], [round(v, 2) for v in hi]],
                                   replaces=([o.name, o.name + "_Leaves", o.name + "_LeavesDark"] if o.name.startswith("Tree_") and "_Crown" not in o.name
                                             else ["Ext_Yard_Hedge"] if o.name == "Hedge_Front" else [])))
    man["markers"] = dict(K_ScaleCube=[0, -120, 30], K_Marker=[12, -120, 25])
    man["total_tris"] = sum(e["tris"] for e in man["objects"])
    man["tree_tris"] = sum(e["tris"] for e in man["objects"] if e["name"].startswith("Tree_"))
    json.dump(man, open(os.path.join(ROOT, "house_trees.json"), "w"), indent=1)
    if "--noexport" not in hc.ARGV:
        hc.export_fbx(os.path.join(hc.FBXD, "H_Trees.fbx"), obs + [cube, mk])
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    bpy.ops.file.make_paths_relative(); bpy.ops.wm.save_mainfile()
    hc.log("DONE", len(obs), "objects", man["total_tris"], "tris (trees", man["tree_tris"], ")")


if __name__ == "__main__":
    main()

"""Tacticals exfil helicopter kit (UH-60 Black Hawk class, RIVALS craft, Tacticals palette). Own geometry only.

Run headless (never touches Edward's open Blender scene):
  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python tools/heli_kit.py
Writes kit/heli.blend, kit/heli.fbx, kit/heli_manifest.json and out/heli/bl_*.png (then run python tools/heli_sheet.py).

Authoring frame = STUDIO coordinates relative to the Heli pivot (world (133, -0.1, 0), axes world-aligned): x = world +X (starboard,
toward the open sky edge), y up, z = world +Z (nose at -Z, tail at +Z). 1 unit = 1 stud. Converted to Blender Z-up by
S2B: Blender (x, y, z) = (-Xs, Zs, Ys) at export (the convention of every earlier Tacticals kit).
Mesh names: <piece>__<material>; one material per mesh (colour split). Pieces: HX_Body (static), HX_Door (open port door leaf),
HX_RotorMain (Rotor = Main), HX_RotorTail (Rotor = Tail). Markers: K_Scale7 (10-stud cube at (0, 60, 0)) + K_Marker7.
Hook geometry (see notes/heli_survey.md): mast axis x 0, z 0; rotor plane y 10.3; CabinPoint (-0.6, 4.3, 0.4) local; port door
z -2.2..3.0, y 1.4..6.5 open; tail rotor hub (1.7, 9.5, 20.6), axis (cos20, sin20, 0).
"""
import bpy, bmesh, math, os, json
from mathutils import Vector, Matrix

ROOT = r"C:/Users/aroki/Documents/tacticals_rebuild"
KIT = ROOT + "/kit/"
OUT = ROOT + "/out/heli/"
os.makedirs(OUT, exist_ok=True)
S2B = Matrix(((-1, 0, 0, 0), (0, 0, 1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
UV_STUDS = 8.0

# name: (sRGB, metallic, roughness, emissive, Studio material, Studio props)
# Studio props: collide, query, fidelity, castShadow, transparency, reflectance
MATS = {
    "olive":      ((84, 90, 50),    0.0, 0.55, False, "SmoothPlastic", (True, True, "Hull", True, 0, 0)),
    "olive_dark": ((64, 70, 40),    0.0, 0.6,  False, "SmoothPlastic", (False, True, "Box", True, 0, 0)),
    "trim_dark":  ((30, 32, 30),    0.0, 0.6,  False, "SmoothPlastic", (False, False, "Box", True, 0, 0)),
    "glass":      ((40, 48, 52),    0.0, 0.05, False, "Glass", (False, False, "Box", False, 0.25, 0.3)),
    "glass_back": ((14, 16, 16),    0.0, 0.95, False, "SmoothPlastic", (False, False, "Box", False, 0, 0)),
    "metal":      ((160, 154, 142), 0.85, 0.4, False, "Metal", (False, False, "Box", True, 0, 0)),
    "cream":      ((236, 232, 218), 0.0, 0.6,  False, "SmoothPlastic", (False, False, "Box", False, 0, 0)),
    "cabin":      ((24, 26, 23),    0.0, 0.9,  False, "SmoothPlastic", (False, False, "Box", True, 0, 0)),
    "blade":      ((34, 36, 34),    0.0, 0.5,  False, "SmoothPlastic", (False, False, "Box", True, 0, 0)),
    "nav_red":    ((255, 60, 40),   0.0, 0.5,  True,  "Neon", (False, False, "Box", False, 0, 0)),
    "nav_green":  ((60, 255, 110),  0.0, 0.5,  True,  "Neon", (False, False, "Box", False, 0, 0)),
    "nav_amber":  ((255, 170, 40),  0.0, 0.5,  True,  "Neon", (False, False, "Box", False, 0, 0)),
    "k_cube":     ((236, 232, 218), 0.0, 0.6,  False, "SmoothPlastic", (False, False, "Box", False, 0, 0)),
    "k_mark":     ((107, 122, 58),  0.0, 0.6,  True,  "Neon", (False, False, "Box", False, 0, 0)),
}

def srgb2lin(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

def make_material(name):
    m = bpy.data.materials.get(name)
    if m:
        return m
    rgb, metal, rough, emis, studio, _ = MATS[name]
    lin = [srgb2lin(v) for v in rgb]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*lin, 1)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    if emis:
        b.inputs["Emission Color"].default_value = (*lin, 1)
        b.inputs["Emission Strength"].default_value = 4.0
    m.diffuse_color = (*lin, 1)
    if name == "glass":   # Eevee look of Roblox Glass at T 0.25 / Reflectance 0.3
        b.inputs["Alpha"].default_value = 0.78
        b.inputs["Roughness"].default_value = 0.04
        try:
            m.surface_render_method = "DITHERED"
        except Exception:
            pass
    m["studio"] = studio
    m["rgb"] = list(rgb)
    return m

# ------------------------------------------------------------------ accumulators (closed solids recalc locally)
ACC = {}
def acc(piece, mat):
    k = (piece, mat)
    if k not in ACC:
        ACC[k] = bmesh.new()
    return ACC[k]

class Solid:
    """with Solid(piece, mat) as bm: ... -> faces made inside get consistent outward normals (closed solids only)."""
    def __init__(self, piece, mat):
        self.bm = acc(piece, mat)
    def __enter__(self):
        for f in self.bm.faces:
            f.tag = True
        return self.bm
    def __exit__(self, *a):
        new = [f for f in self.bm.faces if not f.tag]
        if new:
            bmesh.ops.recalc_face_normals(self.bm, faces=new)
        for f in self.bm.faces:
            f.tag = True

def face(bm, pts, want=None):
    """Make a face from studio points; if want (a direction) is given, orient the normal along it."""
    vs = [bm.verts.new(Vector(p)) for p in pts]
    f = bm.faces.new(vs)
    if want is not None:
        f.normal_update()
        if f.normal.dot(Vector(want)) < 0:
            f.normal_flip()
    return f

def box(piece, mat, c, s, bev=0.08, seg=1, M=None):
    with Solid(piece, mat) as bm:
        T = Matrix.Translation(c) @ Matrix.Diagonal((s[0], s[1], s[2], 1))
        if M is not None:
            T = M @ T
        r = bmesh.ops.create_cube(bm, size=1.0, matrix=T)
        b = min(bev, min(s) * 0.4)
        if b > 0.004:
            edges = list({e for v in r["verts"] for e in v.link_edges})
            bmesh.ops.bevel(bm, geom=edges, offset=b, offset_type="OFFSET", segments=seg, profile=0.5, affect="EDGES",
                            clamp_overlap=True)

def plate(piece, mat, poly, axis, t0, t1, bev=0.08):
    """Polygon in a plane, extruded along a world axis. axis 'x': poly = [(z, y)]; 'y': [(x, z)]; 'z': [(x, y)]."""
    with Solid(piece, mat) as bm:
        def P(a, b, t):
            if axis == "x": return Vector((t, b, a))
            if axis == "y": return Vector((a, t, b))
            return Vector((a, b, t))
        A = [bm.verts.new(P(a, b, t0)) for a, b in poly]
        B = [bm.verts.new(P(a, b, t1)) for a, b in poly]
        n = len(poly)
        f0 = bm.faces.new(A); f1 = bm.faces.new(B[::-1])
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((A[i], A[j], B[j], B[i]))
        if bev > 0:
            edges = list({e for v in A + B for e in v.link_edges})
            bmesh.ops.bevel(bm, geom=edges, offset=bev, offset_type="OFFSET", segments=1, profile=0.5, affect="EDGES",
                            clamp_overlap=True)

def revolve(piece, mat, prof, M, seg=16, cap=True):
    """Revolve an (r, h) profile about local +Y (r = 0 ends close it), transform by M (studio)."""
    with Solid(piece, mat) as bm:
        rings = []
        for i in range(seg):
            a = 2 * math.pi * i / seg
            ca, sa = math.cos(a), math.sin(a)
            rings.append([bm.verts.new(M @ Vector((r * ca, h, r * sa))) for (r, h) in prof])
        n = len(prof)
        for i in range(seg):
            A, B = rings[i], rings[(i + 1) % seg]
            for k in range(n - 1):
                bm.faces.new((A[k], B[k], B[k + 1], A[k + 1]))
        if cap:
            if prof[0][0] > 1e-6:
                bm.faces.new([r[0] for r in rings])
            if prof[-1][0] > 1e-6:
                bm.faces.new([r[-1] for r in rings][::-1])
        bmesh.ops.remove_doubles(bm, verts=[v for r in rings for v in r], dist=1e-5)

def frame_to(p0, d):
    """Matrix taking local +Y to direction d, origin p0."""
    q = Vector((0, 1, 0)).rotation_difference(Vector(d).normalized())
    return Matrix.Translation(p0) @ q.to_matrix().to_4x4()

def rod(piece, mat, p0, p1, r, seg=8):
    p0 = Vector(p0); p1 = Vector(p1); L = (p1 - p0).length
    revolve(piece, mat, [(r, 0), (r, L)], frame_to(p0, p1 - p0), seg=seg)

def dome(piece, mat, c, r, d, seg=10):
    """Hemispherical lens of radius r at c bulging along d."""
    prof = [(r * math.cos(math.pi / 2 * k / 3), r * math.sin(math.pi / 2 * k / 3)) for k in range(4)]
    revolve(piece, mat, prof, frame_to(Vector(c), d), seg=seg)

# ------------------------------------------------------------------ fuselage loft
# stations: z, yb, yt, hw, rb, rt
ST = [
    # sharper, sloped UH-60 nose: low pointed tip, long raked windshield line (v2, Edward: "windows look fake")
    (-13.45, 1.95, 2.55, 0.40, 0.15, 0.20),
    (-13.05, 1.55, 3.30, 1.35, 0.45, 0.55),
    (-12.35, 1.20, 4.05, 2.40, 0.70, 0.90),
    (-11.45, 1.05, 4.80, 3.08, 0.80, 1.20),
    (-10.40, 1.00, 5.75, 3.46, 0.80, 1.45),
    (-9.35, 1.00, 6.60, 3.58, 0.80, 1.60),
    (-8.35, 1.00, 7.20, 3.60, 0.80, 1.60),
    (-7.30, 1.00, 7.40, 3.60, 0.80, 1.60),
    (7.00, 1.00, 7.40, 3.60, 0.80, 1.60),
    (8.60, 1.50, 7.38, 3.48, 0.85, 1.58),
    (10.50, 3.35, 7.33, 2.45, 0.90, 1.30),
    (12.40, 4.45, 7.28, 1.75, 0.80, 1.00),
    (14.60, 5.05, 7.22, 1.30, 0.60, 0.80),
    (16.80, 5.50, 7.16, 0.80, 0.40, 0.50),
    (18.40, 5.85, 7.10, 0.46, 0.30, 0.36),
]
NOSE_POLE = Vector((0, 2.22, -13.62))
TAIL_POLE = Vector((0, 6.48, 18.58))

def _pchip(xs, ys):
    n = len(xs); h = [xs[i + 1] - xs[i] for i in range(n - 1)]
    d = [(ys[i + 1] - ys[i]) / h[i] for i in range(n - 1)]
    m = [0.0] * n
    m[0], m[-1] = d[0], d[-1]
    for i in range(1, n - 1):
        if d[i - 1] * d[i] <= 0:
            m[i] = 0.0
        else:
            w1, w2 = 2 * h[i] + h[i - 1], h[i] + 2 * h[i - 1]
            m[i] = (w1 + w2) / (w1 / d[i - 1] + w2 / d[i])
    def f(x):
        x = min(max(x, xs[0]), xs[-1])
        i = max(0, min(n - 2, max(k for k in range(n - 1) if xs[k] <= x)))
        t = (x - xs[i]) / h[i]
        h00 = 2 * t ** 3 - 3 * t ** 2 + 1; h10 = t ** 3 - 2 * t ** 2 + t; h01 = -2 * t ** 3 + 3 * t ** 2; h11 = t ** 3 - t ** 2
        return h00 * ys[i] + h10 * h[i] * m[i] + h01 * ys[i + 1] + h11 * h[i] * m[i + 1]
    return f

_ZS = [s[0] for s in ST]
_F = [_pchip(_ZS, [s[k] for s in ST]) for k in range(1, 6)]

def sec(z):
    yb, yt, hw, rb, rt = [f(z) for f in _F]
    hh = (yt - yb) / 2
    rb = min(rb, hw * 0.98, hh * 0.98); rt = min(rt, hw * 0.98, hh * 0.98)
    return yb, yt, hw, rb, rt

_RCACHE = {}
def ring_poly(z, inner=None):
    key = (round(z, 5), inner)
    if key in _RCACHE:
        return _RCACHE[key]
    yb, yt, hw, rb, rt = inner if inner else sec(z)
    pts = []
    for (cx, cy, r, a0) in ((hw - rb, yb + rb, rb, -90), (hw - rt, yt - rt, rt, 0), (-(hw - rt), yt - rt, rt, 90),
                            (-(hw - rb), yb + rb, rb, 180)):
        for k in range(13):
            a = math.radians(a0 + 90 * k / 12)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    yc = (yb + yt) / 2
    angs = [math.atan2(y - yc, x) % (2 * math.pi) for x, y in pts]
    _RCACHE[key] = (pts, angs, yc)
    return _RCACHE[key]

def surf(z, a, inner=None):
    """Point on the loft at station z, polar angle a about (0, yc) (a = 0 starboard, pi/2 top, pi port)."""
    pts, angs, yc = ring_poly(z, inner)
    a = a % (2 * math.pi)
    d = Vector((math.cos(a), math.sin(a)))
    n = len(pts)
    for i in range(n):
        p, q = Vector(pts[i]), Vector(pts[(i + 1) % n])
        p = p - Vector((0, yc)); q = q - Vector((0, yc))
        e = q - p
        den = d.x * e.y - d.y * e.x
        if abs(den) < 1e-12:
            continue
        t = (p.x * e.y - p.y * e.x) / den
        u = (p.x * d.y - p.y * d.x) / den
        if t > 0 and -1e-9 <= u <= 1 + 1e-9:
            return Vector((t * d.x, yc + t * d.y, z))
    raise ValueError("no hit")

def a_at(z, y, side):
    """Polar angle on one side (-1 port, +1 starboard) where the surface height is y."""
    lo, hi = (math.pi / 2 + 1e-4, 3 * math.pi / 2 - 1e-4) if side < 0 else (-math.pi / 2 + 1e-4, math.pi / 2 - 1e-4)
    # port: height falls as a grows; starboard: height rises as a grows
    for _ in range(60):
        mid = (lo + hi) / 2
        h = surf(z, mid).y
        if (h > y) == (side < 0):
            lo = mid
        else:
            hi = mid
    return (lo + hi) / 2

def normal_at(z, a):
    e = 1e-3
    pa = surf(z, a + e) - surf(z, a - e)
    z0, z1 = max(z - e, ST[0][0]), min(z + e, ST[-1][0])
    pz = surf(z1, a) - surf(z0, a)
    n = pa.cross(pz)
    return n.normalized()

# door (port, open) and cabin liner
DOOR_Z0, DOOR_Z1, DOOR_Y0, DOOR_Y1 = -2.2, 3.0, 1.4, 6.5
LIN_X, LIN_Y0, LIN_Y1, LIN_Z0, LIN_Z1 = 3.0, 1.25, 6.6, -2.7, 4.6
CAB_Z = -4.0   # a station inside the constant section

# glazing set INTO the hull (v2): every pane is a real opening in the loft grid (grid lines snapped onto its edges), with the
# glass recessed GLASS_RECESS behind the skin and conforming to it, a dark matte shell SHELL_DEPTH behind (depth, no interior,
# no sky), dark jamb walls, and a thin raised seal (SEAL_H proud, SEAL_W wide) round the opening.
GLASS_RECESS, SHELL_DEPTH, SEAL_H, SEAL_W = 0.045, 0.45, 0.06, 0.10
N_RING = 36
TOP = math.pi / 2

def _port(y0, y1, zref):
    return a_at(zref, y1, -1), a_at(zref, y0, -1)

def windows_def():
    """(name, z0, z1, a0, a1): port side + mirrored starboard (a -> pi - a). UH-60 layout (notes/heli_reference.md)."""
    W = []
    def both(name, z0, z1, a0, a1, sides=(-1, 1)):
        for sd in sides:
            if sd < 0:
                W.append((name + "_P", z0, z1, a0, a1))
            else:
                W.append((name + "_S", z0, z1, math.pi - a1, math.pi - a0))
    both("Windshield", -11.30, -9.40, TOP + 0.08, TOP + 1.02)          # two big panes wrapping the nose, centre post between
    both("Overhead", -8.95, -7.35, TOP + 0.13, TOP + 0.58)             # roof windows over the pilots
    both("CockpitDoor", -9.10, -6.95, *_port(3.95, 6.30, -8.4))        # main side window in each cockpit door
    both("Chin", -12.1, -11.0, *_port(1.85, 2.95, -11.5))            # lower nose (chin) windows by the pedals
    both("Gunner", -5.55, -3.40, *_port(4.35, 6.20, CAB_Z))            # gunner windows just behind the cockpit
    both("CabinDoorA", -1.55, 0.15, *_port(4.30, 6.00, CAB_Z), sides=(1,))   # starboard cabin door (closed): two windows
    both("CabinDoorB", 0.65, 2.35, *_port(4.30, 6.00, CAB_Z), sides=(1,))
    return W

def glazing_parts(P, N, rect, accp="HX_Body", recess=GLASS_RECESS, depth=SHELL_DEPTH):
    """Glass, dark shell, jamb and raised seal for one opening rect (i0, i1, k0, k1) on a point grid P[i][k] with normals N."""
    i0, i1, k0, k1 = rect
    gl, sh, tr = acc(accp, "glass"), acc(accp, "glass_back"), acc(accp, "trim_dark")
    ni, nk = len(P), len(P[0])
    def T(i, k, di, dk):
        a = P[min(max(i + di, 0), ni - 1)][min(max(k + dk, 0), nk - 1)]
        b = P[min(max(i - di, 0), ni - 1)][min(max(k - dk, 0), nk - 1)]
        return (a - b).normalized()
    for i in range(i0, i1):
        for k in range(k0, k1):
            q = [(i, k), (i, k + 1), (i + 1, k + 1), (i + 1, k)]
            nc = sum((N[a][b] for a, b in q), Vector()).normalized()
            face(gl, [P[a][b] - N[a][b] * recess for a, b in q], nc)
            face(sh, [P[a][b] - N[a][b] * depth for a, b in q], nc)
    loop = [(i, k0) for i in range(i0, i1)] + [(i1, k) for k in range(k0, k1)] + \
           [(i, k1) for i in range(i1, i0, -1)] + [(i0, k) for k in range(k1, k0, -1)]
    def out_dir(i, k):
        si = -1 if i == i0 else (1 if i == i1 else 0)
        sk = -1 if k == k0 else (1 if k == k1 else 0)
        d = T(i, k, 1, 0) * si + T(i, k, 0, 1) * sk
        n = N[i][k]; d = (d - n * d.dot(n)).normalized()
        return d * (SEAL_W * (1.41 if si and sk else 1.0))
    for j in range(len(loop)):
        (iu, ku), (iv, kv) = loop[j], loop[(j + 1) % len(loop)]
        Pu, Pv, nu, nv = P[iu][ku], P[iv][kv], N[iu][ku], N[iv][kv]
        du, dv = out_dir(iu, ku), out_dir(iv, kv)
        face(tr, [Pu + nu * SEAL_H, Pv + nv * SEAL_H, Pv - nv * depth, Pu - nu * depth], -(du + dv))            # jamb + seal inner wall
        face(tr, [Pu + nu * SEAL_H, Pv + nv * SEAL_H, Pv + nv * SEAL_H + dv, Pu + nu * SEAL_H + du], nu + nv)  # seal top
        face(tr, [Pu + du - nu * 0.03, Pv + dv - nv * 0.03, Pv + dv + nv * SEAL_H, Pu + du + nu * SEAL_H], du + dv)  # seal outer wall

def fuselage():
    a_top = a_at(CAB_Z, DOOR_Y1, -1); a_bot = a_at(CAB_Z, DOOR_Y0, -1)
    openings = [(n, z0, z1, a0, a1, "glass") for (n, z0, z1, a0, a1) in windows_def()]
    openings.append(("Door_P", DOOR_Z0, DOOR_Z1, a_top, a_bot, "door"))
    A0 = [-math.pi / 2 + 2 * math.pi * (k + 0.5) / N_RING for k in range(N_RING)]   # no sample on the top centre line: the windshield centre post is one column
    snaps = []   # snap index per opening edge (same for every ring the opening spans)
    for (n, z0, z1, a0, a1, kind) in openings:
        k0 = min(range(N_RING), key=lambda k: abs(A0[k] - a0)); k1 = min(range(N_RING), key=lambda k: abs(A0[k] - a1))
        assert k1 > k0, n
        snaps.append((k0, k1))
    Z = []
    for i in range(len(ST) - 1):
        z0, z1 = ST[i][0], ST[i + 1][0]
        nsub = 1 if (z1 - z0) > 6 else 2
        Z += [z0 + (z1 - z0) * k / nsub for k in range(nsub)]
    Z += [ST[-1][0]]
    edges = set()
    for o in openings:
        edges |= {round(o[1], 4), round(o[2], 4)}
    Z = sorted(set(round(z, 4) for z in Z) | edges)
    Zf = []
    for z in Z:   # drop non-edge rings closer than 0.25 to an edge ring (no slivers)
        if z in edges or min(abs(z - e) for e in edges) > 0.25:
            Zf.append(z)
    Z = Zf
    bm = acc("HX_Body", "olive")
    Pg, Ng = [], []
    for z in Z:
        A = list(A0)
        used = {}
        for (o, (k0, k1)) in zip(openings, snaps):
            if o[1] - 1e-4 <= z <= o[2] + 1e-4:
                for k, a in ((k0, o[3]), (k1, o[4])):
                    assert abs(used.get(k, a) - a) < 1e-9, ("snap clash", o[0], k)
                    used[k] = a; A[k] = a
        assert all(A[k] < A[k + 1] for k in range(N_RING - 1)), ("ring order", z)
        Pg.append([surf(z, a) for a in A]); Ng.append([normal_at(z, a) for a in A])
    R = [[bm.verts.new(p) for p in row] for row in Pg]
    n = N_RING
    rects, hole = {}, set()
    for (o, (k0, k1)) in zip(openings, snaps):
        i0 = Z.index(round(o[1], 4)); i1 = Z.index(round(o[2], 4))
        rects[o[0]] = ((i0, i1, k0, k1), o[5])
        for i in range(i0, i1):
            for k in range(k0, k1):
                assert (i, k) not in hole, ("overlap", o[0])
                hole.add((i, k))
    for i in range(len(Z) - 1):
        for k in range(n):
            if (i, k) in hole:
                continue
            k2 = (k + 1) % n
            bm.faces.new((R[i][k], R[i][k2], R[i + 1][k2], R[i + 1][k]))
    pn = bm.verts.new(NOSE_POLE); pt = bm.verts.new(TAIL_POLE)
    for k in range(n):
        k2 = (k + 1) % n
        bm.faces.new((pn, R[0][k2], R[0][k]))
        bm.faces.new((pt, R[-1][k], R[-1][k2]))
    for name, (rect, kind) in rects.items():
        if kind == "glass":
            glazing_parts(Pg, Ng, rect)
    # door: jamb from the hole boundary to the flat liner wall at x = -LIN_X (dark trim), facing into the opening
    (i0, i1, k0, k1), _ = rects["Door_P"]
    jb = acc("HX_Body", "trim_dark")
    ctr = Vector((-3.3, (DOOR_Y0 + DOOR_Y1) / 2, (DOOR_Z0 + DOOR_Z1) / 2))
    def jquad(p, q):
        p2 = Vector((-LIN_X, p.y, p.z)); q2 = Vector((-LIN_X, q.y, q.z))
        want = ctr - (p + q) / 2; want.x = 0
        face(jb, [p, q, q2, p2], want)
    for i in range(i0, i1):
        jquad(Pg[i][k0], Pg[i + 1][k0]); jquad(Pg[i][k1], Pg[i + 1][k1])
    for k in range(k0, k1):
        jquad(Pg[i0][k], Pg[i0][k + 1]); jquad(Pg[i1][k], Pg[i1][k + 1])
    return len(Z), n, len(rects)

def cabin_liner():
    """Plain dark cabin volume, faces inward, port wall open at the door."""
    bm = acc("HX_Body", "cabin")
    x0, x1, y0, y1, z0, z1 = -LIN_X, LIN_X, LIN_Y0, LIN_Y1, LIN_Z0, LIN_Z1
    face(bm, [(x0, y0, z0), (x1, y0, z0), (x1, y0, z1), (x0, y0, z1)], (0, 1, 0))      # floor
    face(bm, [(x0, y1, z0), (x1, y1, z0), (x1, y1, z1), (x0, y1, z1)], (0, -1, 0))     # ceiling
    face(bm, [(x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0)], (0, 0, 1))      # front
    face(bm, [(x0, y0, z1), (x1, y0, z1), (x1, y1, z1), (x0, y1, z1)], (0, 0, -1))     # rear
    face(bm, [(x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1)], (-1, 0, 0))     # starboard
    W = (1, 0, 0)
    face(bm, [(x0, y0, z0), (x0, y1, z0), (x0, y1, DOOR_Z0), (x0, y0, DOOR_Z0)], W)
    face(bm, [(x0, y0, DOOR_Z1), (x0, y1, DOOR_Z1), (x0, y1, z1), (x0, y0, z1)], W)
    face(bm, [(x0, DOOR_Y1, DOOR_Z0), (x0, y1, DOOR_Z0), (x0, y1, DOOR_Z1), (x0, DOOR_Y1, DOOR_Z1)], W)
    face(bm, [(x0, y0, DOOR_Z0), (x0, DOOR_Y0, DOOR_Z0), (x0, DOOR_Y0, DOOR_Z1), (x0, y0, DOOR_Z1)], W)

# ------------------------------------------------------------------ surface patches (glazing, frames, seams, markings, door leaf)
def patch(piece, mat, z0, z1, arng, off, sides=0.0, nz=None, na=None):
    """Conforming patch on the loft over z0..z1 and per-z angle range arng(z) -> (a0, a1), offset 'off' along the normal.
    sides > 0: also builds the walls down to off - sides (a slab)."""
    bm = acc(piece, mat)
    a0m, a1m = arng((z0 + z1) / 2)
    nz = nz or max(1, int(abs(z1 - z0) / 1.2) + 1)
    na = na or max(1, int(abs(a1m - a0m) / 0.2) + 1)
    def P(z, a, o):
        return surf(z, a) + normal_at(z, a) * o
    G = []; B = []
    for i in range(nz + 1):
        z = z0 + (z1 - z0) * i / nz
        a0, a1 = arng(z)
        G.append([P(z, a0 + (a1 - a0) * k / na, off) for k in range(na + 1)])
        if sides > 0:
            B.append([P(z, a0 + (a1 - a0) * k / na, off - sides) for k in range(na + 1)])
    vt = [[bm.verts.new(p) for p in row] for row in G]
    for i in range(nz):
        for k in range(na):
            bm.faces.new((vt[i][k], vt[i][k + 1], vt[i + 1][k + 1], vt[i + 1][k]))   # a and z increasing: outward
    if sides > 0:
        vb = [[bm.verts.new(p) for p in row] for row in B]
        walls = []
        walls += [((0, k), (0, k + 1), vt[0][k].co - vt[1][k].co) for k in range(na)]
        walls += [((nz, k), (nz, k + 1), vt[nz][k].co - vt[nz - 1][k].co) for k in range(na)]
        walls += [((i, 0), (i + 1, 0), vt[i][0].co - vt[i][1].co) for i in range(nz)]
        walls += [((i, na), (i + 1, na), vt[i][na].co - vt[i][na - 1].co) for i in range(nz)]
        for (i0, k0), (i1, k1), want in walls:
            f = bm.faces.new((vt[i0][k0], vt[i1][k1], vb[i1][k1], vb[i0][k0]))
            f.normal_update()
            if f.normal.dot(want) < 0:
                f.normal_flip()

def side_rng(y0, y1, side):
    def f(z):
        a, b = a_at(z, y1, side), a_at(z, y0, side)
        return (a, b) if side < 0 else (b, a)
    return f

def const_rng(a0, a1):
    return lambda z: (a0, a1)

def window(z0, z1, rng, frame=0.16, glass_off=0.12, frame_off=0.17, piece="HX_Body"):
    """Framed glazing: a dark frame ring (slab) around a recessed near-black pane."""
    zm = (z0 + z1) / 2; a0, a1 = rng(zm); yb, yt = sec(zm)[:2]
    rmid = (surf(zm, (a0 + a1) / 2) - Vector((0, (yb + yt) / 2, zm))).length
    da = frame / max(rmid, 0.5)
    def inner(z):
        b0, b1 = rng(z); return (b0 + da, b1 - da)
    patch(piece, "glass", z0 + frame, z1 - frame, inner, glass_off)
    fo, fs = frame_off, frame_off
    patch(piece, "trim_dark", z0, z1, lambda z: (rng(z)[0], rng(z)[0] + da), fo, sides=fs, na=1)
    patch(piece, "trim_dark", z0, z1, lambda z: (rng(z)[1] - da, rng(z)[1]), fo, sides=fs, na=1)
    patch(piece, "trim_dark", z0, z0 + frame, lambda z: (rng(z)[0] + da, rng(z)[1] - da), fo, sides=fs, nz=1)
    patch(piece, "trim_dark", z1 - frame, z1, lambda z: (rng(z)[0] + da, rng(z)[1] - da), fo, sides=fs, nz=1)

def seam(z0, z1, rng, w=0.09, off=0.1):
    """Panel outline (door seams): thin dark slab strips."""
    a0, a1 = rng((z0 + z1) / 2)
    rmid = 3.4
    da = w / rmid
    patch("HX_Body", "trim_dark", z0, z1, lambda z: (rng(z)[0], rng(z)[0] + da), off, sides=off, na=1)
    patch("HX_Body", "trim_dark", z0, z1, lambda z: (rng(z)[1] - da, rng(z)[1]), off, sides=off, na=1)
    patch("HX_Body", "trim_dark", z0, z0 + w, lambda z: (rng(z)[0] + da, rng(z)[1] - da), off, sides=off, nz=1)
    patch("HX_Body", "trim_dark", z1 - w, z1, lambda z: (rng(z)[0] + da, rng(z)[1] - da), off, sides=off, nz=1)

def glazing():
    """Panel outlines only; the panes themselves are cut into the loft in fuselage()."""
    for sd in (-1, 1):
        seam(-9.35, -6.7, side_rng(1.55, 6.75, sd))        # cockpit door outline round the door window
    seam(DOOR_Z0, DOOR_Z1, side_rng(DOOR_Y0, DOOR_Y1, 1))  # starboard cabin door outline

def door_leaf():
    """Open port cabin door leaf, slid aft (z 3.15..8.35), 0.16 thick, two windows cut through it like the hull's."""
    zs = [3.15, 3.55, 4.5, 5.45, 5.95, 6.9, 7.85, 8.35]
    hs = [1.45, 2.9, 4.3, 5.2, 6.05, 6.5]
    TOPO, BOT = 0.30, 0.14
    base = []
    for z in zs:
        row = []
        for h in hs:
            a = a_at(z, h, -1); row.append((surf(z, a), normal_at(z, a)))
        base.append(row)
    P = [[p + n * TOPO for p, n in row] for row in base]
    B = [[p + n * BOT for p, n in row] for row in base]
    N = [[n for p, n in row] for row in base]
    wins = [(1, 3, 2, 4), (4, 6, 2, 4)]
    hole = {(i, k) for (i0, i1, k0, k1) in wins for i in range(i0, i1) for k in range(k0, k1)}
    ol = acc("HX_Door", "olive")
    for i in range(len(zs) - 1):
        for k in range(len(hs) - 1):
            q = [(i, k), (i, k + 1), (i + 1, k + 1), (i + 1, k)]
            nc = sum((N[a][b] for a, b in q), Vector()).normalized()
            if (i, k) not in hole:
                face(ol, [P[a][b] for a, b in q], nc)
            face(ol, [B[a][b] for a, b in q], -nc)
    ni, nk = len(zs) - 1, len(hs) - 1
    edges = [((i, 0), (i + 1, 0)) for i in range(ni)] + [((i, nk), (i + 1, nk)) for i in range(ni)] + \
            [((0, k), (0, k + 1)) for k in range(nk)] + [((ni, k), (ni, k + 1)) for k in range(nk)]
    cen = sum((P[i][k] for i in range(len(zs)) for k in range(len(hs))), Vector()) / (len(zs) * len(hs))
    for (a, b), (c, d) in edges:
        want = (P[a][b] + P[c][d]) / 2 - cen; nn = N[a][b]; want = want - nn * want.dot(nn)
        face(ol, [P[a][b], P[c][d], B[c][d], B[a][b]], want)
    for w in wins:
        glazing_parts(P, N, w, accp="HX_Door", depth=TOPO - BOT - 0.01)

def door_and_rails():
    # open port door leaf, slid aft over the cabin side
    door_leaf()
    # rails (metal): upper over the door and the leaf, lower under the leaf's track
    for s in (-1, 1):
        z0 = DOOR_Z0 - 0.4 if s < 0 else DOOR_Z0 - 0.2
        z1 = 8.6 if s < 0 else DOOR_Z1 + 0.3
        patch("HX_Body", "metal", z0, z1, side_rng(6.62, 6.86, s), 0.14, sides=0.14, na=1)
    patch("HX_Body", "metal", DOOR_Z1 - 0.2, 8.6, side_rng(1.18, 1.34, -1), 0.14, sides=0.14, na=1)

def markings():
    # cream identification band round the tail cone
    patch("HX_Body", "cream", 11.6, 12.15, const_rng(0, 2 * math.pi), 0.08, sides=0.08, na=32)
    # number stencils "07": nose sides under the gunner windows, both sides of the pylon
    text_mesh("07", 1.15, Vector((-3.6 - 0.1, 3.55, -4.45)), -1)
    text_mesh("07", 1.15, Vector((3.6 + 0.1, 3.55, -4.45)), 1)
    text_mesh("07", 1.05, Vector((-0.34 - 0.06, 6.85, 19.7)), -1)
    text_mesh("07", 1.05, Vector((0.34 + 0.06, 6.85, 19.7)), 1)

def text_mesh(txt, size, c, side):
    cu = bpy.data.curves.new("txt", type="FONT"); cu.body = txt; cu.size = size; cu.extrude = 0.03
    cu.resolution_u = 2; cu.align_x = "CENTER"; cu.align_y = "CENTER"; cu.space_character = 1.05
    ob = bpy.data.objects.new("txt", cu); bpy.context.scene.collection.objects.link(ob)
    dg = bpy.context.evaluated_depsgraph_get()
    me = ob.evaluated_get(dg).to_mesh()
    # text local (tx right, ty up, tz front) -> studio
    if side < 0:
        M = Matrix(((0, 0, -1, 0), (0, 1, 0, 0), (1, 0, 0, 0), (0, 0, 0, 1)))
    else:
        M = Matrix(((0, 0, 1, 0), (0, 1, 0, 0), (-1, 0, 0, 0), (0, 0, 0, 1)))
    M = Matrix.Translation(c) @ M
    with Solid("HX_Body", "cream") as bm:
        vs = [bm.verts.new(M @ v.co) for v in me.vertices]
        for p in me.polygons:
            try:
                bm.faces.new([vs[i] for i in p.vertices])
            except ValueError:
                pass
    ob.evaluated_get(dg).to_mesh_clear()
    bpy.data.objects.remove(ob, do_unlink=True); bpy.data.curves.remove(cu)

# ------------------------------------------------------------------ roof: transmission fairing, engines, exhausts, mast
def roof():
    prof = [(-5.3, 7.2), (7.4, 7.2), (6.0, 8.55), (4.6, 9.0), (-2.8, 9.0), (-4.2, 8.35)]
    plate("HX_Body", "olive_dark", prof, "x", -1.15, 1.15, bev=0.16)
    for s in (-1, 1):
        x = 1.85 * s
        M = frame_to(Vector((x, 8.2, -1.25)), (0, 0, 1))
        revolve("HX_Body", "olive_dark", [(0.62, 0), (0.86, 0.45), (0.88, 1.2), (0.88, 4.9), (0.72, 5.65)], M, seg=16)
        revolve("HX_Body", "trim_dark", [(0.0, 0), (0.56, 0), (0.56, 0.08), (0.0, 0.08)], frame_to(Vector((x, 8.2, -1.0)), (0, 0, -1)), seg=12)   # intake face
        # exhaust: angled outward-aft, warm grey metal, dark throat
        d = Vector((math.sin(math.radians(28)) * s, 0.06, math.cos(math.radians(28))))
        p0 = Vector((x, 8.2, 4.25))
        revolve("HX_Body", "metal", [(0.5, 0), (0.56, 0.6), (0.64, 1.45), (0.5, 1.45), (0.46, 0.9)], frame_to(p0, d), seg=14,
                cap=False)
        revolve("HX_Body", "trim_dark", [(0.0, 0), (0.5, 0), (0.5, 0.06), (0.0, 0.06)], frame_to(p0 + d * 0.9, d), seg=12)
        # cowling hinge line (dark seam) along each nacelle top
        box("HX_Body", "trim_dark", (x, 9.06, 1.6), (0.12, 0.06, 5.0), bev=0.02)
    # mast, swashplate (static), pitch links
    rod("HX_Body", "metal", (0, 8.9, 0), (0, 10.12, 0), 0.42, seg=16)
    revolve("HX_Body", "metal", [(0.3, 0), (0.85, 0), (0.85, 0.14), (0.3, 0.14)], Matrix.Translation((0, 9.25, 0)), seg=20)
    # wire-strike cutter (upper) on the cockpit roof, lower under the nose; pitot tubes; antennas
    plate("HX_Body", "trim_dark", [(-8.05, 7.2), (-7.55, 7.2), (-6.9, 8.25), (-7.05, 8.3)], "x", -0.07, 0.07, bev=0.02)
    plate("HX_Body", "trim_dark", [(-11.9, 1.5), (-11.3, 1.15), (-11.5, 0.75), (-11.75, 0.75)], "x", -0.07, 0.07, bev=0.02)
    for s in (-1, 1):
        rod("HX_Body", "metal", (1.1 * s, 7.25, -8.1), (1.1 * s, 7.45, -9.6), 0.05, seg=6)
    plate("HX_Body", "trim_dark", [(12.6, 7.2), (13.4, 7.2), (13.15, 8.1), (12.95, 8.1)], "x", -0.06, 0.06, bev=0.02)
    plate("HX_Body", "trim_dark", [(-6.9, 7.3), (-6.2, 7.3), (-6.35, 7.95), (-6.55, 7.95)], "x", -0.06, 0.06, bev=0.02)
    plate("HX_Body", "trim_dark", [(0.6, 1.1), (1.4, 1.1), (1.25, 0.55), (1.05, 0.55)], "x", -0.06, 0.06, bev=0.02)

# ------------------------------------------------------------------ tail: pylon, stabilator, tail wheel
TAIL_HUB = Vector((1.7, 9.5, 20.6))
CANT = math.radians(20)
TAIL_N = Vector((math.cos(CANT), math.sin(CANT), 0))          # disc normal (outboard, tilted up)
TAIL_V = Vector((-math.sin(CANT), math.cos(CANT), 0))          # disc "up" (top leans toward the fin)
TAIL_U = Vector((0, 0, 1))

def tail():
    pyl = [(15.9, 6.0), (19.2, 4.95), (22.35, 4.95), (22.75, 5.6), (22.55, 11.35), (21.95, 11.85), (20.9, 11.85), (15.9, 7.15)]
    plate("HX_Body", "olive", pyl, "x", -0.34, 0.34, bev=0.12)
    stab = [(-4.6, 20.25), (-4.6, 21.45), (4.6, 21.45), (4.6, 20.25), (1.0, 19.7), (-1.0, 19.7)]
    plate("HX_Body", "olive", stab, "y", 5.0, 5.28, bev=0.08)
    # tail rotor gearbox stub (static) from the fin out to the hub along the canted axis
    rod("HX_Body", "metal", TAIL_HUB - TAIL_N * 1.45, TAIL_HUB - TAIL_N * 0.25, 0.3, seg=12)
    revolve("HX_Body", "olive_dark", [(0.0, 0), (0.42, 0.0), (0.42, 0.7), (0.0, 0.9)], frame_to(TAIL_HUB - TAIL_N * 1.55, TAIL_N),
            seg=12)
    # tail wheel: raked strut + fork + wheel
    rod("HX_Body", "metal", (0, 5.55, 15.7), (0, 1.35, 16.75), 0.2, seg=10)
    rod("HX_Body", "metal", (0, 4.6, 14.9), (0, 3.4, 16.2), 0.12, seg=8)
    for s in (-1, 1):
        box("HX_Body", "metal", (0.36 * s, 1.0, 16.75), (0.1, 0.9, 0.35), bev=0.03)
    wheel((0, 0.76, 16.75), 0.56, 0.42)

def wheel(c, r, w):
    c = Vector(c)
    M = frame_to(c - Vector((w / 2, 0, 0)), (1, 0, 0))
    revolve("HX_Body", "trim_dark", [(0.0, 0), (r * 0.62, 0), (r * 0.9, 0.02 * w), (r, 0.22 * w), (r, 0.78 * w), (r * 0.9, 0.98 * w),
                                    (r * 0.62, w), (0.0, w)], M, seg=14)
    for s in (-1, 1):
        dome("HX_Body", "metal", c + Vector((s * w / 2, 0, 0)), r * 0.5, (s, 0, 0), seg=10)

def main_gear():
    for s in (-1, 1):
        xw = 4.45 * s
        # stub wing from the lower fuselage side
        box("HX_Body", "olive", (3.75 * s, 2.55, -4.5), (0.95, 0.5, 1.5), bev=0.12)
        rod("HX_Body", "metal", (4.0 * s, 2.5, -4.2), (4.0 * s, 0.95, -4.35), 0.17, seg=10)        # shock strut
        rod("HX_Body", "metal", (3.2 * s, 1.15, -6.3), (4.0 * s, 0.95, -4.35), 0.11, seg=8)        # drag beam
        wheel((xw, 0.84, -4.35), 0.66, 0.55)
        # cockpit step and starboard cabin step
        box("HX_Body", "metal", (3.82 * s, 1.75, -8.0), (0.5, 0.08, 0.9), bev=0.02)
    box("HX_Body", "metal", (3.82, 1.2, 0.4), (0.55, 0.08, 1.4), bev=0.02)

def nav_lights():
    for s, mat in ((-1, "nav_red"), (1, "nav_green")):
        dome("HX_Body", mat, (4.6 * s, 5.14, 20.85), 0.2, (s, 0, 0), seg=10)                   # stabilator tips
        p = surf(-6.6, math.pi / 2 + s * -0.95)
        n = normal_at(-6.6, math.pi / 2 + s * -0.95)
        dome("HX_Body", mat, p + n * 0.02, 0.2, n, seg=10)                                  # upper cabin shoulders
    dome("HX_Body", "nav_amber", (0, 11.86, 21.45), 0.24, (0, 1, 0), seg=10)                  # pylon top beacon
    dome("HX_Body", "nav_amber", (0, 1.0, 1.6), 0.24, (0, -1, 0), seg=10)                     # belly beacon

# ------------------------------------------------------------------ rotors
HUB_Y = 10.3
R_MAIN = 15.5
DROOP = math.radians(1.4)

def blade_strip(piece, mat, hub, radial, le, up, r0, r1, outline, thick, droop=0.0):
    """outline: [(r, c)] polygon in the blade plane (c toward the leading edge); thick: slab thickness."""
    pts = []
    for r, c in outline:
        p = hub + radial * (r * math.cos(droop)) + le * c - up * (r * math.sin(droop))
        pts.append(p)
    with Solid(piece, mat) as bm:
        A = [bm.verts.new(p - up * thick / 2) for p in pts]
        B = [bm.verts.new(p + up * thick / 2) for p in pts]
        n = len(pts)
        bm.faces.new(A); bm.faces.new(B[::-1])
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((A[i], A[j], B[j], B[i]))
        edges = list({e for v in A + B for e in v.link_edges})
        bmesh.ops.bevel(bm, geom=edges, offset=min(0.05, thick * 0.3), offset_type="OFFSET", segments=1, profile=0.5,
                        affect="EDGES", clamp_overlap=True)

def main_rotor():
    hub = Vector((0, HUB_Y, 0)); up = Vector((0, 1, 0))
    revolve("HX_RotorMain", "metal", [(0.0, -0.25), (1.05, -0.25), (1.15, -0.05), (1.15, 0.12), (0.9, 0.3), (0.0, 0.3)],
            Matrix.Translation(hub), seg=20)
    rod("HX_RotorMain", "metal", (0, HUB_Y + 0.3, 0), (0, HUB_Y + 0.75, 0), 0.25, seg=12)
    for k in range(4):
        psi = math.pi / 4 + k * math.pi / 2
        radial = Vector((math.cos(psi), 0, math.sin(psi)))
        le = Vector((math.sin(psi), 0, -math.cos(psi)))          # direction of travel (ExfilFX spins +Y)
        # bifilar absorber arm + weight on top
        b = math.pi / 4 * 0 + psi + math.pi / 4
        rb = Vector((math.cos(b), 0, math.sin(b)))
        p0 = hub + Vector((0, 0.68, 0)); p1 = p0 + rb * 0.95
        rod("HX_RotorMain", "metal", p0, p1, 0.09, seg=6)
        dome("HX_RotorMain", "metal", p1, 0.2, rb, seg=8)
        dome("HX_RotorMain", "metal", p1, 0.2, -rb, seg=8)
        # cuff (spindle) from the hub to the blade root
        cpos = hub + radial * 1.75
        rot = Matrix.Rotation(-psi, 4, "Y")
        box("HX_RotorMain", "metal", (0, 0, 0), (1.4, 0.36, 0.62), bev=0.06,
            M=Matrix.Translation(cpos) @ rot)
        # blade (near-black) and its cream tip
        body = [(2.3, -0.55), (14.2, -0.55), (14.2, 0.55), (2.3, 0.55), (1.9, 0.3), (1.9, -0.3)]
        tip = [(14.2, -0.55), (15.5, -0.55), (15.5, 0.12), (14.8, 0.55), (14.2, 0.55)]
        blade_strip("HX_RotorMain", "blade", hub, radial, le, up, 1.9, 14.2, body, 0.17, DROOP)
        blade_strip("HX_RotorMain", "cream", hub, radial, le, up, 14.2, 15.5, tip, 0.17, DROOP)

def tail_rotor():
    H = TAIL_HUB
    revolve("HX_RotorTail", "metal", [(0.0, -0.05), (0.36, -0.05), (0.36, 0.35), (0.2, 0.55), (0.0, 0.55)], frame_to(H, TAIL_N),
            seg=14)
    for k in range(4):
        psi = k * math.pi / 2 + math.pi / 4
        radial = TAIL_U * math.cos(psi) + TAIL_V * math.sin(psi)
        le = TAIL_U * -math.sin(psi) + TAIL_V * math.cos(psi)
        c = H + TAIL_N * 0.22
        body = [(0.35, -0.24), (3.05, -0.27), (3.05, 0.27), (0.35, 0.24)]
        tip = [(3.05, -0.27), (3.6, -0.27), (3.6, 0.27), (3.05, 0.27)]
        blade_strip("HX_RotorTail", "blade", c, radial, le, TAIL_N, 0.35, 3.05, body, 0.1)
        blade_strip("HX_RotorTail", "cream", c, radial, le, TAIL_N, 3.05, 3.6, tip, 0.1)

# ------------------------------------------------------------------ markers + reference figure (not exported)
def markers():
    box("K_Scale7", "k_cube", (0, 60, 0), (10, 10, 10), bev=0)
    box("K_Marker7", "k_mark", (20, 56, 0), (10, 2, 2), bev=0)       # long arm +X
    box("K_Marker7", "k_mark", (16, 60, 0), (2, 6, 2), bev=0)        # upright +Y
    box("K_Marker7", "k_mark", (16, 56, 3), (2, 2, 4), bev=0)        # short arm +Z

def ref_figure(c, face):
    """5.2-stud R15-ish block figure for scale in the previews (collection REF, never exported). c = feet centre."""
    c = Vector(c)
    box("REF_R15", "k_cube", c + Vector((0, 1.0, 0)), (1.6, 2.0, 1.0), bev=0.05)      # legs
    box("REF_R15", "k_cube", c + Vector((0, 3.0, 0)), (2.0, 2.0, 1.0), bev=0.05)      # torso
    box("REF_R15", "k_cube", c + Vector((0, 4.6, 0)), (1.2, 1.2, 1.2), bev=0.15)      # head

# ------------------------------------------------------------------ finalize
def collection(name):
    c = bpy.data.collections.get(name)
    if not c:
        c = bpy.data.collections.new(name); bpy.context.scene.collection.children.link(c)
    return c

def finalize():
    stats = []
    for (piece, mat), bm in ACC.items():
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
        bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
        bm.transform(S2B)
        uvl = bm.loops.layers.uv.verify()
        for f in bm.faces:
            n = f.normal; ax = max(range(3), key=lambda i: abs(n[i]))
            for l in f.loops:
                c = l.vert.co
                if ax == 0: l[uvl].uv = (c.y / UV_STUDS * (1 if n.x > 0 else -1), c.z / UV_STUDS)
                elif ax == 1: l[uvl].uv = (c.x / UV_STUDS * (-1 if n.y > 0 else 1), c.z / UV_STUDS)
                else: l[uvl].uv = (c.x / UV_STUDS, c.y / UV_STUDS)
        for f in bm.faces:
            f.smooth = True
        name = piece if piece.startswith(("K_", "REF_")) else f"{piece}__{mat}"
        me = bpy.data.meshes.new(name)
        bm.to_mesh(me); bm.free()
        vs = [v.co for v in me.vertices]
        mn = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
        mx = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
        c = (mn + mx) / 2
        me.transform(Matrix.Translation(-c))
        ob = bpy.data.objects.new(name, me); ob.location = c
        coll = "REF" if piece.startswith("REF_") else ("Markers" if piece.startswith("K_") else "Heli")
        collection(coll).objects.link(ob)
        me.materials.append(make_material(mat))
        if not piece.startswith(("K_", "REF_")) and not MATS[mat][3] and mat not in ("glass", "glass_back", "cabin"):
            wn = ob.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL"); wn.mode = "FACE_AREA"; wn.keep_sharp = True
            wn.weight = 50
            try:
                me.set_sharp_from_angle(angle=math.radians(40))
            except Exception:
                pass
        if piece.startswith("REF_"):
            ob.hide_render = False
        tris = sum(len(p.vertices) - 2 for p in me.polygons)
        sz = mx - mn
        studio = MATS[mat]
        stats.append(dict(name=name, piece=piece, material=mat, rgb=list(studio[0]), studio_material=studio[4],
                          collide=studio[5][0], query=studio[5][1], fidelity=studio[5][2], cast_shadow=studio[5][3],
                          transparency=studio[5][4], reflectance=studio[5][5],
                          rotor={"HX_RotorMain": "Main", "HX_RotorTail": "Tail"}.get(piece, ""),
                          tris=tris, size_studio=[round(sz.x, 3), round(sz.z, 3), round(sz.y, 3)],
                          center_studio=[round(-c.x, 3), round(c.z, 3), round(c.y, 3)]))
    ACC.clear()
    return stats

def clear_scene():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for coll in (bpy.data.meshes, bpy.data.materials, bpy.data.cameras, bpy.data.curves):
        for d in list(coll):
            if d.users == 0:
                coll.remove(d)
    for c in list(bpy.data.collections):
        bpy.data.collections.remove(c)

def build():
    clear_scene()
    info = {}
    info["grid"] = fuselage()
    cabin_liner(); glazing(); door_and_rails(); markings(); roof(); tail(); main_gear(); nav_lights()
    main_rotor(); tail_rotor(); markers()
    ref_figure((-0.6, 1.3, 0.4), -1)            # standing at CabinPoint
    ref_figure((-6.2, 0.0, -0.2), -1)           # at HatchPoint (ground under it)
    return finalize(), info

# ------------------------------------------------------------------ previews
def look(cam_ob, pos_s, tgt_s):
    p = S2B @ Vector(pos_s); t = S2B @ Vector(tgt_s)
    cam_ob.location = p
    cam_ob.rotation_euler = (t - p).to_track_quat("-Z", "Y").to_euler()

def previews():
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.view_settings.view_transform = "Standard"
    sh = sc.display.shading
    sh.light = "STUDIO"; sh.color_type = "MATERIAL"; sh.show_shadows = False; sh.show_cavity = True
    sh.cavity_type = "BOTH"; sh.show_backface_culling = True
    sc.render.resolution_x, sc.render.resolution_y = 1400, 900
    world = bpy.data.worlds.get("World") or bpy.data.worlds.new("World"); sc.world = world
    world.color = (0.42, 0.6, 0.78)
    # ground plane (not exported; deleted after)
    gm = bpy.data.meshes.new("PREV_ground")
    bmg = bmesh.new(); bmesh.ops.create_grid(bmg, x_segments=1, y_segments=1, size=40); bmg.to_mesh(gm); bmg.free()
    g = bpy.data.objects.new("PREV_ground", gm); sc.collection.objects.link(g)
    g.location = S2B @ Vector((0, 0.15, 4))
    gmat = bpy.data.materials.new("PREV_ground"); gmat.diffuse_color = (0.05, 0.05, 0.05, 1); gm.materials.append(gmat)
    for ob in bpy.data.objects:
        if ob.name.startswith("K_"):
            ob.hide_render = True
    cam = bpy.data.cameras.new("PrevCam"); co = bpy.data.objects.new("PrevCam", cam); sc.collection.objects.link(co); sc.camera = co
    views = [("bl_34front", (-24, 13, -28), (0, 4.5, 2), 30, False),
             ("bl_side", (-70, 6, 4.5), (0, 6, 4.5), 50, False),
             ("bl_top", (0, 90, 4.5), (0, 0, 4.4), 46, False),
             ("bl_34rear", (26, 12, 40), (0, 6, 6), 32, False),
             ("bl_cutscene", (-13, 9.1, -18), (0, 4.1, 2), 24, False),
             ("bl_front", (0, 5, -70), (0, 6, 0), 50, False)]
    out = []
    for name, p, t, lens, ortho in views:
        cam.lens = lens
        if name == "bl_top":
            co.location = S2B @ Vector(p); co.rotation_euler = (0, 0, math.pi / 2)
            cam.type = "ORTHO"; cam.ortho_scale = 44
        elif name in ("bl_side", "bl_front"):
            cam.type = "ORTHO"; cam.ortho_scale = 40 if name == "bl_side" else 36
            look(co, p, t)
        else:
            cam.type = "PERSP"; look(co, p, t)
        sc.render.filepath = OUT + name + ".png"
        bpy.ops.render.render(write_still=True)
        out.append(name)
    bpy.data.objects.remove(co, do_unlink=True); bpy.data.objects.remove(g, do_unlink=True)
    return out

def eevee_views():
    """Eevee close-ups in a light environment (sun + sky + pale ground) so the glass reflectance and the seals read."""
    sc = bpy.context.scene
    for eng in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT"):
        try:
            sc.render.engine = eng; break
        except Exception:
            pass
    try:
        sc.eevee.use_raytracing = True
    except Exception:
        pass
    try:
        sc.eevee.taa_render_samples = 48
    except Exception:
        pass
    sc.view_settings.view_transform = "AgX"
    sc.render.resolution_x, sc.render.resolution_y = 1400, 900
    world = bpy.data.worlds.get("World") or bpy.data.worlds.new("World"); sc.world = world
    world.use_nodes = True
    nt = world.node_tree; N = nt.nodes; L = nt.links
    for nd in list(N):
        N.remove(nd)
    out = N.new("ShaderNodeOutputWorld"); bg = N.new("ShaderNodeBackground")
    grad = N.new("ShaderNodeTexGradient"); ramp = N.new("ShaderNodeValToRGB"); tc = N.new("ShaderNodeTexCoord")
    mp = N.new("ShaderNodeMapping"); mp.inputs["Rotation"].default_value = (0, -math.pi / 2, 0)
    ramp.color_ramp.elements[0].color = (0.75, 0.78, 0.8, 1); ramp.color_ramp.elements[1].color = (0.25, 0.45, 0.85, 1)
    ramp.color_ramp.elements[0].position = 0.45
    L.new(tc.outputs["Generated"], mp.inputs["Vector"]); L.new(mp.outputs["Vector"], grad.inputs["Vector"])
    L.new(grad.outputs["Fac"], ramp.inputs["Fac"])
    bg.inputs["Color"].default_value = (0.42, 0.6, 0.88, 1)   # plain light sky (the gradient rig was unused)
    bg.inputs["Strength"].default_value = 1.0
    L.new(bg.outputs["Background"], out.inputs["Surface"])
    sun_d = bpy.data.lights.new("PREV_sun", "SUN"); sun_d.energy = 3.5; sun_d.angle = math.radians(2)
    sun = bpy.data.objects.new("PREV_sun", sun_d); sc.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(140))
    gm = bpy.data.meshes.new("PREV_ground2")
    bmg = bmesh.new(); bmesh.ops.create_grid(bmg, x_segments=1, y_segments=1, size=60); bmg.to_mesh(gm); bmg.free()
    g = bpy.data.objects.new("PREV_ground2", gm); sc.collection.objects.link(g)
    g.location = S2B @ Vector((0, 0.15, 4))
    gmat = bpy.data.materials.new("PREV_ground2"); gmat.use_nodes = True
    gmat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.09, 0.09, 0.09, 1)
    gmat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.6
    gm.materials.append(gmat)
    for ob in bpy.data.objects:
        if ob.name.startswith(("K_", "REF_")):
            ob.hide_render = True
    cam = bpy.data.cameras.new("EvCam"); co = bpy.data.objects.new("EvCam", cam); sc.collection.objects.link(co); sc.camera = co
    views = [("ev_cockpit", (-9.5, 7.2, -19.5), (-1.0, 5.0, -9.6), 38),
             ("ev_cockpit_match", (-10, 7.1, -21), (-2.5, 4.6, -9), 16.5),   # same camera as out/heli/old_cockpit.jpg (Studio FOV 70)
             ("ev_cabin_stbd", (13.5, 5.6, -4.5), (3.6, 4.9, -2.0), 30),
             ("ev_door_port", (-14.0, 5.4, 1.0), (-3.6, 4.6, 3.0), 30),
             ("ev_34front", (-24, 13, -28), (0, 4.5, 2), 30)]
    done = []
    for name, p, t, lens in views:
        cam.type = "PERSP"; cam.lens = lens; look(co, p, t)
        sc.render.filepath = OUT + name + ".png"
        bpy.ops.render.render(write_still=True)
        done.append(name)
    for ob in (co, sun, g):
        bpy.data.objects.remove(ob, do_unlink=True)
    for ob in bpy.data.objects:
        if ob.name.startswith("REF_"):
            ob.hide_render = False
    return done

if __name__ == "__main__" or True:
    STATS, INFO = build()
    kitstats = [s for s in STATS if not s["piece"].startswith(("K_", "REF_"))]
    total = sum(s["tris"] for s in kitstats)
    man = {
        "_note": "Exfil helicopter kit (UH-60 class), 2026-10-16. Studio coordinates RELATIVE TO THE HELI PIVOT world (133, -0.1, 0), "
                 "axes world-aligned (nose -Z, starboard +X). center_studio = mesh bounding-box centre in that frame. Import 3D "
                 "(Creator = Gunsy Funsy group, Insert Using Scene Position, Anchored); fix/place_heli.lua measures the import scale "
                 "from K_Scale7 (10-stud cube at (0, 60, 0)) and the turn from K_Marker7 (long arm +X, upright +Y, short arm +Z).",
        "pivot_world": [133, -0.1, 0],
        "hooks": {"Mast": [133, -0.1, 0], "TailHub_local": list(TAIL_HUB), "TailHub_world": [133 + TAIL_HUB.x, TAIL_HUB.y - 0.1, TAIL_HUB.z],
                  "TailAxis": [-TAIL_N.x, -TAIL_N.y, -TAIL_N.z], "rotor_plane_y_world": HUB_Y - 0.1, "main_rotor_radius": R_MAIN,
                  "tail_rotor_radius": 3.6, "door_local": {"z": [DOOR_Z0, DOOR_Z1], "y": [DOOR_Y0, DOOR_Y1], "x": -3.6},
                  "cabin_liner_local": {"x": [-LIN_X, LIN_X], "y": [LIN_Y0, LIN_Y1], "z": [LIN_Z0, LIN_Z1]},
                  "CabinPoint_world": [132.4, 4.2, 0.4], "HatchPoint_world": [126.8, 3, -0.2]},
        "K_Scale7_center": [0, 60, 0], "K_Scale7_size": 10,
        "tris_total": total, "meshes": STATS,
        "pieces": {}}
    for s in kitstats:
        p = man["pieces"].setdefault(s["piece"], {"tris": 0, "meshes": []})
        p["tris"] += s["tris"]; p["meshes"].append(s["name"])
    # collision-check proxies: every static kit mesh sliced along z into <= 1-stud AABBs (studio frame, relative to the pivot)
    prox = []
    for ob in bpy.data.objects:
        if ob.type != "MESH" or ob.name.startswith(("K_", "REF_", "PREV_", "HX_Rotor")):
            continue
        vs = [S2B.inverted() @ (ob.location + v.co) for v in ob.data.vertices]
        z0 = min(v.z for v in vs); z1 = max(v.z for v in vs)
        n = max(1, int(math.ceil((z1 - z0) / 1.0)))
        for i in range(n):
            a0, a1 = z0 + (z1 - z0) * i / n, z0 + (z1 - z0) * (i + 1) / n
            sl = [v for v in vs if a0 - 0.05 <= v.z <= a1 + 0.05]
            if len(sl) < 2:
                continue
            mn = Vector((min(v.x for v in sl), min(v.y for v in sl), max(a0, min(v.z for v in sl))))
            mx = Vector((max(v.x for v in sl), max(v.y for v in sl), min(a1, max(v.z for v in sl))))
            c = (mn + mx) / 2; sz = mx - mn
            prox.append([round(c.x, 3), round(c.y, 3), round(c.z, 3), round(max(sz.x, 0.05), 3), round(max(sz.y, 0.05), 3),
                         round(max(sz.z, 0.05), 3), ob.name])
    man["proxies"] = prox
    with open(KIT + "heli_manifest.json", "w") as f:
        json.dump(man, f, indent=1)
    # export: kit meshes + markers (REF figures excluded)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in bpy.data.objects:
        if ob.type == "MESH" and not ob.name.startswith("REF_"):
            ob.select_set(True)
    bpy.ops.export_scene.fbx(filepath=KIT + "heli.fbx", use_selection=True, object_types={"MESH"}, use_mesh_modifiers=True,
                             mesh_smooth_type="FACE", apply_unit_scale=True, global_scale=1.0, axis_forward="-Z", axis_up="Y",
                             add_leaf_bones=False, path_mode="STRIP", bake_anim=False)
    bpy.ops.object.select_all(action="DESELECT")
    bpy.ops.wm.save_as_mainfile(filepath=KIT + "heli.blend")
    try:
        pv = previews() + eevee_views()
        bpy.ops.wm.save_mainfile()
    except Exception as ex:
        import traceback; traceback.print_exc(); pv = "preview failed: %s" % ex
    print("HELI_DONE", json.dumps({"tris_total": total, "meshes": len(kitstats),
                                   "per_mesh": {s["name"]: s["tris"] for s in kitstats}, "grid": INFO["grid"], "previews": pv}))

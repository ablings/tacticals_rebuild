"""gunkit: scripted low-poly gun builder (RIVALS weapon method: flat shading, hard edges, profile extrusions, 8-sided
cylinders, inset slots by boolean, one mesh per colour per moving part) with more moving parts, each its own mesh with its
pivot on its real hinge / slide axis. Runs INSIDE Blender (headless): see build_gun.py.

Authoring frame (per gun): the Codex side-view reference with a stud grid (tools/ref_grid.py):
  f = studs from the rear of the silhouette toward the muzzle, z = studs up from its bottom, x = across (+x = gun's right).
Each spec gives ORIGIN = (f, z) of the grip centre; it becomes the Handle (Roblox Tool grip, Tool.Grip identity).
Blender frame after build: X right, +Y toward the muzzle, Z up  (Roblox: x, y = z, z = -f; muzzle along Roblox -Z).
"""
import bpy, bmesh, math, json, os, sys
from mathutils import Vector, Matrix

sys.dont_write_bytecode = True
KIT = os.path.expanduser(r"~\Documents\roblox_kits\tools\checks\blender_check.py")
_g = {"__name__": "blender_check_lib"}
exec(open(KIT).read(), _g)
resolve_coplanar = _g["resolve_coplanar"]

# ---------------------------------------------------------------- palette (SmoothPlastic colours, sRGB 0-255)
PALETTE = {
    "Polymer":   (28, 29, 31),
    "Gunmetal":  (54, 57, 62),
    "Steel":     (110, 112, 118),
    "DarkSteel": (20, 21, 23),
    "Olive":     (107, 122, 58),
    "OliveLt":   (138, 156, 74),
    "Tan":       (150, 128, 96),
    "Cream":     (200, 196, 186),
    "Wood":      (92, 58, 35),
    "Rubber":    (36, 36, 38),
    "Lens":      (40, 70, 90),
    "Brass":     (168, 144, 96),
    "Bore":      (8, 8, 9),
    "Sage":      (167, 173, 152),
    "Glow":      (190, 214, 120),
    "Ash":       (200, 168, 120),
    "Red":       (150, 40, 36),
}


def lin(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def material(key):
    name = "GUN_" + key
    m = bpy.data.materials.get(name)
    if not m:
        m = bpy.data.materials.new(name)
        r, g, b = PALETTE[key]
        m.diffuse_color = (lin(r), lin(g), lin(b), 1)
        m.use_nodes = True
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        if bsdf:
            bsdf.inputs["Base Color"].default_value = (lin(r), lin(g), lin(b), 1)
            bsdf.inputs["Roughness"].default_value = 0.6
            if key == "Lens":
                bsdf.inputs["Roughness"].default_value = 0.1
    return m


# ---------------------------------------------------------------- primitives (image frame f, z, x)
class Solid:
    def __init__(self, kind, cut=None, **kw):
        self.kind, self.kw, self.cut = kind, kw, cut or []


def P(pts, w, x=0.0, cut=None):
    """side-profile prism: pts [(f, z)...] extruded across x (width w centred on x)"""
    return Solid("prism", cut, pts=pts, plane="fz", a0=x - w / 2, a1=x + w / 2)


def PT(pts, z0, z1, cut=None):
    """top-view prism: pts [(x, f)...] extruded up from z0 to z1"""
    return Solid("prism", cut, pts=pts, plane="xf", a0=z0, a1=z1)


def PF(pts, f0, f1, cut=None):
    """front-view prism: pts [(x, z)...] extruded along f from f0 to f1"""
    return Solid("prism", cut, pts=pts, plane="xz", a0=f0, a1=f1)


def B(f0, f1, z0, z1, w, x=0.0, cut=None):
    return P([(f0, z0), (f1, z0), (f1, z1), (f0, z1)], w, x, cut)


def C(f0, f1, zc, r, x=0.0, seg=8, r1=None, cut=None, rot=None):
    """cylinder along f (barrels, tubes); r1 = radius at f1 (taper); rot=0 puts a vertex on top (no flat face
    parallel to a box face: use it for parts buried inside others, like rounds)"""
    return Solid("cyl", cut, a=Vector((x, f0, zc)), b=Vector((x, f1, zc)), r=r, r1=r if r1 is None else r1, seg=seg, rot=rot)


def CX(fc, zc, r, x0, x1, seg=8, cut=None, rot=0.0):
    """cylinder across x (pins, knobs sticking out sideways); rot=0: no face parallel to the frame's faces"""
    return Solid("cyl", cut, a=Vector((x0, fc, zc)), b=Vector((x1, fc, zc)), r=r, r1=r, seg=seg, rot=rot)


def CZ(fc, z0, z1, r, x=0.0, seg=8, r1=None, cut=None, rot=None):
    """vertical cylinder (knobs, turrets)"""
    return Solid("cyl", cut, a=Vector((x, fc, z0)), b=Vector((x, fc, z1)), r=r, r1=r if r1 is None else r1, seg=seg, rot=rot)


def CA(p0, p1, r, seg=8, r1=None, cut=None, rot=None):
    """cylinder between two (x, f, z) points (angled rods: bipod legs, wire stocks)"""
    return Solid("cyl", cut, a=Vector(p0), b=Vector(p1), r=r, r1=r if r1 is None else r1, seg=seg, rot=rot)


def L(fs, rs, zc, x=0.0, seg=8, rot=None):
    """lathe along f: stations fs with radii rs (a radius of 0 closes to a point); caps at open ends"""
    return Solid("lathe", None, fs=fs, rs=rs, zc=zc, x=x, seg=seg, rot=rot)


def LZ(zs, rs, fc=0.0, x=0.0, seg=12, rot=None, cut=None):
    """vertical lathe (grenade bodies, mines, cans): stations zs with radii rs around the axis at (x, fc)"""
    return Solid("lathe", cut, fs=zs, rs=rs, zc=fc, x=x, seg=seg, rot=rot, axis="z")


def T(f0, f1, zc, ro, ri, x=0.0, seg=8, rot=None):
    """closed tube along f (muzzle, suppressor bore)"""
    return Solid("tube", None, a=Vector((x, f0, zc)), b=Vector((x, f1, zc)), ro=ro, ri=ri, seg=seg, rot=rot)


def S(fc, zc, r, x=0.0, seg=8, rings=4):
    return Solid("sphere", None, c=Vector((x, fc, zc)), r=r, seg=seg, rings=rings)


# ---------------------------------------------------------------- geometry
def _to3(plane, u, v, a):
    if plane == "fz":
        return Vector((a, u, v))
    if plane == "xf":
        return Vector((u, v, a))
    return Vector((u, a, v))  # xz


def _area(pts):
    return sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1] for i in range(len(pts))) / 2


def add_prism(bm, pts, plane, a0, a1):
    pts = list(pts)
    # (f,z) CCW -> +x ; (x,f) CCW -> +z ; (x,z) CCW -> -f (x cross z = -f): flip that plane
    ccw = _area(pts) > 0
    want = plane != "xz"
    if ccw != want:
        pts.reverse()
    lo = [bm.verts.new(_to3(plane, u, v, a0)) for u, v in pts]
    hi = [bm.verts.new(_to3(plane, u, v, a1)) for u, v in pts]
    n = len(pts)
    bm.faces.new(hi)
    bm.faces.new(list(reversed(lo)))
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((lo[i], lo[j], hi[j], hi[i]))


def _frame(a, b):
    ax = (b - a).normalized()
    ref = Vector((0, 0, 1)) if abs(ax.z) < 0.9 else Vector((1, 0, 0))
    u = ax.cross(ref).normalized()
    v = ax.cross(u).normalized()
    return ax, u, v


def _ring(a, u, v, r, seg, rot):
    return [a + (u * math.cos(rot + 2 * math.pi * i / seg) + v * math.sin(rot + 2 * math.pi * i / seg)) * r for i in range(seg)]


def add_cyl(bm, a, b, r, r1, seg, rot=None):
    ax, u, v = _frame(a, b)
    rot = math.pi / seg if rot is None else rot
    ra = [bm.verts.new(p) for p in _ring(a, u, v, r, seg, rot)]
    rb = [bm.verts.new(p) for p in _ring(b, u, v, r1, seg, rot)]
    f = bm.faces.new(rb)
    if f.normal.dot(ax) < 0 if False else False:
        pass
    bm.faces.new(list(reversed(ra)))
    for i in range(seg):
        j = (i + 1) % seg
        bm.faces.new((ra[i], ra[j], rb[j], rb[i]))
    _orient_outward(bm, ra + rb, (a + b) / 2)


def add_lathe(bm, fs, rs, zc, x, seg, rot, axis="f"):
    rot = math.pi / seg if rot is None else rot

    def P3(a, r, i):
        c, s_ = r * math.cos(rot + 2 * math.pi * i / seg), r * math.sin(rot + 2 * math.pi * i / seg)
        return (x + c, a, zc + s_) if axis == "f" else (x + c, zc + s_, a)
    rings = []
    for f, r in zip(fs, rs):
        if r <= 1e-6:
            rings.append([bm.verts.new((x, f, zc) if axis == "f" else (x, zc, f))])
        else:
            rings.append([bm.verts.new(P3(f, r, i)) for i in range(seg)])
    for ra, rb in zip(rings, rings[1:]):
        if len(ra) == 1 and len(rb) == 1:
            continue
        for i in range(seg):
            j = (i + 1) % seg
            if len(ra) == 1:
                bm.faces.new((ra[0], rb[i], rb[j]))
            elif len(rb) == 1:
                bm.faces.new((ra[i], rb[0], ra[j]))
            else:
                bm.faces.new((ra[i], rb[i], rb[j], ra[j]))
    if len(rings[0]) > 1:
        bm.faces.new(list(rings[0]))
    if len(rings[-1]) > 1:
        bm.faces.new(list(reversed(rings[-1])))
    bm.normal_update()
    vol = 0.0
    for f in bm.faces:
        vs = [l.vert.co for l in f.loops]
        for i in range(1, len(vs) - 1):
            vol += vs[0].dot(vs[i].cross(vs[i + 1])) / 6.0
    if vol < 0:
        for f in bm.faces:
            f.normal_flip()


def add_tube(bm, a, b, ro, ri, seg, rot=None):
    ax, u, v = _frame(a, b)
    rot = math.pi / seg if rot is None else rot
    oa = [bm.verts.new(p) for p in _ring(a, u, v, ro, seg, rot)]
    ob = [bm.verts.new(p) for p in _ring(b, u, v, ro, seg, rot)]
    ia = [bm.verts.new(p) for p in _ring(a, u, v, ri, seg, rot)]
    ib = [bm.verts.new(p) for p in _ring(b, u, v, ri, seg, rot)]
    for i in range(seg):
        j = (i + 1) % seg
        bm.faces.new((oa[i], oa[j], ob[j], ob[i]))      # outer
        bm.faces.new((ib[i], ib[j], ia[j], ia[i]))      # inner (faces inward to the axis)
        bm.faces.new((ob[i], ob[j], ib[j], ib[i]))      # cap at b
        bm.faces.new((ia[i], ia[j], oa[j], oa[i]))      # cap at a
    # orientation check on the outer wall
    f = bm.faces[-4] if False else None


def add_sphere(bm, c, r, seg, rings):
    ret = bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=r)
    for v in ret["verts"]:
        v.co += c


def _orient_outward(bm, verts, centre):
    faces = {f for v in verts for f in v.link_faces}
    bm.normal_update()
    for f in faces:
        if f.normal.dot(f.calc_center_median() - centre) < 0:
            f.normal_flip()


def solid_bmesh(s):
    bm = bmesh.new()
    k = s.kind
    if k == "prism":
        add_prism(bm, s.kw["pts"], s.kw["plane"], s.kw["a0"], s.kw["a1"])
    elif k == "cyl":
        add_cyl(bm, s.kw["a"], s.kw["b"], s.kw["r"], s.kw["r1"], s.kw["seg"], s.kw.get("rot"))
    elif k == "lathe":
        add_lathe(bm, s.kw["fs"], s.kw["rs"], s.kw["zc"], s.kw["x"], s.kw["seg"], s.kw["rot"], s.kw.get("axis", "f"))
    elif k == "tube":
        add_tube(bm, s.kw["a"], s.kw["b"], s.kw["ro"], s.kw["ri"], s.kw["seg"], s.kw.get("rot"))
    elif k == "sphere":
        add_sphere(bm, s.kw["c"], s.kw["r"], s.kw["seg"], s.kw["rings"])
    bm.normal_update()
    if k == "tube":
        # make every face point away from the tube wall's middle radius
        a, b, ro, ri = s.kw["a"], s.kw["b"], s.kw["ro"], s.kw["ri"]
        ax = (b - a).normalized()
        for f in bm.faces:
            c = f.calc_center_median()
            t = (c - a).dot(ax)
            radial = (c - a) - ax * t
            mid = a + ax * t + (radial.normalized() * (ro + ri) / 2 if radial.length > 1e-6 else Vector())
            if f.normal.dot(c - mid) < 0 and abs(f.normal.dot(ax)) < 0.5:
                f.normal_flip()
            elif abs(f.normal.dot(ax)) >= 0.5:
                want = 1 if t > (b - a).length / 2 else -1
                if f.normal.dot(ax) * want < 0:
                    f.normal_flip()
    return bm


def bm_to_obj(bm, name):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o


def solid_with_cuts(s):
    """returns a bmesh of the solid with its cutters subtracted (Blender exact boolean, applied)"""
    bm = solid_bmesh(s)
    if not s.cut:
        return bm
    o = bm_to_obj(bm, "_tmp_solid")
    bm.free()
    cutters = []
    for c in s.cut:
        cb = solid_with_cuts(c)
        co = bm_to_obj(cb, "_tmp_cut")
        cb.free()
        co.hide_render = True
        cutters.append(co)
        m = o.modifiers.new("cut", "BOOLEAN")
        m.operation = "DIFFERENCE"
        m.solver = "EXACT"
        m.object = co
    dg = bpy.context.evaluated_depsgraph_get()
    ev = o.evaluated_get(dg)
    me = bpy.data.meshes.new_from_object(ev)
    out = bmesh.new()
    out.from_mesh(me)
    bpy.data.meshes.remove(me)
    for ob in cutters + [o]:
        me_ = ob.data
        bpy.data.objects.remove(ob, do_unlink=True)
        bpy.data.meshes.remove(me_)
    return out


# ---------------------------------------------------------------- gun assembly
class Part:
    def __init__(self, name, mat, solids, parent="Handle", pivot=None, wrap="B", motion="static", note="", open_shell=False, explode=(0, 0, 0), visible=True):
        self.explode = explode
        self.visible = visible
        self.name, self.mat, self.solids, self.parent = name, mat, solids, parent
        self.pivot, self.wrap, self.motion, self.note, self.open_shell = pivot, wrap, motion, note, open_shell


_SCALE = [1.0]


def build_part(part, origin, collection):
    of, oz = origin
    k = _SCALE[0]
    bm = bmesh.new()
    for s in part.solids:
        sb = solid_with_cuts(s)
        me = bpy.data.meshes.new("_tmp_join")
        sb.to_mesh(me)
        sb.free()
        bm.from_mesh(me)
        bpy.data.meshes.remove(me)
    # image frame -> gun frame (grip centre at 0): Blender X = x, Y = f - of, Z = z - oz
    bmesh.ops.translate(bm, verts=bm.verts, vec=Vector((0, -of, -oz)))
    if k != 1.0:
        bmesh.ops.scale(bm, vec=Vector((k, k, k)), verts=bm.verts)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.normal_update()
    resolve_coplanar(bm)
    bm.normal_update()
    bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="BEAUTY", ngon_method="BEAUTY")
    bmesh.ops.dissolve_degenerate(bm, edges=bm.edges[:], dist=1e-6)
    pv = part.pivot
    if pv is None:
        lo = Vector((min(v.co[i] for v in bm.verts) for i in range(3)))
        hi = Vector((max(v.co[i] for v in bm.verts) for i in range(3)))
        pivot = (lo + hi) / 2
    else:
        f, z = pv[0], pv[1]
        x = pv[2] if len(pv) > 2 else 0.0
        pivot = Vector((x, f - of, z - oz)) * k
    bmesh.ops.translate(bm, verts=bm.verts, vec=-pivot)
    me = bpy.data.meshes.new(part.name)
    bm.to_mesh(me)
    tris = len(bm.faces)
    bm.free()
    for p in me.polygons:
        p.use_smooth = False
    me.materials.append(material(part.mat))
    o = bpy.data.objects.new(part.name, me)
    o.location = pivot
    collection.objects.link(o)
    r, g, b = PALETTE[part.mat]
    o.color = (lin(r), lin(g), lin(b), 1)
    o["wrap"] = part.wrap
    o["motion"] = part.motion
    o["gun_parent"] = part.parent
    o["colour_rgb"] = list(PALETTE[part.mat])
    o["mat_key"] = part.mat
    if part.open_shell:
        o["open_shell"] = True
    return o, tris


def r2(v):
    return [round(float(c), 4) for c in v]


def blender_to_roblox(v):
    """Blender gun frame (X right, Y muzzle, Z up) -> Roblox (x, y up, z back)"""
    return [round(v[0], 4), round(v[2], 4), round(-v[1], 4)]


def build_gun(spec, out_blend, out_fbx, manifest_path, render_dir, rig_blend=None):
    """spec: module-like with NAME, ORIGIN, PARTS (list of Part), ATTACH {name: (part, (f, z, x))}, SIZE_NOTE"""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.unit_settings.system = "METRIC"
    sc.unit_settings.scale_length = 1.0
    _SCALE[0] = getattr(spec, "SCALE", 1.0)
    gcol = bpy.data.collections.new("Gun_" + spec.NAME)
    sc.collection.children.link(gcol)
    objs, tris = {}, {}
    for p in spec.PARTS:
        o, t = build_part(p, spec.ORIGIN, gcol)
        objs[p.name], tris[p.name] = o, t
    of, oz = spec.ORIGIN

    # armature: Handle root bone at the grip, one bone per moving part at its pivot
    arm_data = bpy.data.armatures.new("GunRig_" + spec.NAME)
    arm = bpy.data.objects.new("GunRig_" + spec.NAME, arm_data)
    gcol.objects.link(arm)
    arm.show_in_front = True
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_data.edit_bones
    hb = eb.new("Handle")
    hb.head, hb.tail = Vector((0, 0, 0)), Vector((0, 0, 0.15))
    movers = [p for p in spec.PARTS if p.motion != "static"]
    for p in movers:
        b = eb.new(p.name)
        b.head = objs[p.name].location.copy()
        b.tail = b.head + Vector((0, 0, 0.08))
    for p in movers:
        par = p.parent if p.parent in eb else "Handle"
        if par != p.name:
            eb[p.name].parent = eb[par]
    bpy.ops.object.mode_set(mode="OBJECT")

    def bone_of(p):
        if p.motion != "static":
            return p.name
        par = p.parent
        while par != "Handle":
            pp = next((q for q in spec.PARTS if q.name == par), None)
            if pp is None:
                break
            if pp.motion != "static":
                return pp.name
            par = pp.parent
        return "Handle"

    for p in spec.PARTS:
        o = objs[p.name]
        mw = o.matrix_world.copy()
        o.parent = arm
        o.parent_type = "BONE"
        o.parent_bone = bone_of(p)
        bpy.context.view_layer.update()
        o.matrix_world = mw

    # attachment empties
    att = {}
    for an, (pn, pos) in spec.ATTACH.items():
        e = bpy.data.objects.new(an, None)
        e.empty_display_type = "ARROWS"
        e.empty_display_size = 0.08
        f, z = pos[0], pos[1]
        x = pos[2] if len(pos) > 2 else 0.0
        e.location = Vector((x, f - of, z - oz)) * _SCALE[0]
        gcol.objects.link(e)
        att[an] = (pn, e.location.copy())
        tgt = objs.get(pn)
        mw = e.matrix_world.copy()
        e.parent = arm
        e.parent_type = "BONE"
        e.parent_bone = bone_of(next(p for p in spec.PARTS if p.name == pn)) if pn in objs else "Handle"
        bpy.context.view_layer.update()
        e.matrix_world = mw

    # manifest
    bpy.context.view_layer.update()
    man = {"gun": spec.NAME, "frame": "Roblox studs, Handle space: x right, y up, z back (muzzle toward -z); Tool.Grip = identity",
           "handle": {"size": [0.2, 0.6, 0.3], "note": "invisible root Part at the grip centre; every mesh hangs off it by Motor6D"},
           "parts": [], "attachments": {}, "total_tris": sum(tris.values())}
    for p in spec.PARTS:
        o = objs[p.name]
        ws = [o.matrix_world @ v.co for v in o.data.vertices]
        lo = Vector((min(v[i] for v in ws) for i in range(3)))
        hi = Vector((max(v[i] for v in ws) for i in range(3)))
        c, s = (lo + hi) / 2, hi - lo
        piv = o.matrix_world.translation
        man["parts"].append({
            "name": p.name, "parent": p.parent, "motor6d": p.name, "motor_part0": p.parent, "motion": p.motion,
            "pivot": blender_to_roblox(piv), "bbox_centre": blender_to_roblox(c), "size": [round(s[0], 4), round(s[2], 4), round(s[1], 4)],
            "tris": tris[p.name], "colour": list(PALETTE[p.mat]), "material": {"Lens": "Glass", "Glow": "Neon"}.get(p.mat, "SmoothPlastic"),
            "visible_at_rest": getattr(p, "visible", True),
            "wrap": p.wrap, "note": p.note})
    for an, (pn, loc) in att.items():
        man["attachments"][an] = {"part": pn, "position_handle_space": blender_to_roblox(loc)}
    lo = Vector((min(min((o.matrix_world @ v.co)[i] for v in o.data.vertices) for o in objs.values()) for i in range(3)))
    hi = Vector((max(max((o.matrix_world @ v.co)[i] for v in o.data.vertices) for o in objs.values()) for i in range(3)))
    man["overall_size_LxHxW"] = [round(hi[1] - lo[1], 3), round(hi[2] - lo[2], 3), round(hi[0] - lo[0], 3)]
    os.makedirs(os.path.dirname(manifest_path), exist_ok=True)
    json.dump(man, open(manifest_path, "w"), indent=1)

    # attach to the Starter Blocky rig's right hand (appended copy; the source file is only read)
    if rig_blend and os.path.exists(rig_blend):
        rcol = bpy.data.collections.new("StarterRig_ref")
        sc.collection.children.link(rcol)
        with bpy.data.libraries.load(rig_blend, link=False) as (src, dst):
            dst.objects = [n for n in src.objects if n in ("Blocky Rig", "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg")]
        rig = None
        for ob in dst.objects:
            if ob is None:
                continue
            rcol.objects.link(ob)
            if ob.type == "ARMATURE":
                rig = ob
        if rig:
            grip = bpy.data.objects.new("RightGripAttachment", None)
            grip.empty_display_type = "ARROWS"
            grip.empty_display_size = 0.3
            rcol.objects.link(grip)
            # R6 RightGripAttachment: 1 stud below the arm centre (arm bottom), rotated -90 deg about X:
            # gun muzzle (+Y) points down the arm, gun top (+Z) points forward (+Y = the character's front)
            grip.parent = rig
            grip.parent_type = "BONE"
            grip.parent_bone = "Hand.R"
            bpy.context.view_layer.update()
            grip.matrix_world = Matrix.Translation((1.5, 0, 2.0)) @ Matrix.Rotation(math.radians(-90), 4, "X")
            arm.parent = grip
            arm.matrix_parent_inverse = Matrix.Identity(4)
            arm.matrix_basis = Matrix.Identity(4)
            # parts that ride another rig bone (the left fist wrap on Hand.L): their meshes are bone-parented to that rig bone
            bpy.context.view_layer.update()
            for bn, tgt in getattr(spec, "FOLLOW", {}).items():
                fam = {bn} | {p.name for p in spec.PARTS if p.parent == bn}
                for p in spec.PARTS:
                    if p.name in fam and tgt in rig.data.bones:
                        o = objs[p.name]
                        mw = o.matrix_world.copy()
                        o.parent = rig
                        o.parent_type = "BONE"
                        o.parent_bone = tgt
                        bpy.context.view_layer.update()
                        o.matrix_world = mw
            man["follow"] = getattr(spec, "FOLLOW", {})
            man["rig_attach"] = {"rig": "Starter_Blocky_Rig (appended copy)", "bone": "Hand.R", "empty": "RightGripAttachment",
                                 "grip_world": [1.5, 0, 2.0], "rotation": "-90 deg about X (Roblox RightGripAttachment)"}
            json.dump(man, open(manifest_path, "w"), indent=1)
    os.makedirs(os.path.dirname(out_blend), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=out_blend)

    # FBX of the gun alone (rig at origin): armature + bone-parented meshes + attachment empties
    saved_parent = arm.parent
    mw = arm.matrix_world.copy()
    arm.parent = None
    arm.matrix_world = Matrix.Identity(4)
    bpy.context.view_layer.update()
    for o in bpy.context.scene.objects:
        o.select_set(False)
    for o in [ob for ob in bpy.data.objects if gcol.name in [c.name for c in ob.users_collection]]:
        o.select_set(True)
    bpy.ops.export_scene.fbx(filepath=out_fbx, use_selection=True, object_types={"ARMATURE", "MESH", "EMPTY"},
                             apply_unit_scale=True, global_scale=1.0, bake_space_transform=False, add_leaf_bones=False,
                             mesh_smooth_type="FACE", bake_anim=False, axis_forward="-Z", axis_up="Y")
    arm.parent = saved_parent
    arm.matrix_world = mw if saved_parent is None else arm.matrix_world
    if saved_parent is not None:
        arm.matrix_parent_inverse = Matrix.Identity(4)
        arm.matrix_basis = Matrix.Identity(4)
    bpy.ops.wm.save_as_mainfile(filepath=out_blend)
    return objs, man


# ---------------------------------------------------------------- renders
def _setup_render(res=(1600, 700)):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sh = sc.display.shading
    sh.light = "STUDIO"
    sh.color_type = "OBJECT"
    sh.show_cavity = True
    sh.cavity_type = "WORLD"
    sh.show_object_outline = True
    sh.object_outline_color = (0, 0, 0)
    sc.display.shading.background_type = "WORLD"
    if not sc.world:
        sc.world = bpy.data.worlds.new("w")
    sc.world.color = (0.82, 0.82, 0.8)
    sc.render.resolution_x, sc.render.resolution_y = res
    sc.render.film_transparent = False
    sc.view_settings.view_transform = "Standard"


def render_ortho(objs, path, view="right", pad=1.12, res=(1600, 700), offsets=None):
    """flat side render; offsets {obj: Vector} pushes parts out for an exploded view (restored afterwards)"""
    _setup_render(res)
    sc = bpy.context.scene
    saved = {}
    if offsets:
        for o, d in offsets.items():
            saved[o] = o.matrix_world.copy()
            o.matrix_world = Matrix.Translation(d) @ o.matrix_world
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
    lo = Vector((min(p[i] for p in pts) for i in range(3)))
    hi = Vector((max(p[i] for p in pts) for i in range(3)))
    c = (lo + hi) / 2
    cd = bpy.data.cameras.new("rc")
    cd.type = "ORTHO"
    cam = bpy.data.objects.new("rc", cd)
    sc.collection.objects.link(cam)
    sc.camera = cam
    aspect = res[0] / res[1]
    if view == "right":
        cam.location = c + Vector((10, 0, 0))
        cam.rotation_euler = (math.radians(90), 0, math.radians(90))
        w, h = hi.y - lo.y, hi.z - lo.z
    elif view == "left":
        cam.location = c + Vector((-10, 0, 0))
        cam.rotation_euler = (math.radians(90), 0, math.radians(-90))
        w, h = hi.y - lo.y, hi.z - lo.z
    elif view == "front":
        cam.location = c + Vector((0, 10, 0))
        cam.rotation_euler = (math.radians(90), 0, math.radians(180))
        w, h = hi.x - lo.x, hi.z - lo.z
    elif view == "top":
        cam.location = c + Vector((0, 0, 10))
        cam.rotation_euler = (0, 0, math.radians(90))
        w, h = hi.y - lo.y, hi.x - lo.x
    elif view == "persp":
        cd.type = "PERSP"
        d = Vector((1.0, -0.6, 0.55)).normalized()
        cam.location = c + d * (hi - lo).length * 1.6
        cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
        w, h = 1, 1
    cd.ortho_scale = max(w, h * aspect) * pad
    sc.render.filepath = os.path.abspath(path)
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam)
    bpy.data.cameras.remove(cd)
    for o, m in saved.items():
        o.matrix_world = m
    bpy.context.view_layer.update()
    return path

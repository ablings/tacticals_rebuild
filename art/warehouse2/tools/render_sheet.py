"""Render each Warehouse 2 assembly next to a stand-in of the old piece it replaces and a 5-stud human, then tile them
into notes/warehouse2_props_sheet.jpg. Runs inside Blender 4.5 (headless) on the built kit (read-only: never saves):
  blender -b art/warehouse2/warehouse2_props.blend --python art/warehouse2/tools/render_sheet.py -- [--samples 64] [--only W2_FireBarrel]
Old stand-ins are rebuilt from notes/warehouse_study sizes and the colours seen in the old map capture (old meshes are
not downloadable here), so they show size and look, not exact shape.
Writes art/warehouse2/renders/<assembly>.png and the sheet."""
import bpy, bmesh, json, math, os, sys
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))
REPO = os.path.abspath(os.path.join(ROOT, "..", ".."))
REN = os.path.join(ROOT, "renders")
ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SAMPLES = int(ARGV[ARGV.index("--samples") + 1]) if "--samples" in ARGV else 64
ONLY = ARGV[ARGV.index("--only") + 1] if "--only" in ARGV else None
os.makedirs(REN, exist_ok=True)


def srgb(c):
    f = lambda v: (v / 255) / 12.92 if v / 255 <= 0.04045 else ((v / 255 + 0.055) / 1.055) ** 2.4
    return (f(c[0]), f(c[1]), f(c[2]), 1.0)


MATS = {}
def mat(name, col, rough=0.6, metal=0.0):
    if name in MATS:
        return MATS[name]
    m = bpy.data.materials.new("REF_" + name); m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = srgb(col); b.inputs["Roughness"].default_value = rough; b.inputs["Metallic"].default_value = metal
    MATS[name] = m
    return m


STAND = []
def sbox(lo, hi, m, coll):
    lo, hi = Vector(lo), Vector(hi)
    me = bpy.data.meshes.new("Reference_box")
    bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=hi - lo, verts=bm.verts); bmesh.ops.translate(bm, vec=(lo + hi) / 2, verts=bm.verts)
    bm.to_mesh(me); bm.free(); me.materials.append(m)
    o = bpy.data.objects.new("Reference_old", me); coll.objects.link(o); STAND.append(o)
    return o

def scyl(c, r, h, m, coll, segs=24):
    me = bpy.data.meshes.new("Reference_cyl")
    bm = bmesh.new(); bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r, radius2=r, depth=h)
    bmesh.ops.translate(bm, vec=(c[0], c[1], c[2] + h / 2), verts=bm.verts)
    for f in bm.faces: f.smooth = True
    bm.to_mesh(me); bm.free(); me.materials.append(m)
    o = bpy.data.objects.new("Reference_old", me); coll.objects.link(o); STAND.append(o)
    return o


def old_standin(kind, coll):
    """old pieces at the origin, bottom on z=0, front -Y. Sizes from warehouse_dump.json (Studio -> Blender)."""
    dark = mat("dark", (38, 40, 46), 0.5); navy = mat("navy", (26, 28, 36), 0.5)
    if kind == "barrel":
        scyl((0, 0, 0), 1.05, 3.4, mat("oldred", (150, 28, 22), 0.45, 0.3), coll)
        for z in (0.1, 1.0, 2.0, 2.95):
            scyl((0, 0, z), 1.09, 0.12, mat("oldrib", (110, 20, 16), 0.45, 0.3), coll)
        sbox((-0.45, -1.12, 1.3), (0.45, -1.0, 2.0), mat("oldlabel", (220, 180, 40), 0.5), coll)
    elif kind == "low":
        sbox((-3, -1, 0), (3, 1, 3.4), dark, coll)
        for x in (-2.2, 0, 2.2):
            sbox((x - 0.25, -1.06, 0.2), (x + 0.25, -0.98, 0.5), mat("oldyel", (220, 180, 40), 0.5), coll)
    elif kind == "tall":
        pan = mat("oldpanel", (150, 172, 196), 0.4, 0.2); fr = mat("oldframe", (60, 66, 80), 0.4, 0.3)
        for z0 in (0, 3.5):
            sbox((-2.35, -1.85, z0 + 0.15), (2.35, 1.85, z0 + 3.35), pan, coll)
            for (lo, hi) in (((-2.5, -2.0, z0), (-2.15, 2.0, z0 + 3.5)), ((2.15, -2.0, z0), (2.5, 2.0, z0 + 3.5)),
                             ((-2.5, -2.0, z0), (2.5, 2.0, z0 + 0.3)), ((-2.5, -2.0, z0 + 3.2), (2.5, 2.0, z0 + 3.5))):
                sbox(lo, hi, fr, coll)
    elif kind == "wall":
        sbox((-5, -1.5, 0), (5, 1.5, 7), navy, coll)
    elif kind == "propcrate":
        sbox((-1.2, -0.9, 0), (1.2, 0.9, 1.2), mat("oldpanel", (150, 172, 196), 0.4, 0.2), coll)
    elif kind == "door":
        sbox((-8, -0.22, 1.05), (8, 0.22, 10.05), mat("oldshutter", (163, 162, 165), 0.5, 0.3), coll)
        sbox((-8, 0.0, 9.0), (8, 1.0, 14.0), mat("oldwall", (105, 106, 108), 0.8), coll)
        for x in (-9.6, 9.6):
            scyl((x, -1.6, 0), 0.35, 3.4, mat("oldbollard", (205, 212, 228), 0.4, 0.6), coll, 12)
    elif kind == "pallet":
        w = mat("oldwood", (120, 92, 62), 0.8)
        for y in (-1.4, 0, 1.4):
            sbox((-2, y - 0.3, 0), (2, y + 0.3, 0.6), w, coll)
    elif kind == "palletload":
        w = mat("oldwood", (120, 92, 62), 0.8)
        for y in (-1.4, 0, 1.4):
            sbox((-2, y - 0.3, 0), (2, y + 0.3, 0.6), w, coll)
        sbox((-1.3, -1.3, 0.6), (1.3, 1.3, 2.4), mat("oldcard", (150, 110, 70), 0.8), coll)
    elif kind == "cabinet":
        sbox((-1.0, -0.33, 2.85), (1.0, 0.33, 5.85), mat("oldcab", (90, 96, 104), 0.5, 0.3), coll)
    elif kind == "bench":
        sbox((-3, -1.2, 2.5), (3, 1.2, 2.8), dark, coll)
        for x in (-2.8, 2.8):
            sbox((x - 0.15, -1.1, 0), (x + 0.15, 1.1, 2.5), dark, coll)
        sbox((-3, 1.0, 2.8), (3, 1.2, 4.75), dark, coll)
    elif kind == "lamp":
        sbox((-2.0, -0.5, 4.9), (2.0, 0.5, 5.0), mat("oldlight", (235, 240, 255), 0.3), coll)
    else:
        return False
    return True


OLD = {
    "W2_FireBarrel": ("barrel", "FireBarrel (Look 2.1 x 3.4 x 2.1)"),
    "W2_FireBarrel_Burnt": (None, "none (old barrel had no burnt state)"),
    "W2_OilDrum_Olive": (None, "none (new clutter, 3.0 high: not shootable)"), "W2_OilDrum_Black": (None, "none (new clutter, 3.0 high: not shootable)"),
    "W2_Cover_Low": ("low", "Arena_L low cover 6 x 3.4 x 2"),
    "W2_Cover_Tall": ("tall", "Arena_C tall cover 5 x 7 x 4"),
    "W2_Cover_TallPly": ("tall", "Arena_C tall cover 5 x 7 x 4 (variant 2)"),
    "W2_Cover_Wall": ("wall", "Arena_W cover wall 10 x 7 x 3"),
    "W2_SupplyCrate": (None, "none (loose dressing crate)"), "W2_SteelCrate": (None, "none (loose dressing crate)"),
    "W2_LongCrate": (None, "none (loose dressing crate)"),
    "W2_AmmoCan": ("propcrate", "Arena_PropCrate 2.4 x 1.2 x 1.8"),
    "W2_RollDoor_Open": ("door", "old Shutter 16 x 9; new opening is 20 x 14"),
    "W2_RollDoor_HalfOpen": ("door", "old Shutter 16 x 9; new opening is 20 x 14"),
    "W2_Pallet": ("pallet", "Props/Pallet 4 x 0.6 x 3.4"),
    "W2_PalletSacks": ("palletload", "Pallet + Cardboard"),
    "W2_Tyre": (None, "none (new clutter)"), "W2_TyreStack": (None, "none (new clutter)"),
    "W2_ShelfRack": ("cabinet", "Arena_Cabinet 0.65 x 3 x 2"),
    "W2_Workbench": ("bench", "Props/Workbench 6 x 4.75 x 2.4"),
    "W2_HighBayLamp": ("lamp", "flat ceiling light strip"),
    "W2_Forklift": (None, "none (new set dressing)"),
}


CAMDIR = {"W2_Forklift": Vector((1.0, -0.55, 0.42))}   # long along Y: shoot it from the side


def human(coll):
    skin = mat("hskin", (200, 196, 186), 0.6); shirt = mat("hshirt", (107, 122, 58), 0.7); pants = mat("hpants", (60, 62, 60), 0.7)
    parts = [((-0.5, -0.25, 0.0), (-0.04, 0.25, 2.0), pants), ((0.04, -0.25, 0.0), (0.5, 0.25, 2.0), pants),
             ((-0.75, -0.3, 2.0), (0.75, 0.3, 3.8), shirt), ((-1.2, -0.25, 2.1), (-0.78, 0.25, 3.8), shirt),
             ((0.78, -0.25, 2.1), (1.2, 0.25, 3.8), shirt), ((-0.42, -0.4, 3.82), (0.42, 0.4, 5.0), skin)]
    return [sbox(lo, hi, m, coll) for lo, hi, m in parts]


def bbox(objs):
    pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    return (Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts))),
            Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts))))


def setup_scene():
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    try:
        pr = bpy.context.preferences.addons["cycles"].preferences
        pr.compute_device_type = "OPTIX"; pr.get_devices()
        for d in pr.devices: d.use = d.type == "OPTIX"
        sc.cycles.device = "GPU"
    except Exception as ex:
        print("GPU fail", ex)
    sc.cycles.samples = SAMPLES; sc.cycles.use_denoising = True
    sc.render.resolution_x, sc.render.resolution_y = 900, 600
    sc.view_settings.view_transform = "AgX"; sc.view_settings.look = "AgX - Medium High Contrast"
    w = bpy.data.worlds.new("RefWorld"); w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = srgb((150, 154, 160)); w.node_tree.nodes["Background"].inputs[1].default_value = 0.55
    sc.world = w
    coll = bpy.data.collections.new("SheetStage"); sc.collection.children.link(coll)
    me = bpy.data.meshes.new("Reference_floor")
    bm = bmesh.new(); bmesh.ops.create_grid(bm, x_segments=1, y_segments=1, size=200); bm.to_mesh(me); bm.free()
    me.materials.append(mat("floor", (112, 112, 108), 0.85))
    fl = bpy.data.objects.new("Reference_floor", me); coll.objects.link(fl)
    sun = bpy.data.objects.new("RefSun", bpy.data.lights.new("RefSun", "SUN")); coll.objects.link(sun)
    sun.data.energy = 3.2; sun.data.angle = math.radians(8); sun.data.color = (1.0, 0.96, 0.9)
    sun.rotation_euler = (math.radians(50), 0, math.radians(-35))
    fill = bpy.data.objects.new("RefFill", bpy.data.lights.new("RefFill", "AREA")); coll.objects.link(fill)
    fill.data.energy = 4000; fill.data.size = 30; fill.data.color = (0.85, 0.9, 1.0)
    cam = bpy.data.objects.new("RefCam", bpy.data.cameras.new("RefCam")); coll.objects.link(cam); sc.camera = cam
    cam.data.lens = 45
    return sc, coll, fill, cam


def main():
    man = json.load(open(os.path.join(ROOT, "warehouse2_props.json")))
    sc, coll, fill, cam = setup_scene()
    kit = {o.name: o for o in bpy.data.collections["Kit"].objects}
    for o in bpy.data.collections["Markers"].objects:
        o.hide_render = True
    tiles = []
    for e in man["assemblies"]:
        name = e["assembly"]
        if ONLY and name != ONLY:
            continue
        objs = [kit[n] for n in e["objects"]]
        for o in kit.values():
            o.hide_render = o not in objs
        lo, hi = bbox(objs)
        base = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
        moved = {o: o.location.copy() for o in objs}
        for o in objs:
            o.location -= base
        bpy.context.view_layer.update()
        lo, hi = bbox(objs)
        width = hi.x - lo.x
        kind, old_label = OLD[name]
        stage = bpy.data.collections.new("Stage_" + name); coll.children.link(stage)
        STAND.clear()
        has_old = kind and old_standin(kind, stage)
        olds = list(STAND)
        if olds:
            olo, ohi = bbox(olds)
            dx = lo.x - 2.6 - 2.4 - ohi.x
            for o in olds:
                o.location.x += dx
        hum = human(stage)
        hx = lo.x - 1.6 if not olds else lo.x - 2.5
        if name in CAMDIR:      # side shot: stand the figure on the camera side, by the front wheel
            hx = hi.x + 1.4
        for o in hum:
            o.location.x += hx; o.location.y += 0.4
        bpy.context.view_layer.update()
        alo, ahi = bbox(objs + olds + hum)
        c = (alo + ahi) / 2
        span = max(ahi.x - alo.x, (ahi.y - alo.y) * (0.9 if name in CAMDIR else 0.0), (ahi.z - alo.z) * 1.5, 6.0)
        d = CAMDIR.get(name, Vector((0.18, -1.0, 0.4))).normalized()
        cam.location = c + d * span * (1.9 if name in CAMDIR else 1.45)
        cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
        cam.data.clip_end = 500
        print("CAM", name, tuple(round(v, 2) for v in alo), tuple(round(v, 2) for v in ahi), round(span, 2), tuple(round(v, 2) for v in cam.location), flush=True)
        fill.location = c + Vector((-12, -14, 10))
        fill.rotation_euler = (c - fill.location).to_track_quat("-Z", "Y").to_euler()
        out = os.path.join(REN, name + ".png")
        sc.render.filepath = out
        bpy.ops.render.render(write_still=True)
        tiles.append(dict(name=name, png=out, old=old_label, size=e["size_studio"], tris=e["tris"], replaces=e["replaces"]))
        for o in olds + hum:
            bpy.data.objects.remove(o)
        bpy.data.collections.remove(stage)
        for o, l in moved.items():
            o.location = l
        print("TILE", name, flush=True)
    path = os.path.join(REN, "tiles.json")
    if ONLY and os.path.exists(path):   # re-render of one tile: keep the others
        old = json.load(open(path))
        tiles = [next((t for t in tiles if t["name"] == o["name"]), o) for o in old]
    json.dump(tiles, open(path, "w"), indent=1)


main()

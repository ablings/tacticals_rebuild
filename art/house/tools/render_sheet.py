"""Render each assembly of a house kit next to a 5-stud human (3/4 front view), then tile them into a sheet.
Read-only on the .blend (never saves).
  blender -b art/house/house_furniture.blend --python art/house/tools/render_sheet.py -- house_furniture.json notes/house_props_sheet.jpg [--samples 32] [--only H_Sofa]
Writes art/house/renders/<assembly>.png and the sheet (title row + one labelled tile per assembly)."""
import bpy, json, math, os, sys
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))
REPO = os.path.abspath(os.path.join(ROOT, "..", ".."))
A = sys.argv[sys.argv.index("--") + 1:]
MAN, OUT = A[0], A[1]
SAMPLES = int(A[A.index("--samples") + 1]) if "--samples" in A else 32
ONLY = A[A.index("--only") + 1] if "--only" in A else None
TITLE = A[A.index("--title") + 1] if "--title" in A else "House kit"
REN = os.path.join(ROOT, "renders")
os.makedirs(REN, exist_ok=True)
man = json.load(open(os.path.join(ROOT, MAN)))
sc = bpy.context.scene
sc.render.engine = "CYCLES"
try:
    pr = bpy.context.preferences.addons["cycles"].preferences
    pr.compute_device_type = "OPTIX"; pr.get_devices()
    for d in pr.devices:
        d.use = d.type == "OPTIX"
    sc.cycles.device = "GPU"
except Exception as ex:
    print("cpu", ex)
sc.cycles.samples = SAMPLES
sc.cycles.use_denoising = True
sc.render.resolution_x, sc.render.resolution_y = 600, 400
sc.render.film_transparent = False
sc.view_settings.view_transform = "AgX" if "AgX" in [i.identifier for i in sc.view_settings.bl_rna.properties["view_transform"].enum_items] else "Filmic"
w = bpy.data.worlds.new("SheetWorld"); sc.world = w; w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.42, 0.44, 0.47, 1); w.node_tree.nodes["Background"].inputs[1].default_value = 0.9
sun = bpy.data.objects.new("SheetSun", bpy.data.lights.new("SheetSun", "SUN")); sc.collection.objects.link(sun)
sun.data.energy = 3.2; sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(-35)); sun.data.angle = math.radians(8)
me = bpy.data.meshes.new("SheetFloor"); me.from_pydata([(-500, -500, 0), (500, -500, 0), (500, 500, 0), (-500, 500, 0)], [], [(0, 1, 2, 3)])
fl = bpy.data.objects.new("SheetFloor", me); sc.collection.objects.link(fl)
fm = bpy.data.materials.new("SheetFloorMat"); fm.use_nodes = True
fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.2, 0.2, 0.21, 1); me.materials.append(fm)
cam = bpy.data.objects.new("SheetCam", bpy.data.cameras.new("SheetCam")); sc.collection.objects.link(cam); sc.camera = cam
cam.data.lens = 50
hum = bpy.data.objects.get("R15_Human_5stud")
kit = list(bpy.data.collections["Kit"].objects)
for c in ("Markers",):
    if c in bpy.data.collections:
        for o in bpy.data.collections[c].objects:
            o.hide_render = True
tiles = []
for e in man["assemblies"]:
    if ONLY and not e["assembly"].startswith(ONLY):
        continue
    objs = [o for o in kit if o.name in e["objects"]]
    for o in kit:
        o.hide_render = o not in objs
    pts = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
    lo = Vector([min(p[i] for p in pts) for i in range(3)]); hi = Vector([max(p[i] for p in pts) for i in range(3)])
    lo.z = min(lo.z, 0.0)
    piv = Vector(e["pivot_blender_in_kit"])
    fl.location = (0, 0, piv.z + min(0.0, lo.z - piv.z) - 0.001) if e["bbox_min_rel_pivot_studio"][1] > -0.5 else (0, 0, -100)
    if hum:
        hum.hide_render = False
        hum.location = (lo.x - 1.6, (lo.y + hi.y) / 2, piv.z if e["bbox_min_rel_pivot_studio"][1] > -0.5 else lo.z)
        lo.x -= 2.8
        lo.z = min(lo.z, hum.location.z); hi.z = max(hi.z, hum.location.z + 5.0)
    c = (lo + hi) / 2
    r = max((hi - lo).length / 2, 2.5)
    d = Vector((0.55, -1.0, 0.5)).normalized()
    cam.location = c + d * r * 2.35
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    png = os.path.join(REN, e["assembly"] + ".png")
    sc.render.filepath = png
    bpy.ops.render.render(write_still=True)
    tiles.append(dict(name=e["assembly"], png=png, size=e["size_studio"], tris=e["tris"], cover=e.get("cover", ""), role=e.get("role", "")))
    print("RENDER", e["assembly"], flush=True)
json.dump(tiles, open(os.path.join(REN, "tiles_" + os.path.splitext(MAN)[0] + ".json"), "w"), indent=1)

# compose (PIL ships with Blender's Python? fall back to a separate python run)
try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("PIL missing in Blender: run tools/compose_sheet.py", flush=True)
    sys.exit(0)

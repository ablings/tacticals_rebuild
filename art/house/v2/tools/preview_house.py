"""Preview renders of house.blend (read-only): exterior 3/4, cutaways per storey, interior player-height views.
  blender -b art/house/house.blend --python art/house/tools/preview_house.py -- <outdir> [--views ext,cutG,cutU,int1] [--samples 24] [--extra house_exterior.blend]"""
import bpy, math, os, sys
from mathutils import Vector

A = sys.argv[sys.argv.index("--") + 1:]
OUT = A[0]
VIEWS = (A[A.index("--views") + 1] if "--views" in A else "ext,cutG,cutU,int_lr,int_fy,int_kt,int_ld,back").split(",")
SAMPLES = int(A[A.index("--samples") + 1]) if "--samples" in A else 24
EXTRA = A[A.index("--extra") + 1] if "--extra" in A else None
os.makedirs(OUT, exist_ok=True)
sc = bpy.context.scene
if EXTRA:
    with bpy.data.libraries.load(EXTRA, link=False) as (src, dst):
        dst.objects = list(src.objects)
    for o in dst.objects:
        if o is not None and o.type == "MESH" and "Scale" not in o.name and "Marker" not in o.name:
            sc.collection.objects.link(o)
sc.render.engine = "CYCLES"
try:
    pr = bpy.context.preferences.addons["cycles"].preferences
    pr.compute_device_type = "OPTIX"; pr.get_devices()
    for d in pr.devices:
        d.use = d.type == "OPTIX"
    sc.cycles.device = "GPU"
except Exception:
    pass
sc.cycles.samples = SAMPLES
sc.cycles.use_denoising = True
sc.render.resolution_x, sc.render.resolution_y = 1280, 720
sc.view_settings.view_transform = "AgX"
w = bpy.data.worlds.new("PW"); sc.world = w; w.use_nodes = True
bg = w.node_tree.nodes["Background"]
sky = None
p = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tex", "sky", "sky_side.png")
bg.inputs[0].default_value = (0.55, 0.68, 0.85, 1); bg.inputs[1].default_value = 1.0
sun = bpy.data.objects.new("PSun", bpy.data.lights.new("PSun", "SUN")); sc.collection.objects.link(sun)
sun.data.energy = 4.0; sun.rotation_euler = (math.radians(48), math.radians(12), math.radians(-30)); sun.data.angle = math.radians(3)
cam = bpy.data.objects.new("PCam", bpy.data.cameras.new("PCam")); sc.collection.objects.link(cam); sc.camera = cam
for o in sc.objects:
    if "ScaleCube" in o.name or "Marker" in o.name:
        o.hide_render = True
# ground for previews when the exterior is not loaded
if not EXTRA:
    me = bpy.data.meshes.new("PGround"); me.from_pydata([(-300, -300, -1), (300, -300, -1), (300, 300, -1), (-300, 300, -1)], [], [(0, 1, 2, 3)])
    gr = bpy.data.objects.new("PGround", me); sc.collection.objects.link(gr)
    gm = bpy.data.materials.new("PG"); gm.use_nodes = True
    gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.12, 0.2, 0.08, 1); me.materials.append(gm)


def look(loc, tgt, lens=24):
    cam.location = Vector(loc)
    cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = lens


def hide(fn):
    for o in sc.objects:
        if o.type == "MESH" and o.name not in ("PGround",):
            o.hide_render = fn(o) or ("ScaleCube" in o.name or "Marker" in o.name) or ((o.name.endswith("_Glass") or "_BrokenGlass" in o.name) and "Skylight" not in o.name)


def zmin(o):
    return min((o.matrix_world @ v.co).z for v in o.data.vertices) if o.data.vertices else 0


VIEWDEF = {
    "ext": (lambda o: False, (60, -95, 35), (0, 0, 12), 24),
    "back": (lambda o: False, (-55, 90, 30), (0, 0, 12), 24),
    "cutG": (lambda o: zmin(o) > 12.5 or o.name.startswith(("Shell_R", "Roof", "Shell_U")), (0, -1, 140), (0, 0, 0), 26),
    "cutU": (lambda o: o.name.startswith("Shell_R") or ("CeilingWhite" in o.name and "Shell_U" in o.name) or o.name.startswith("Skylight") and "Glass" in o.name, (0, -1, 150), (0, 0, 14), 26),
    "int_lr": (lambda o: False, (-37, -27, 4.6), (-12, -5, 3.5), 18),
    "int_fy": (lambda o: False, (4, -28, 4.6), (-4, -6, 10), 18),
    "int_kt": (lambda o: False, (37, 27, 4.6), (18, 2, 3.5), 18),
    "int_ld": (lambda o: False, (6, 2, 18.6), (-2, -24, 12), 18),
    "int_mb": (lambda o: False, (-12, 2, 18.6), (-35, -25, 16), 18),
    "win_s": (lambda o: False, (-18, -24, 18.6), (-14, -70, 14), 22),
    "win_n": (lambda o: False, (-30, 24, 18.6), (-30, 70, 16), 22),
    "street": (lambda o: False, (40, -66, 4), (-10, -40, 10), 20),
    "aerial": (lambda o: False, (110, -170, 90), (0, -40, 0), 24),
    "win_w": (lambda o: False, (-33, -2, 4.6), (-90, -2, 9), 26),
    "win_e": (lambda o: False, (33, 12, 5.5), (90, 12, 9), 26),
    "win_bw": (lambda o: False, (-33, 14, 18.6), (-90, 14, 22), 26),
    "int_bh": (lambda o: False, (-2, 28, 4.6), (2, 6, 6), 18),
}
# preview-only fill lights in the rooms (the map builder lights the real map)
for (x, y, z) in ((-25, -10, 11), (0, -16, 22), (0, -16, 10), (25, -20, 11), (25, 12, 11), (-10, 20, 11), (-25, -14, 24), (25, -14, 24),
                  (-25, 17, 24), (0, 0, 24), (0, 0, 11), (-3, 24, 24), (-32, 20, 11)):
    L = bpy.data.objects.new("PFill", bpy.data.lights.new("PFill", "POINT")); sc.collection.objects.link(L)
    L.location = (x, y, z); L.data.energy = 9000; L.data.shadow_soft_size = 3; L.data.color = (1.0, 0.95, 0.88)
CULL = "--cull" in A
if CULL:      # Roblox-like: back faces culled, magenta sky -> any hole or flipped face shows magenta
    try:
        sc.render.engine = "BLENDER_EEVEE_NEXT"
    except Exception:
        sc.render.engine = "BLENDER_EEVEE"
    nt = w.node_tree
    mg = nt.nodes.new("ShaderNodeBackground"); mg.inputs[0].default_value = (1, 0, 1, 1)
    lp = nt.nodes.new("ShaderNodeLightPath"); mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(lp.outputs["Is Camera Ray"], mix.inputs[0]); nt.links.new(bg.outputs[0], mix.inputs[1]); nt.links.new(mg.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], nt.nodes["World Output"].inputs[0])
    for m in bpy.data.materials:
        m.use_backface_culling = True
for v in VIEWS:
    fn, loc, tgt, lens = VIEWDEF[v]
    hide(fn)
    look(loc, tgt, lens)
    if v.startswith("cut"):
        cam.data.type = "ORTHO"; cam.data.ortho_scale = 100
    else:
        cam.data.type = "PERSP"
    sc.render.filepath = os.path.join(OUT, f"house_{v}{'_cull' if CULL else ''}.png")
    bpy.ops.render.render(write_still=True)
    print("VIEW", v, flush=True)

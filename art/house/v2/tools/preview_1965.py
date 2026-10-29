"""1965 House previews (read-only on the blends): the shell + its 1965 layers, the furniture kit placed the way
tools/house_installer.lua places it (bbox bottom centre on the layout box centre, face -> turn, kitchen runs, the dining
table as two sets, the variant map applied), and the exterior. Player-height views per room + window views + the street.
  blender -b art/house/v2/house.blend --python art/house/v2/tools/preview_1965.py -- <outdir> [--views a,b] [--samples 32] [--novariants] [--cull]"""
import bpy, json, math, os, sys
from mathutils import Vector, Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))
REPO = os.path.abspath(os.path.join(ROOT, "..", "..", ".."))
A = sys.argv[sys.argv.index("--") + 1:]
OUT = A[0]
SAMPLES = int(A[A.index("--samples") + 1]) if "--samples" in A else 32
VAR = "--novariants" not in A
CULL = "--cull" in A
LAY = json.load(open(os.path.join(REPO, "notes", "maps", "house_layout.json")))
FMAN = json.load(open(os.path.join(ROOT, "house_furniture.json")))
VMAP = FMAN.get("variant_map", {}) if VAR else {}
os.makedirs(OUT, exist_ok=True)
sc = bpy.context.scene

# ---- load the exterior and the furniture kit
with bpy.data.libraries.load(os.path.join(ROOT, "house_exterior.blend"), link=False) as (src, dst):
    dst.objects = [n for n in src.objects if not n.startswith("K_")]
for o in dst.objects:
    if o is not None and o.type == "MESH":
        sc.collection.objects.link(o)
ASM = {e["assembly"]: e for e in FMAN["assemblies"]}
need = set()
for e in FMAN["assemblies"]:
    need |= set(e["objects"])
with bpy.data.libraries.load(os.path.join(ROOT, "house_furniture.blend"), link=False) as (src, dst):
    dst.objects = [n for n in src.objects if n in need]
KIT = {o.name: o for o in dst.objects if o is not None}
ROT = {"S": 0.0, "E": 90.0, "N": 180.0, "W": -90.0}


def asm_bbox(name):
    e = ASM[name]
    pts = [KIT[n].matrix_world @ v.co for n in e["objects"] for v in KIT[n].data.vertices]
    lo = Vector([min(p[i] for p in pts) for i in range(3)]); hi = Vector([max(p[i] for p in pts) for i in range(3)])
    return lo, hi


def place(name, x, y, z, face):
    lo, hi = asm_bbox(name)
    piv = Vector(((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, lo.z))
    M = Matrix.Translation((x, y, z)) @ Matrix.Rotation(math.radians(ROT.get(face or "S", 0.0)), 4, "Z") @ Matrix.Translation(-piv)
    for n in ASM[name]["objects"]:
        src_ = KIT[n]
        o = bpy.data.objects.new("P_" + n, src_.data)
        o.matrix_world = M @ src_.matrix_world
        sc.collection.objects.link(o)


RUN = {"KitchenRun1": ["H_KitchenBase"], "KitchenRun3": ["H_KitchenBase", "H_KitchenSink", "H_KitchenBase"],
       "KitchenRun6": ["H_KitchenBase", "H_KitchenSink", "H_KitchenBase", "H_KitchenHob", "H_KitchenBase", "H_KitchenBase"]}
for f in LAY["furniture"]:
    cx, cy = (f["x0"] + f["x1"]) / 2, (f["y0"] + f["y1"]) / 2
    fw, fd = f["x1"] - f["x0"], f["y1"] - f["y0"]
    face = f["face"] or ("S" if fw >= fd else "E")
    model = VMAP.get(f["id"], f["model"])
    runs = RUN.get(model)
    if runs:
        alongX = fw >= fd
        for k, nm in enumerate(runs):
            t = (k + 0.5) / len(runs)
            place(nm, f["x0"] + fw * t if alongX else cx, cy if alongX else f["y0"] + fd * t, f["z0"], face)
    elif model == "H_DiningSet":
        place(model, f["x0"] + fw * 0.25, cy, f["z0"], face or "S"); place(model, f["x0"] + fw * 0.75, cy, f["z0"], face or "S")
    else:
        place(model, cx, cy, f["z0"], face)
for d in LAY["dressing"]:
    model = VMAP.get(d["id"], d["model"])
    if model not in ASM:
        continue
    z = d["z"] - d["size"][1] if d["model"] == "H_PendantLamp" else d["z"]
    place(model, d["x"], d["y"], z, d["face"])

# ---- render setup: hazy desert afternoon
sc.render.engine = "CYCLES"
try:
    pr = bpy.context.preferences.addons["cycles"].preferences
    DEV = A[A.index("--device") + 1] if "--device" in A else "OPTIX"     # Shadow PC: OptiX fails, use --device CUDA
    pr.compute_device_type = DEV; pr.get_devices()
    for dv in pr.devices:
        dv.use = dv.type == DEV
    sc.cycles.device = "GPU"
except Exception:
    pass
sc.cycles.samples = SAMPLES
sc.cycles.use_denoising = True
sc.render.resolution_x, sc.render.resolution_y = 1280, 720
sc.view_settings.view_transform = "AgX"
w = bpy.data.worlds.new("PW"); sc.world = w; w.use_nodes = True
bg = w.node_tree.nodes["Background"]
skyimg = os.path.join(ROOT, "tex", "sky", "sky_side.png")
if os.path.exists(skyimg):
    te = w.node_tree.nodes.new("ShaderNodeTexEnvironment"); te.image = bpy.data.images.load(skyimg)
    te.projection = "EQUIRECTANGULAR"
    w.node_tree.links.new(te.outputs[0], bg.inputs[0])
bg.inputs[1].default_value = 1.1
sun = bpy.data.objects.new("PSun", bpy.data.lights.new("PSun", "SUN")); sc.collection.objects.link(sun)
sun.data.energy = 4.5; sun.data.color = (1.0, 0.9, 0.76)
sun.rotation_euler = (math.radians(52), math.radians(8), math.radians(-150)); sun.data.angle = math.radians(2)
cam = bpy.data.objects.new("PCam", bpy.data.cameras.new("PCam")); sc.collection.objects.link(cam); sc.camera = cam
for o in sc.objects:
    if o.type == "MESH" and ("ScaleCube" in o.name or "Marker" in o.name or "_BrokenGlass" in o.name):
        o.hide_render = True
    if o.type == "MESH" and (o.name.endswith("_Glass") or "Bookcase_Glass" in o.name or o.name.endswith("Hutch_Glass")):
        o.hide_render = True          # windows: the panes are Studio glass (Transparency ~0.82); the tape crosses stay visible
# preview-only warm lamps in the rooms (the map builder lights the real map)
for (x, y, z) in ((-25, -12, 11), (0, -16, 22), (0, -16, 10), (25, -20, 11), (25, 12, 11), (-10, 20, 11), (-25, -14, 24), (25, -14, 24),
                  (-25, 17, 24), (0, 0, 24), (0, 0, 11), (-3, 24, 24), (-32, 20, 11), (-33, -20, 11), (33, 22, 11)):
    L = bpy.data.objects.new("PFill", bpy.data.lights.new("PFill", "POINT")); sc.collection.objects.link(L)
    L.location = (x, y, z); L.data.energy = 5000; L.data.shadow_soft_size = 3; L.data.color = (1.0, 0.82, 0.62)

VIEWS = {   # name: (camera, target, lens): eye 4.6 above each floor
    "lr": ((-11, -27.5, 4.6), (-38, -8, 4.0), 18), "lr2": ((-37, 6, 4.6), (-18, -24, 3.0), 18),
    "fy": ((4, -28, 4.6), (-4, -6, 10), 18), "kt": ((37, 27, 4.6), (16, 4, 3.5), 18), "kt2": ((11, -6, 4.6), (34, 24, 3.5), 18),
    "dr": ((38, -28.5, 4.6), (16, -12, 3.5), 18), "bh": ((-2, 28, 4.6), (2, 6, 6), 18), "mr": ((-10, 29, 4.6), (-22, 12, 3.5), 18),
    "gb": ((-38.5, 11.0, 4.6), (-26, 28, 3.0), 18), "ld": ((6, 2, 18.6), (-2, -24, 12), 18), "mb": ((-14, -1, 18.6), (-38, -28, 16), 18),
    "br2": ((20, -28.5, 18.6), (38, -6, 16), 18), "br3": ((-12, 28, 18.6), (-36, 6, 16), 18), "ub": ((2.5, 18.0, 18.6), (-8, 29, 17), 18),
    "win_s": ((-20, -25, 18.6), (-18, -80, 14), 22), "win_n": ((-30, 24, 18.6), (-30, 80, 16), 22),
    "win_fy": ((3, -6, 18.6), (25, -200, 28), 22), "win_e": ((33, 12, 5.5), (90, 12, 9), 26), "win_w": ((-33, -2, 4.6), (-90, -2, 9), 26),
    "street": ((40, -66, 4), (-10, -40, 10), 20), "aerial": ((110, -170, 90), (0, -60, 0), 24), "across": ((6, -40, 6), (0, -120, 12), 22),
}
VS = (A[A.index("--views") + 1].split(",") if "--views" in A else list(VIEWS))
if CULL:
    nt = w.node_tree
    mg = nt.nodes.new("ShaderNodeBackground"); mg.inputs[0].default_value = (1, 0, 1, 1)
    lp = nt.nodes.new("ShaderNodeLightPath"); mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(lp.outputs["Is Camera Ray"], mix.inputs[0]); nt.links.new(bg.outputs[0], mix.inputs[1]); nt.links.new(mg.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], nt.nodes["World Output"].inputs[0])
    for m in bpy.data.materials:
        m.use_backface_culling = True
for v in VS:
    loc, tgt, lens = VIEWS[v]
    cam.location = Vector(loc)
    cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = lens
    sc.render.filepath = os.path.join(OUT, f"h65_{v}{'_cull' if CULL else ''}.png")
    bpy.ops.render.render(write_still=True)
    print("VIEW", v, flush=True)

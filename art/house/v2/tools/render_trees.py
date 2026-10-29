"""Render the exterior trees in the real street scene, old vs new from the same cameras. Read-only on both .blend files.
  blender -b art/house/house_exterior.blend --python art/house/tools/render_trees.py -- before|after [--samples 48]
before = H_Exterior as built (faceted Tree_* blobs, box hedge); after = those hidden and house_trees.blend's trees + hedge in.
Writes captures/house/trees/<mode>_<camera>.png (the cameras stand where our windows are, eye height ~5 above the floor)."""
import bpy, math, os, sys
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))
REPO = os.path.abspath(os.path.join(ROOT, "..", "..", ".."))
A = sys.argv[sys.argv.index("--") + 1:]
MODE = A[0]
SAMPLES = int(A[A.index("--samples") + 1]) if "--samples" in A else 48
OUT = os.path.join(REPO, "captures", "house", "trees")
os.makedirs(OUT, exist_ok=True)

CAMS = {   # name: (location, look-at, lens mm)
    "front_LR": ((-12, -32, 5.5), (-18, -80, 6), 24),      # living room front window, looking south over the hedge
    "front_DR": ((14, -32, 5.5), (24, -80, 7), 24),
    "back_BH": ((0, 30, 5.5), (0, 80, 8), 24),             # back of the house, looking north at the yard trees
    "side_W": ((-40, -10, 5.5), (-100, -40, 8), 28),
    "close_round": ((-14, -36, 4.5), (-30, -46, 9), 28),   # Tree_01 round
    "close_spruce": ((0, 46, 4.5), (6, 66, 8), 30),        # Tree_04 spruce
    "close_spread": ((-22, 42, 4.5), (-34, 58, 10), 26),   # Tree_03 spread
    "close_oval": ((24, -36, 4.5), (36, -48, 8), 30),      # Tree_02 oval
}

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
sc.render.resolution_x, sc.render.resolution_y = 1100, 640
sc.view_settings.view_transform = "AgX"
w = bpy.data.worlds.new("TreeWorld"); sc.world = w
nt = w.node_tree
bg = nt.nodes.get("Background") or nt.nodes.new("ShaderNodeBackground")
grad = nt.nodes.new("ShaderNodeTexCoord"); sep = nt.nodes.new("ShaderNodeSeparateXYZ"); ramp = nt.nodes.new("ShaderNodeValToRGB")
nt.links.new(sep.inputs[0], grad.outputs["Generated"]); nt.links.new(ramp.inputs[0], sep.outputs[2])
ramp.color_ramp.elements[0].position = 0.5; ramp.color_ramp.elements[0].color = (0.62, 0.74, 0.86, 1)
ramp.color_ramp.elements[1].position = 0.75; ramp.color_ramp.elements[1].color = (0.18, 0.38, 0.75, 1)
bg.inputs["Color"].default_value = (0.42, 0.6, 0.9, 1); bg.inputs["Strength"].default_value = 0.9
out = nt.nodes.get("World Output") or nt.nodes.new("ShaderNodeOutputWorld")
nt.links.new(out.inputs[0], bg.outputs[0])
sun = bpy.data.objects.new("TreeSun", bpy.data.lights.new("TreeSun", "SUN")); sc.collection.objects.link(sun)
sun.data.energy = 3.5; sun.data.angle = math.radians(3)
sun.rotation_euler = (math.radians(42), 0, math.radians(200))
for o in sc.objects:   # helpers never in the shot
    if o.name.startswith(("K_ScaleCube", "K_Marker")):
        o.hide_render = True

if MODE == "after":
    for o in sc.objects:
        if (o.name.startswith("Tree_") and not o.name.startswith("Tree_N")) or o.name == "Ext_Yard_Hedge":
            o.hide_render = True
    lib = os.path.join(ROOT, "house_trees.blend")
    with bpy.data.libraries.load(lib, link=False) as (src, dst):
        dst.objects = [n for n in src.objects if n.startswith(("Tree_", "Hedge_"))]
    for o in dst.objects:
        o.name = "N_" + o.name
        sc.collection.objects.link(o)

cam = bpy.data.objects.new("TreeCam", bpy.data.cameras.new("TreeCam")); sc.collection.objects.link(cam); sc.camera = cam
only = A[A.index("--only") + 1].split(",") if "--only" in A else None
for name, (loc, tgt, lens) in CAMS.items():
    if only and name not in only:
        continue
    cam.location = loc
    d = Vector(tgt) - Vector(loc)
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = lens; cam.data.clip_end = 2000
    sc.render.filepath = os.path.join(OUT, f"{MODE}_{name}.png")
    bpy.ops.render.render(write_still=True)
    print("wrote", sc.render.filepath, flush=True)

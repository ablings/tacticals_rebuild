"""render.py: workbench preview strips of clips in a set file.
  blender -b art/anim/weapons/blender/sets/<set>.blend --python render.py -- <out_dir> <Clip> [<Clip> ...] [--n 6]
Writes <out_dir>/<Clip>_<view>_<i>.png (views: side, game = over the right shoulder, front)."""
import bpy, sys, os, math
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
n = 6
frames = None
if "--n" in argv:
    i = argv.index("--n"); n = int(argv[i + 1]); argv = argv[:i] + argv[i + 2:]
if "--f" in argv:  # explicit frames: --f 0,4,9,15,24
    i = argv.index("--f"); frames = [float(x) for x in argv[i + 1].split(",")]; argv = argv[:i] + argv[i + 2:]
out, clips = argv[0], argv[1:]
os.makedirs(out, exist_ok=True)
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sc.display.shading.light = "STUDIO"
sc.display.shading.color_type = "MATERIAL"
sc.display.shading.show_shadows = True
sc.render.resolution_x, sc.render.resolution_y = 360, 480
sc.render.film_transparent = False
for o in bpy.data.objects:  # hide the starter rig's widget shapes
    if o.type == "MESH" and o.parent is None:
        o.hide_render = True
    if o.name == "Woman Head":
        o.hide_render = True
ob = bpy.data.objects["Blocky Rig"]
# a stand-in gun box on the Gun bone (the real gun is checked in Studio)
if False:
    bpy.ops.mesh.primitive_cube_add(size=1)
    g = bpy.context.active_object; g.name = "GunProxy"
    g.scale = (0.18, 0.9, 0.35)
    g.parent = ob; g.parent_type = "BONE"; g.parent_bone = "Gun"
    g.location = (0, -0.65, 0.1)  # bone-tail relative; barrel along +Y of the bone
cam_data = bpy.data.cameras.new("cam"); cam = bpy.data.objects.new("cam", cam_data)
sc.collection.objects.link(cam); sc.camera = cam
cam_data.lens = 45
VIEWS = {"side": (Vector((11, 0.6, 3.0)), Vector((0, 0.6, 3.0))),
         "game": (Vector((3.2, -9.0, 5.4)), Vector((0.3, 1.5, 3.4))),
         "front": (Vector((-5.5, 9.0, 3.6)), Vector((0, 0.3, 3.0)))}
for name in clips:
    act = bpy.data.actions[name]
    ob.animation_data.action = act
    f0, f1 = act.frame_range
    for vi, (pos, look) in VIEWS.items():
        cam.location = pos
        cam.rotation_euler = (look - pos).to_track_quat("-Z", "Y").to_euler()
        fl = frames if frames else [f0 + (f1 - f0) * k / max(1, n - 1) for k in range(n)]
        for k, f in enumerate(fl):
            sc.frame_set(int(f), subframe=f - int(f))
            sc.render.filepath = os.path.join(out, "%s_%s_%d.png" % (name, vi, k))
            bpy.ops.render.render(write_still=True)
print("RENDERED", clips)

"""render.py: workbench preview strips of clips in a set file.
  blender -b art/anim/weapons/blender/sets/<set>.blend --python render.py -- <out_dir> <Clip> [<Clip> ...] [--n 6]
Writes <out_dir>/<Clip>_<view>_<i>.png (views: side, game = over the right shoulder, front)."""
import bpy, sys, os, math
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
n = 6
if "--n" in argv:
    i = argv.index("--n"); n = int(argv[i + 1]); argv = argv[:i] + argv[i + 2:]
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
if "GunProxy" not in bpy.data.objects:
    bpy.ops.mesh.primitive_cube_add(size=1)
    g = bpy.context.active_object; g.name = "GunProxy"
    g.scale = (0.18, 0.9, 0.35)
    g.parent = ob; g.parent_type = "BONE"; g.parent_bone = "Gun"
    g.location = (0, -0.65, 0.1)  # bone-tail relative; barrel along +Y of the bone
cam_data = bpy.data.cameras.new("cam"); cam = bpy.data.objects.new("cam", cam_data)
sc.collection.objects.link(cam); sc.camera = cam
cam_data.lens = 50
VIEWS = {"side": (Vector((9, 1.5, 3.4)), Vector((0, 1.0, 3.2))),
         "game": (Vector((2.6, -6.5, 5.6)), Vector((0.4, 3.0, 4.2))),
         "front": (Vector((1.5, 9, 3.6)), Vector((0, 0, 3.0)))}
for name in clips:
    act = bpy.data.actions[name]
    ob.animation_data.action = act
    f0, f1 = act.frame_range
    for vi, (pos, look) in VIEWS.items():
        cam.location = pos
        cam.rotation_euler = (look - pos).to_track_quat("-Z", "Y").to_euler()
        for k in range(n):
            f = f0 + (f1 - f0) * k / max(1, n - 1)
            sc.frame_set(int(f), subframe=f - int(f))
            sc.render.filepath = os.path.join(out, "%s_%s_%d.png" % (name, vi, k))
            bpy.ops.render.render(write_still=True)
print("RENDERED", clips)

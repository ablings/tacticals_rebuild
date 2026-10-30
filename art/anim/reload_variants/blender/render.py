"""render.py: Blender workbench previews of reload variants (side, game camera, and a close-up that follows the gun).
  blender -b reload_variants/blender/sets/<set>.blend --python render.py -- <out_dir> <Clip> --f 0,13,25,...
Writes <out_dir>/<Clip>_<view>_<i>.png"""
import bpy, sys, os
from mathutils import Vector
argv = sys.argv[sys.argv.index("--") + 1:]
i = argv.index("--f"); frames = [float(x) for x in argv[i + 1].split(",")]; argv = argv[:i] + argv[i + 2:]
views = ["side", "game", "close"]
if "--views" in argv:
    i = argv.index("--views"); views = argv[i + 1].split(","); argv = argv[:i] + argv[i + 2:]
out, clips = argv[0], argv[1:]
os.makedirs(out, exist_ok=True)
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sc.display.shading.light = "STUDIO"
sc.display.shading.color_type = "MATERIAL"
sc.display.shading.show_shadows = True
sc.render.resolution_x, sc.render.resolution_y = 360, 480
for o in bpy.data.objects:
    if o.type == "MESH" and o.parent is None:
        o.hide_render = True
    if o.name == "Woman Head":
        o.hide_render = True
# rounds in brass so they read against the dark gun
brass = bpy.data.materials.get("RVBrass") or bpy.data.materials.new("RVBrass")
brass.diffuse_color = (0.85, 0.62, 0.18, 1)
for o in bpy.data.objects:
    if o.name.startswith("R15_gun_Round") or o.name == "R15_gun_SpeedLoader":
        o.data.materials.clear(); o.data.materials.append(brass)
    if o.name == "R15_gun_Rounds":
        o.hide_render = True
olive = bpy.data.materials.get("RVOlive") or bpy.data.materials.new("RVOlive")
olive.diffuse_color = (0.42, 0.5, 0.18, 1)
MOVING = ("Mag", "Slide", "SlideStop", "CockingKnob", "ChargingHandle", "BoltCarrier", "Bolt", "Pump", "Crane", "Cylinder",
          "EjectorRod", "LoadShell", "MagRelease", "LeftMag", "LeftSlide")
for o in bpy.data.objects:
    n = o.name[len("R15_gun_"):] if o.name.startswith("R15_gun_") else None
    if n in MOVING:
        o.data.materials.clear(); o.data.materials.append(olive)
ob = bpy.data.objects["Blocky Rig"]
if "close" in views:
    for o in bpy.data.objects:
        if o.name in ():
            o.hide_render = True
cam_data = bpy.data.cameras.new("cam"); cam = bpy.data.objects.new("cam", cam_data)
sc.collection.objects.link(cam); sc.camera = cam
VIEWS = {"side": (Vector((11, 0.6, 3.0)), Vector((0, 0.6, 3.0)), 45),
         "game": (Vector((3.2, -9.0, 5.4)), Vector((0.3, 1.5, 3.4)), 45)}
for name in clips:
    ob.animation_data.action = bpy.data.actions[name]
    for vi in views:
        for k, f in enumerate(frames):
            sc.frame_set(int(f), subframe=f - int(f))
            bpy.context.view_layer.update()
            for o in bpy.data.objects:
                if o.name == "R15_Head":
                    o.hide_render = (vi == "fp")
            if vi == "fp":
                hc = bpy.data.objects["R15_Head"].matrix_world.translation   # head box centre (Roblox camera subject)
                eye = Vector((hc.x, hc.y + 0.1, hc.z + 0.45))
                pos, look, lens = eye, eye + Vector((0, 10, -5.5)), 20
                sc.render.resolution_x, sc.render.resolution_y = 480, 360
            else:
                sc.render.resolution_x, sc.render.resolution_y = 360, 480
            if vi == "fp":
                pass
            elif vi == "close":
                cyl = bpy.data.objects.get("R15_gun_Cylinder") or bpy.data.objects.get("R15_gun_Frame")
                g = cyl.matrix_world.translation
                pos, look, lens = g + Vector((-1.4, 1.3, 0.9)), g, 55   # front-left, above: the open cylinder's face
            else:
                pos, look, lens = VIEWS[vi]
            cam.location = pos; cam_data.lens = lens
            cam.rotation_euler = (look - pos).to_track_quat("-Z", "Y").to_euler()
            sc.render.filepath = os.path.join(out, "%s_%s_%d.png" % (name, vi, k))
            bpy.ops.render.render(write_still=True)
print("RENDERED", clips)

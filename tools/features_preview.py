"""Eevee previews for the features kit. Background Blender on kit/features_kit.blend (renders only, the .blend is NOT re-saved):
  blender.exe -b kit/features_kit.blend --python tools/features_preview.py
Writes out/features/bl_<piece>.png (one per piece, others hidden) and bl_row.png (whole row). Sheet: tools/features_sheet.py."""
import bpy, math
from mathutils import Vector

OUT = r"C:/Users/aroki/Documents/tacticals_rebuild/out/features/"
sc = bpy.context.scene
sc.render.engine = "BLENDER_EEVEE"
sc.render.resolution_x, sc.render.resolution_y = 800, 600
sc.render.film_transparent = False
for k, v in (("taa_render_samples", 24), ("use_shadows", True), ("use_raytracing", True)):
    try:
        setattr(sc.eevee, k, v)
    except Exception:
        pass
sc.view_settings.view_transform = "AgX"
w = bpy.data.worlds.get("PV_World") or bpy.data.worlds.new("PV_World")
w.use_nodes = True
w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.32, 0.33, 0.34, 1)
w.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
sc.world = w

def light(name, kind, rot, energy, color=(1, 0.95, 0.88)):
    l = bpy.data.lights.get(name) or bpy.data.lights.new(name, kind)
    l.energy = energy; l.color = color
    o = bpy.data.objects.get(name) or bpy.data.objects.new(name, l)
    if o.name not in sc.collection.objects:
        sc.collection.objects.link(o)
    o.rotation_euler = rot
    return o
light("PV_Sun", "SUN", (math.radians(50), math.radians(10), math.radians(-35)), 3.5)
light("PV_Fill", "SUN", (math.radians(70), 0, math.radians(150)), 1.0, (0.85, 0.9, 1.0))
cd = bpy.data.cameras.get("PV_Cam") or bpy.data.cameras.new("PV_Cam")
cd.lens = 50
cam = bpy.data.objects.get("PV_Cam") or bpy.data.objects.new("PV_Cam", cd)
if cam.name not in sc.collection.objects:
    sc.collection.objects.link(cam)
sc.camera = cam

meshes = [o for o in bpy.data.objects if o.type == "MESH"]
pieces = sorted({o.get("piece", o.name.split("__")[0]) for o in meshes if not o.name.startswith("K_")},
                key=lambda p: min((o.matrix_world @ Vector(c)).x for o in meshes if o.get("piece") == p for c in o.bound_box) * -1)

def bounds(objs):
    pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return mn, mx

def shoot(objs, path, d=(-0.6, -1.0, 0.55)):
    for o in meshes:
        o.hide_render = o not in objs
    mn, mx = bounds(objs)
    c = (mn + mx) / 2; r = (mx - mn).length / 2
    dv = Vector(d).normalized()
    dist = r / math.tan(cd.angle / 2) * 1.05
    cam.location = c + dv * dist
    cam.rotation_euler = (-dv).to_track_quat("-Z", "Y").to_euler()
    cd.clip_end = dist * 4
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)

VIEW = {"F_TVArmCeil": (-0.6, -1.0, -0.15), "F_TVArmCeilDual": (-0.9, -1.0, -0.1), "F_PitRim": (-0.5, -0.8, 1.3),
        "F_TrussSpot": (-1.0, -0.8, 0.05), "F_TVArmWall": (-1.4, -0.7, 0.5), "F_PipeRun": (-0.4, -1.0, 0.4)}
for p in pieces:
    objs = [o for o in meshes if o.get("piece") == p]
    shoot(objs, OUT + "bl_%s.png" % p, VIEW.get(p, (-0.6, -1.0, 0.55)))
sc.render.resolution_x, sc.render.resolution_y = 2400, 600
shoot([o for o in meshes if not o.name.startswith("K_")], OUT + "bl_row.png", (-0.0, -1.0, 0.45))
print("PREVIEW_DONE", len(pieces))

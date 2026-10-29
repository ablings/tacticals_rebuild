"""Crouch-eye renders of kit assemblies: a camera at a crouching player's eye height (2.4 studs), a floor and a pale
blue wall behind, so anything see-through under a cover piece shows the blue wall / floor through it.
  blender -b <furniture.blend> --python art/house/v2/tools/crouch_render.py -- <out_dir> <tag> <assembly> [<assembly> ...]
Objects are found by the manifest's object names (house_furniture.json next to the blend). Writes
<out_dir>/<assembly>_crouch_<view>_<tag>.png for views front (-Y), back (+Y) and side (+X, three-quarter)."""
import bpy, json, math, os, sys
from mathutils import Vector

A = sys.argv[sys.argv.index("--") + 1:]
out, tag, names = os.path.abspath(A[0]), A[1], A[2:]
os.makedirs(out, exist_ok=True)
man = json.load(open(os.path.join(os.path.dirname(bpy.data.filepath), "house_furniture.json")))
ents = {e["assembly"]: e for e in man["assemblies"]}
sc = bpy.context.scene
for eng in ("BLENDER_EEVEE_NEXT", "BLENDER_EEVEE"):
    try:
        sc.render.engine = eng; break
    except TypeError:
        pass
sc.render.resolution_x, sc.render.resolution_y = 960, 600
sc.render.film_transparent = False
sc.view_settings.view_transform = "Standard"
w = bpy.data.worlds.new("CR") if not sc.world else sc.world
w.use_nodes = True
bg = w.node_tree.nodes.get("Background")
bg.inputs[0].default_value = (0.55, 0.55, 0.55, 1); bg.inputs[1].default_value = 0.8
sc.world = w


def plane(name, size, loc, rot, col):
    bpy.ops.mesh.primitive_plane_add(size=1, location=loc, rotation=rot)
    o = bpy.context.object; o.name = name; o.scale = size
    m = bpy.data.materials.new(name); m.diffuse_color = col
    m.use_nodes = True; m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = col
    o.data.materials.append(m)
    return o


sun = bpy.data.objects.new("CR_Sun", bpy.data.lights.new("CR_Sun", "SUN")); sc.collection.objects.link(sun)
sun.data.energy = 3.0; sun.rotation_euler = (math.radians(50), 0, math.radians(30))
cam = bpy.data.objects.new("CR_Cam", bpy.data.cameras.new("CR_Cam")); sc.collection.objects.link(cam)
cam.data.lens = 24; sc.camera = cam
for n in names:
    objs = [bpy.data.objects[o] for o in ents[n]["objects"]]
    for o in bpy.data.objects:
        if o.type == "MESH":
            o.hide_render = o not in objs
    pts = [o.matrix_world @ v.co for o in objs for v in o.data.vertices]
    lo = Vector([min(p[i] for p in pts) for i in range(3)]); hi = Vector([max(p[i] for p in pts) for i in range(3)])
    c = (lo + hi) / 2; size = hi - lo
    d = max(size.x, size.y) * 0.9 + 4.0
    for view, dirv in (("front", Vector((0.15, -1, 0))), ("back", Vector((-0.15, 1, 0))), ("side", Vector((1, -0.55, 0)))):
        dirv.normalize()
        wall_d = d + 0.0
        extras = [plane("CR_Floor", (80, 80, 1), (c.x, c.y, 0.0), (0, 0, 0), (0.42, 0.40, 0.36, 1)),
                  plane("CR_Wall", (80, 30, 1), tuple(c - dirv * (max(size.x, size.y) / 2 + 3.0) + Vector((0, 0, 0))),
                        (math.radians(90), 0, math.atan2(dirv.y, dirv.x) + math.radians(90)), (0.35, 0.6, 0.95, 1))]
        extras[1].location.z = 15
        cam.location = Vector((c.x, c.y, 0)) + dirv * d + Vector((0, 0, 2.4))
        tgt = Vector((c.x, c.y, 1.6))
        cam.rotation_euler = (tgt - cam.location).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(out, f"{n}_crouch_{view}_{tag}.png")
        bpy.ops.render.render(write_still=True)
        print("RENDER", sc.render.filepath, flush=True)
        for e in extras:
            bpy.data.objects.remove(e, do_unlink=True)

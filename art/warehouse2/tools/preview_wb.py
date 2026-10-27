"""Quick solid-colour (Workbench) previews of the kit layout, for shape review before baking. Runs inside Blender.
  blender -b art/warehouse2/warehouse2_props.blend --python art/warehouse2/tools/preview_wb.py -- <out_dir>"""
import bpy, os, sys
from mathutils import Vector
out = os.path.abspath(sys.argv[sys.argv.index("--") + 1])
os.makedirs(out, exist_ok=True)
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sh = sc.display.shading
sh.light, sh.color_type, sh.show_cavity, sh.show_shadows = "STUDIO", "MATERIAL", True, True
sc.render.resolution_x, sc.render.resolution_y = 480, 400
w = bpy.data.worlds.new("w"); w.color = (0.2, 0.21, 0.22); sc.world = w
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
kit = [o for o in bpy.data.collections["Kit"].objects if o.type == "MESH"]
groups = {}
for o in kit:
    groups.setdefault(o.name.split("__")[0], []).append(o)
names = list(groups)
for i in range(len(names)):
    objs = groups[names[i]]
    pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    c, r = (lo + hi) / 2, (hi - lo).length / 2
    for tag, d in (("a", Vector((0.55, -1.0, 0.45))), ("b", Vector((-0.6, 0.9, 0.5)))):
        cam.location = c + d.normalized() * r * 2.6
        cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
        cam.data.lens = 40
        for o in kit:
            o.hide_render = o not in objs
        sc.render.filepath = os.path.join(out, f"wb_{i:02d}{tag}.png")
        bpy.ops.render.render(write_still=True)
print("PREVIEWS", out)

try:
    from PIL import Image
except ImportError:
    Image = None

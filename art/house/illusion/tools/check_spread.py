"""blender_check with the Mid pieces spread 120 apart in memory (in the saved file they all sit at the origin, which
only makes false A8 overlaps between alternative pieces). Never saves.
  blender -b art/house/illusion/house_illusion.blend --python art/house/illusion/tools/check_spread.py -- <render_dir> <json>"""
import bpy, sys, os, json
args = sys.argv[sys.argv.index("--") + 1:]
mids = [o for o in bpy.data.objects if o.type == "MESH" and o.users_collection and o.users_collection[0].name == "Mid"]
for i, o in enumerate(sorted(mids, key=lambda o: o.name)):
    o.location.x += 120.0 * (i + 1)
    o.location.y += 1500.0
bpy.context.view_layer.update()
g = {"__name__": "blender_check_lib"}
exec(open(r"C:/Users/aroki/Documents/roblox_kits/tools/checks/blender_check.py").read(), g)
rep = g["run"](collection=(args[2] if len(args) > 2 else None), render_dir=args[0] if args else None)
if len(args) > 1:
    json.dump(rep, open(args[1], "w"), indent=1, default=str)
print("MODEL CHECK:", rep.get("objects"), "objects", rep.get("triangles"), "tris", rep["fail"], "FAIL", rep["warn"], "WARN")
for f in rep["findings"]:
    print(" ", f["level"], f.get("code", f.get("check")), f.get("object", f.get("objects")), str(f.get("msg", f.get("message", "")))[:150])

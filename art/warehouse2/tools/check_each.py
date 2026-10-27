"""Run roblox_kits blender_check per assembly (others hidden), magenta renders into renders/check/<assembly>/.
  blender -b art/warehouse2/warehouse2_props.blend --python art/warehouse2/tools/check_each.py"""
import bpy, json, os
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.abspath(os.path.join(HERE, ".."))
ns = {"__name__": "blender_check"}
exec(open(os.path.expanduser("~/Documents/roblox_kits/tools/checks/blender_check.py")).read(), ns)
man = json.load(open(os.path.join(ROOT, "warehouse2_props.json")))
kit = [o for o in bpy.data.collections["Kit"].objects]
for o in bpy.data.collections["Markers"].objects:
    o.hide_render = True
summary = {}
for e in man["assemblies"]:
    for o in kit:
        o.hide_set(o.name not in e["objects"]); o.hide_render = o.name not in e["objects"]
    rep = ns["run"](collection="Kit", render_dir=os.path.join(ROOT, "renders", "check", e["assembly"]))
    summary[e["assembly"]] = dict(tris=rep["triangles"], fail=rep["fail"], warn=rep["warn"],
                                  findings=[f"{f['level']} {f['code']} {f['object']}: {f['message']}" for f in rep["findings"] if f["code"] != "A1b"])
    print("CHECK", e["assembly"], rep["triangles"], "tris", rep["fail"], "FAIL", rep["warn"], "WARN", flush=True)
for o in kit:
    o.hide_set(False)
json.dump(summary, open(os.path.join(ROOT, "renders", "check", "per_assembly.json"), "w"), indent=1)

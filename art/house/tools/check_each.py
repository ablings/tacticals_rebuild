"""Run roblox_kits blender_check per assembly (others hidden), magenta renders into renders/check/<assembly>/.
  blender -b art/house/<file>.blend --python art/house/tools/check_each.py -- <manifest.json> [--norender]"""
import bpy, json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.abspath(os.path.join(HERE, ".."))
A = sys.argv[sys.argv.index("--") + 1:]
ns = {"__name__": "blender_check"}
exec(open(os.path.expanduser("~/Documents/roblox_kits/tools/checks/blender_check.py")).read(), ns)
man = json.load(open(os.path.join(ROOT, A[0])))
render = "--norender" not in A
kit = [o for o in bpy.data.collections["Kit"].objects]
for c in ("Markers", "Reference"):
    if c in bpy.data.collections:
        for o in bpy.data.collections[c].objects:
            o.hide_render = True; o.hide_set(True)
summary = {}
for e in man["assemblies"]:
    for o in kit:
        o.hide_set(o.name not in e["objects"]); o.hide_render = o.name not in e["objects"]
    rep = ns["run"](collection="Kit", render_dir=os.path.join(ROOT, "renders", "check", e["assembly"]) if render else None)
    summary[e["assembly"]] = dict(tris=rep["triangles"], fail=rep["fail"], warn=rep["warn"],
                                  findings=[f"{f['level']} {f['code']} {f['object']}: {f['message']}" for f in rep["findings"]])
    print("CHECK", e["assembly"], rep["triangles"], "tris", rep["fail"], "FAIL", rep["warn"], "WARN", flush=True)
for o in kit:
    o.hide_set(False)
os.makedirs(os.path.join(ROOT, "renders", "check"), exist_ok=True)
json.dump(summary, open(os.path.join(ROOT, "renders", "check", "per_assembly_" + os.path.splitext(os.path.basename(A[0]))[0] + ".json"), "w"), indent=1)

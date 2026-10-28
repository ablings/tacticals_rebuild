# Grader: run the vault blender_check per assembly (read-only; the .blend is never saved)
import bpy, json, sys, os
argv = sys.argv[sys.argv.index("--")+1:]
OUT = argv[0]
ns = {"__name__": "blender_check"}
exec(open(r"C:/Users/Shadow/Documents/roblox_kits/tools/checks/blender_check.py").read(), ns)
kit = [o for o in bpy.data.collections["Kit"].all_objects if o.type == "MESH"]
groups = {}
for o in kit:
    groups.setdefault(o.name.split("__")[0], []).append(o)
orig_meshes = ns["meshes"]
summary = {}
allobjs = list(bpy.context.scene.objects)
for asm, objs in sorted(groups.items()):
    names = {o.name for o in objs}
    ns["meshes"] = lambda collection=None, names=names: [o for o in orig_meshes("Kit") if o.name in names]
    saved = {o.name: o.hide_render for o in allobjs}
    for o in allobjs:
        o.hide_render = o.name not in names
    try:
        rep = ns["run"](collection="Kit", render_dir=os.path.join(OUT, asm))
    finally:
        for o in allobjs:
            o.hide_render = saved[o.name]
    summary[asm] = {"objects": rep["objects"], "tris": rep["triangles"], "fail": rep["fail"], "warn": rep["warn"],
                    "findings": rep["findings"]}
    print(f"ASM {asm:24s} objs={rep['objects']:2d} tris={rep['triangles']:5d} FAIL={rep['fail']} WARN={rep['warn']}")
    for f in rep["findings"]:
        if f["level"] == "FAIL":
            print("    FAIL", f["code"], f["object"], f["message"])
json.dump(summary, open(os.path.join(OUT, "per_assembly_grader.json"), "w"), indent=1)

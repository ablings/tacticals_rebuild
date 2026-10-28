import bpy, json, sys
out = sys.argv[sys.argv.index("--")+1]
res = {}
for o in bpy.context.scene.objects:
    if o.type != "MESH" or not o.data.uv_layers: continue
    res[o.name] = [list(d.uv) for d in o.data.uv_layers[0].data]
json.dump(res, open(out, "w"))

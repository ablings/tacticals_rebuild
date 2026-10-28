import bpy, hashlib, json, sys
out = sys.argv[sys.argv.index("--")+1]
res = {}
for o in bpy.context.scene.objects:
    if o.type != "MESH": continue
    me = o.data
    h = hashlib.sha1()
    for v in me.vertices:
        h.update(("%.5f,%.5f,%.5f;" % tuple(v.co)).encode())
    for p in me.polygons:
        h.update((",".join(map(str, p.vertices)) + ";").encode())
    hu = hashlib.sha1()
    for uvl in me.uv_layers:
        for d in uvl.data:
            hu.update(("%.5f,%.5f;" % tuple(d.uv)).encode())
    mw = [round(x, 5) for r in o.matrix_world for x in r]
    res[o.name] = {"geo": h.hexdigest()[:12], "uv": hu.hexdigest()[:12], "mw": mw, "uvn": [u.name for u in me.uv_layers]}
json.dump(res, open(out, "w"), indent=0)
print("hashed", len(res))

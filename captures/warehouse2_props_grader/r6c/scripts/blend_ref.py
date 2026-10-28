import bpy, json, sys, os, glob, hashlib
import numpy as np
argv = sys.argv[sys.argv.index("--")+1:]
texdir, out = argv[0], argv[1]
res = {"objs": {}, "tex": {}}
for o in bpy.context.scene.objects:
    if o.type != "MESH": continue
    me = o.data
    uv = me.uv_layers[0].data if me.uv_layers else None
    res["objs"][o.name] = {"uvh": hashlib.sha1(np.round(np.array([d.uv[:] for d in uv]), 4).tobytes()).hexdigest()[:10] if uv else None,
                           "tris": sum(len(p.vertices)-2 for p in me.polygons)}
for f in sorted(glob.glob(os.path.join(texdir, "*.png"))):
    im = bpy.data.images.load(f)
    px = np.array(im.pixels[:])
    res["tex"][os.path.basename(f)] = {"size": list(im.size), "px_hash": hashlib.sha1(np.round(px*255).astype(np.uint8).tobytes()).hexdigest()[:10]}
json.dump(res, open(out, "w"), indent=1)
print("done", len(res["objs"]), len(res["tex"]))

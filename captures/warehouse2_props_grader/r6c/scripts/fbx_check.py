# Grader: import each FBX into an EMPTY scene (nothing saved) and compare with the kit .blend dump
import bpy, json, sys, os, glob, hashlib
import numpy as np
argv = sys.argv[sys.argv.index("--")+1:]
fbxdir, out = argv[0], argv[1]
res = {}
for f in sorted(glob.glob(os.path.join(fbxdir, "*.fbx"))):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=f)
    objs = {}
    for o in bpy.context.scene.objects:
        if o.type != "MESH": 
            continue
        me = o.data
        dg = bpy.context.evaluated_depsgraph_get()
        tris = sum(len(p.vertices)-2 for p in me.polygons)
        ngons = sum(1 for p in me.polygons if len(p.vertices) > 3)
        ws = [o.matrix_world @ v.co for v in me.vertices]
        lo = [min(w[i] for w in ws) for i in range(3)]; hi = [max(w[i] for w in ws) for i in range(3)]
        uv = me.uv_layers[0].data if me.uv_layers else None
        uvh = hashlib.sha1(np.round(np.array([d.uv[:] for d in uv]), 4).tobytes()).hexdigest()[:10] if uv else None
        mats = []
        for m in me.materials:
            imgs = []
            if m and m.node_tree:
                for n in m.node_tree.nodes:
                    if n.type == "TEX_IMAGE" and n.image:
                        im = n.image
                        px = np.array(im.pixels[:]) if im.size[0] else np.array([])
                        imgs.append({"name": im.name, "size": list(im.size), "packed": bool(im.packed_file),
                                     "px_hash": hashlib.sha1(np.round(px*255).astype(np.uint8).tobytes()).hexdigest()[:10] if px.size else None,
                                     "file": im.filepath})
            mats.append({"name": m.name if m else None, "imgs": imgs})
        objs[o.name] = {"tris": tris, "ngons": ngons, "uv_layers": [u.name for u in me.uv_layers], "uvh": uvh,
                        "lo": [round(x, 3) for x in lo], "hi": [round(x, 3) for x in hi],
                        "size": [round(hi[i]-lo[i], 3) for i in range(3)], "mats": mats,
                        "rot": [round(x, 4) for x in o.rotation_euler], "scale": [round(x, 4) for x in o.scale]}
    res[os.path.basename(f)] = objs
    print("FBX", os.path.basename(f), len(objs), "meshes", sum(v["tris"] for v in objs.values()), "tris")
json.dump(res, open(out, "w"), indent=1)

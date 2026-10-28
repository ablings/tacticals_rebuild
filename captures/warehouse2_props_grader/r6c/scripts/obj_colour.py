# Grader: per-object mean colour + dark share from the baked colour atlas (optionally remapped to another tex dir). Never saves.
import bpy, json, sys, os, random, colorsys
import numpy as np
argv = sys.argv[sys.argv.index("--")+1:]
out = argv[0]; texdir = argv[1] if len(argv) > 1 else None
if texdir:
    fresh = {}
    for m in bpy.data.materials:
        if not m.node_tree: continue
        for n in m.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image and n.image.filepath:
                base = os.path.basename(n.image.filepath.replace("\\", "/"))
                if not base.lower().endswith(".png"):
                    print("SKIP", n.image.name, repr(n.image.filepath)); continue
                if base not in fresh:
                    fresh[base] = bpy.data.images.load(os.path.join(texdir, base), check_existing=False)
                    fresh[base].name = n.image.name.split(".")[0] + "_g"
                n.image = fresh[base]
random.seed(3)
cache = {}
res = {}
for o in bpy.context.scene.objects:
    if o.type != "MESH" or not o.data.uv_layers or "K_" in o.name[:2]: continue
    me = o.data
    col = [n for n in me.materials[0].node_tree.nodes if n.type == "TEX_IMAGE" and n.image and n.image.name.split(".")[0].replace("_g","").endswith("_color")][0].image
    if col.name not in cache:
        w, h = col.size
        cache[col.name] = (np.array(col.pixels[:], dtype=np.float32).reshape(h, w, 4), w, h)
    px, W, H = cache[col.name]
    me.calc_loop_triangles(); uvl = me.uv_layers[0].data
    acc = np.zeros(3); wsum = 0; dark = 0
    for lt in me.loop_triangles:
        vs = [o.matrix_world @ me.vertices[i].co for i in lt.vertices]
        a = ((vs[1]-vs[0]).cross(vs[2]-vs[0])).length / 2
        uvs = [np.array(uvl[l].uv[:]) for l in lt.loops]
        if abs(np.cross(uvs[1]-uvs[0], uvs[2]-uvs[0])) < 1e-9: continue
        n = max(1, int(a*40))
        for _ in range(n):
            r1, r2 = random.random(), random.random()
            if r1 + r2 > 1: r1, r2 = 1-r1, 1-r2
            uv = uvs[0] + r1*(uvs[1]-uvs[0]) + r2*(uvs[2]-uvs[0])
            c = px[min(H-1, max(0, int(uv[1]*H))), min(W-1, max(0, int(uv[0]*W))), :3]
            acc += c * (a/n); wsum += a/n
            if max(c) < 0.06: dark += a/n
    m = acc / max(wsum, 1e-9)
    res[o.name] = {"mean": [round(float(x)*255) for x in m], "dark_share": round(dark/max(wsum,1e-9), 3), "area": round(wsum, 2)}
json.dump(res, open(out, "w"), indent=1)
print("ok", len(res))

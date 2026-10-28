# Grader: area-weighted colour classes of every kit mesh, sampled from its baked colour atlas (read-only, never saves)
import bpy, json, sys, colorsys, random
import numpy as np
argv = sys.argv[sys.argv.index("--")+1:]
out = argv[0]
random.seed(7)
imgs = {}
def img(name):
    if name not in imgs:
        im = bpy.data.images[name]
        w, h = im.size
        imgs[name] = (np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4), w, h)
    return imgs[name]
def to_srgb(c):
    # Blender stores sRGB PNG pixels as-is in .pixels for colour-managed 'sRGB' images? -> check colorspace
    return c
def classify(r, g, b):
    h, s, v = colorsys.rgb_to_hsv(r, g, b); h *= 360
    if v < 0.10: return "dark"
    if s < 0.10: return "neutral"
    if 60 <= h <= 170 and s >= 0.15: return "green"
    if 60 <= h <= 170: return "greenish_grey"
    if (h < 15 or h >= 340) and s >= 0.35: return "red"
    if 15 <= h < 60 and s >= 0.55: return "orange_yellow"
    if 15 <= h < 60: return "wood_brown"
    if 170 < h < 260: return "blue_grey"
    return "other"
res = {}
for o in bpy.data.collections["Kit"].all_objects:
    if o.type != "MESH": continue
    me = o.data
    mat = me.materials[0]
    col = [n for n in mat.node_tree.nodes if n.type == "TEX_IMAGE" and n.image and n.image.name.endswith("_color")][0].image
    px, W, H = img(col.name)
    me.calc_loop_triangles()
    uvl = me.uv_layers[0].data
    M = o.matrix_world
    tally = {}; area_tot = 0.0; buried = 0.0
    for lt in me.loop_triangles:
        vs = [M @ me.vertices[i].co for i in lt.vertices]
        a = ((vs[1]-vs[0]).cross(vs[2]-vs[0])).length / 2
        uvs = [np.array(uvl[l].uv[:]) for l in lt.loops]
        uva = abs(np.cross(uvs[1]-uvs[0], uvs[2]-uvs[0])) / 2
        if uva < 1e-9:
            buried += a; continue
        n = max(1, int(a * 60))
        w = a / n
        for _ in range(n):
            r1, r2 = random.random(), random.random()
            if r1 + r2 > 1: r1, r2 = 1-r1, 1-r2
            uv = uvs[0] + r1*(uvs[1]-uvs[0]) + r2*(uvs[2]-uvs[0])
            x = min(W-1, max(0, int(uv[0]*W))); y = min(H-1, max(0, int(uv[1]*H)))
            c = px[y, x, :3]
            k = classify(*c)
            tally[k] = tally.get(k, 0) + w
        area_tot += a
    res[o.name] = {"area": area_tot, "buried": buried, "classes": tally, "colourspace": col.colorspace_settings.name}
json.dump(res, open(out, "w"), indent=1)
print("ok", len(res))

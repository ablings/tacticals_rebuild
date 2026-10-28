"""Two hand-over checks the round-2 grade asked for (run inside Blender on a built .blend):
  A18: px per stud of every baked mesh = sqrt(sum(uv_area * res^2) / sum(3D area)) over its visible (non-zero-UV) faces.
  A17: for each assembly in the manifest, the gameplay part's object origin must equal the manifest pivot (kit layout).
  blender -b art/house/house_furniture.blend --python art/house/tools/texel_pivot_check.py -- house_furniture.json
  blender -b art/house/house.blend --python art/house/tools/texel_pivot_check.py
Prints the 12 lowest densities and every pivot mismatch over 0.01."""
import bpy, bmesh, json, math, os, sys
from mathutils import Vector
ROOT = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
A = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
rows = []
for o in bpy.data.objects:
    if o.type != "MESH" or not o.data.uv_layers or not o.data.materials or not o.data.materials[0]:
        continue
    m = o.data.materials[0]
    if not m.use_nodes:
        continue
    imgs = [n.image for n in m.node_tree.nodes if n.type == "TEX_IMAGE" and n.image and "color" in n.image.name]
    if not imgs:
        continue
    res = imgs[0].size[0]
    bm = bmesh.new(); bm.from_mesh(o.data); bm.transform(o.matrix_world)
    uv = bm.loops.layers.uv.active
    A3 = Auv = 0.0
    for f in bm.faces:
        pts = [l[uv].uv for l in f.loops]
        ua = 0.0
        for i in range(1, len(pts) - 1):
            a, b, c = pts[0], pts[i], pts[i + 1]
            ua += abs((b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)) / 2
        if ua < 1e-9:
            continue          # buried faces: zero UV on purpose
        A3 += f.calc_area(); Auv += ua
    bm.free()
    if A3 > 0:
        rows.append((math.sqrt(Auv * res * res / A3), o.name, imgs[0].name, res, round(A3, 1)))
rows.sort()
print("TEXEL lowest px/stud:")
for r in rows[:12]:
    print(f"  TEXEL {r[0]:6.1f}  {r[1]}  ({r[2]} {r[3]}px, {r[4]} sq studs visible)")
if A:
    man = json.load(open(os.path.join(ROOT, A[0])))
    bad = 0
    for e in man["assemblies"]:
        o = bpy.data.objects.get(e["objects"][0])
        if o is None:
            continue
        d = (o.location - Vector(e["pivot_blender_in_kit"])).length
        if d > 0.01:
            bad += 1
            print(f"  PIVOT {e['assembly']}: origin {tuple(round(v, 3) for v in o.location)} vs manifest {e['pivot_blender_in_kit']} ({d:.3f})")
    print(f"PIVOT mismatches: {bad} of {len(man['assemblies'])}")

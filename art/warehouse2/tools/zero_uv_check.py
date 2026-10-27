"""Visible area of faces that got a zero-area UV (they would render the atlas colour at UV 0,0), sampled on a grid; a
sample is visible when it is not inside another loose part of the same assembly. Runs inside Blender on the kit:
  blender -b art/warehouse2/warehouse2_props.blend --python art/warehouse2/tools/zero_uv_check.py"""
import bpy, os, sys
sys.argv = [sys.argv[0], "--", "--only", "__none__"]
exec(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "assembly_check.py")).read())
tot = 0.0
for name in sorted(groups):
    bm = merged(groups[name]); P = Parts(bm)
    uvl = bm.loops.layers.uv.active
    vis = 0.0
    for f in bm.faces:
        uv = [l[uvl].uv for l in f.loops]
        a2 = sum(abs((uv[i].x - uv[0].x) * (uv[i + 1].y - uv[0].y) - (uv[i].y - uv[0].y) * (uv[i + 1].x - uv[0].x)) for i in range(1, len(uv) - 1))
        if a2 > 1e-9:
            continue
        pts = grid(f, 6)
        out = sum(1 for p in pts if not P.hidden(p + f.normal * 0.004, (P.comp[f],)))
        vis += f.calc_area() * out / len(pts)
    bm.free(); tot += vis
    if vis > 0.001:
        print(f"ZEROUV {name:24s} visible {vis:.3f} sq studs")
print(f"ZEROUV TOTAL {tot:.3f} sq studs")

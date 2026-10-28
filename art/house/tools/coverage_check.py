"""Culling-aware coverage test for the house shell (blender_check's A3 is off for open shells, so slits and missing faces
need their own test). For every face of every layout part box that is exposed (not buried in another part, not covered
by a room floor / ceiling quad, not a door reveal), sample points every 0.25 studs and cast a short ray back at the face
from 0.2 in front of it. A sample passes when the first hit is a FRONT face (Roblox culls back faces) within 0.3.
  blender -b art/house/house.blend --python art/house/tools/coverage_check.py -- [out.json]
Exit code 1 if any sample is missing. Lesson from the 2026-10-28 grade: a 6x6 cell split of the wall faces left
full-height slits at every T-junction while blender_check reported 0 FAIL."""
import bpy, bmesh, json, os, sys
from mathutils import Vector
from mathutils.bvhtree import BVHTree
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build_house as bh

A = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = A[0] if A else os.path.join(bh.ROOT, "renders", "check", "coverage_house.json")
bm = bmesh.new()
for o in bpy.data.collections["House"].objects:
    if o.type != "MESH" or "Glass" in o.name or "Scale" in o.name or "Marker" in o.name:
        continue
    t = bmesh.new(); t.from_mesh(o.data); t.transform(o.matrix_world)
    me = bpy.data.meshes.new("tmp"); t.to_mesh(me); t.free()
    bm.from_mesh(me); bpy.data.meshes.remove(me)
bm.normal_update()
tree = BVHTree.FromBMesh(bm)
# room floor / ceiling rects (the generator fills these planes)
for rm in bh.ROOMS:
    fz = 0.0 if rm["storey"] == "G" else 14.0
    cz = 26.0 if (rm["storey"] == "U" or rm["id"] == "FY") else 13.0
    for r in bh.room_rects(rm):
        bh.PLANE_RECTS.append((fz, r["x0"], r["x1"], r["y0"], r["y1"], True))
        bh.PLANE_RECTS.append((cz, r["x0"], r["x1"], r["y0"], r["y1"], False))
# solids the generator adds that are not layout parts: the kitchen-roof parapets (build_house.build_roof)
SOLIDS = [(40.0, 41.0, 4.5, 31.0, 13.0, 15.2), (9.5, 40.0, 30.0, 31.0, 13.0, 15.2)]
import math


def in_stair(p):
    """inside a stair body (under the tread tops, nosings included)"""
    for st in bh.LAY["stairs"]:
        if not (st["x0"] - 0.01 <= p.x <= st["x1"] + 0.01):
            continue
        foot, top, rise, run, n = st["foot_y"], st["top_y"], st["step_rise"], st["step_run"], st["steps"]
        sgn = 1.0 if top > foot else -1.0
        t = (p.y - foot) * sgn + 0.09            # nosing 0.08 over the riser
        if t < 0 or (p.y - top) * sgn > 0.01:
            continue
        i = min(n, int(t // run) + 1)
        if p.z <= i * rise + 0.01:
            return True
    return False


missing, total = [], 0
for b in bh.BOXES:
    for nrm, quad in bh.box_faces(b["x0"], b["x1"], b["y0"], b["y1"], b["z0"], b["z1"]):
        if b["role"] in ("floor", "ceiling") and abs(nrm.z) > 0.5:
            continue
        cen = sum(quad, Vector()) / 4
        if b["role"] in ("wall", "sill") and bh.in_door_opening(cen) and (nrm.z < -0.5 or bh.o_axis_end(quad, nrm, b)):
            continue
        cells, _ = bh.exact_cells(quad, nrm, b)
        for q in cells:
            ax = max(range(3), key=lambda i: abs(nrm[i]))
            u, v = [i for i in range(3) if i != ax]
            lo = [min(p[i] for p in q) for i in range(3)]; hi = [max(p[i] for p in q) for i in range(3)]
            nu = max(1, int((hi[u] - lo[u]) / 0.25)); nv = max(1, int((hi[v] - lo[v]) / 0.25))
            for i in range(nu):
                for j in range(nv):
                    p = Vector(lo)
                    p[u] = lo[u] + 0.02 + (hi[u] - lo[u] - 0.04) * (i + 0.5) / nu
                    p[v] = lo[v] + 0.02 + (hi[v] - lo[v] - 0.04) * (j + 0.5) / nv
                    total += 1
                    if any(x0 - 0.01 <= p.x <= x1 + 0.01 and y0 - 0.01 <= p.y <= y1 + 0.01 and z0 - 0.01 <= p.z <= z1 + 0.01
                           for (x0, x1, y0, y1, z0, z1) in SOLIDS) or in_stair(p) or (p.z > 26.99 and nrm.z > 0.5):   # wall tops under the roof infill
                        continue
                    ok = False
                    for off in (0.13, 0.21, 0.33):
                        hit = tree.ray_cast(p + nrm * off, -nrm, off + 0.1)
                        if hit[0] is not None and hit[1].dot(nrm) >= 0.5:
                            ok = True; break
                    if ok:
                        continue
                    # covered by another solid that overlaps the face (a window frame buried in the reveal, a parapet,
                    # the stair against the slab): walking out from the face we are inside it and meet its back face
                    inn = tree.ray_cast(p + nrm * 0.01, nrm, 6.0)
                    if inn[0] is not None and inn[1].dot(nrm) > 0.5:
                        continue
                    if True:
                        missing.append(dict(part=b["id"], at=[round(c, 2) for c in p], normal=[round(c) for c in nrm]))
by_part = {}
for m in missing:
    by_part.setdefault(m["part"], []).append(m["at"])
rep = dict(samples=total, missing=len(missing), parts={k: dict(n=len(v), first=v[:3]) for k, v in by_part.items()})
json.dump(rep, open(OUT, "w"), indent=1)
print(f"COVERAGE: {total} samples, {len(missing)} missing in {len(by_part)} parts", flush=True)
for k, v in list(by_part.items())[:25]:
    print("  MISSING", k, len(v), v[:2], flush=True)
sys.exit(1 if missing else 0)

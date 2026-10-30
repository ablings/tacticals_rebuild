"""print the faces behind each GAP fail: blender -b <gun.blend> --python gapdiag.py -- PartA PartB"""
import bpy, bmesh, sys
from mathutils.bvhtree import BVHTree
a, b = sys.argv[sys.argv.index("--") + 1:][:2]
def wb(o):
    bm = bmesh.new(); bm.from_object(o, bpy.context.evaluated_depsgraph_get()); bm.transform(o.matrix_world); bm.normal_update(); return bm
A, Bm = wb(bpy.data.objects[a]), wb(bpy.data.objects[b])
for src, dst, n1, n2 in ((A, Bm, a, b), (Bm, A, b, a)):
    bvh = BVHTree.FromBMesh(dst)
    for f in src.faces:
        if f.calc_area() < 1e-4: continue
        hit = bvh.find_nearest(f.calc_center_median(), 0.15)
        if hit[0] is None or hit[3] < 1e-3: continue
        if f.normal.dot(hit[1]) < -0.98:
            c = f.calc_center_median()
            # print in gun frame: f = Y, z = Z, x = X
            print(f"{n1} face c=(x{c.x:.3f} f{c.y:.3f} z{c.z:.3f}) n={tuple(round(v,2) for v in f.normal)} -> {n2} at (x{hit[0].x:.3f} f{hit[0].y:.3f} z{hit[0].z:.3f}) d={hit[3]:.3f}")

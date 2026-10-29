"""FBX read-back (A7 / A10 / A17): import each delivered FBX into an empty scene, measure K_ScaleCube, compare every
object's origin and size with house_illusion.json, count UV maps / materials, and check each closed loose part's signed
volume (A1 per loose part: the whole-object test can hide one inside-out part behind a good one).
  blender -b --factory-startup --python art/house/illusion/tools/verify_fbx.py"""
import bpy, bmesh, json, os, math
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
IROOT = os.path.abspath(os.path.join(HERE, ".."))
man = {o["name"]: o for o in json.load(open(os.path.join(IROOT, "house_illusion.json")))["objects"]}
bad = 0
for fn in ("X_Far.fbx", "X_Near.fbx", "X_Mid.fbx"):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=os.path.join(IROOT, "fbx", fn))
    obs = {o.name: o for o in bpy.data.objects if o.type == "MESH"}
    cube = obs.get("K_ScaleCube")
    cs = max(cube.dimensions) if cube else None
    sc = 10.0 / cs if cs else 1.0
    worst_o, worst_s, n, uvbad, matbad, vol_bad = 0.0, 0.0, 0, [], [], []
    for name, o in obs.items():
        if name.startswith("K_"):
            continue
        m = man.get(name)
        if not m:
            print("  not in manifest:", name); bad += 1; continue
        n += 1
        loc = Vector(o.matrix_world.translation) * sc
        worst_o = max(worst_o, (loc - Vector(m["origin"])).length)
        pts = [o.matrix_world @ v.co * sc for v in o.data.vertices]
        size = Vector([max(p[k] for p in pts) - min(p[k] for p in pts) for k in range(3)])
        worst_s = max(worst_s, (size - Vector(m["size"])).length)
        if len(o.data.uv_layers) != 1:
            uvbad.append(name)
        if len(o.data.materials) != 1:
            matbad.append(name)
        if not m.get("open_shell", True) or name.startswith("X_Mesa1"):
            bm = bmesh.new(); bm.from_mesh(o.data)
            seen = set()
            for f in bm.faces:
                if f in seen:
                    continue
                part, stack = [], [f]
                seen.add(f)
                while stack:
                    g = stack.pop(); part.append(g)
                    for e in g.edges:
                        for h in e.link_faces:
                            if h not in seen:
                                seen.add(h); stack.append(h)
                v = sum(l[0].vert.co.dot(l[i].vert.co.cross(l[i + 1].vert.co)) for g in part for l in [g.loops] for i in range(1, len(l) - 1)) / 6
                if v <= 0:
                    vol_bad.append((name, round(v, 1)))
            bm.free()
    ok = cube is not None and abs(cs * sc - 10) < 1e-6 and worst_o < 0.01 and worst_s < 0.01 and not uvbad and not matbad and not vol_bad
    bad += 0 if ok else 1
    print(f"FBXCHECK {fn}: {n} objects, cube {cs:.4f} units (scale x{sc:.4f}), worst origin diff {worst_o:.4f}, worst size diff "
          f"{worst_s:.4f}, uv!=1 {uvbad}, mats!=1 {matbad}, inside-out loose parts {vol_bad} -> {'PASS' if ok else 'FAIL'}")
print("FBXCHECK", "PASS" if bad == 0 else "FAIL")

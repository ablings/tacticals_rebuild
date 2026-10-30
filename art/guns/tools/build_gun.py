"""Build one gun (or all) from its spec. Rebuild = one run.
  "C:/Program Files/Blender Foundation/Blender 4.5/blender.exe" -b --factory-startup --python art/guns/tools/build_gun.py -- Pistol [Revolver ...]
Writes art/anim/guns/<Gun>.blend + .fbx (rig attached to a copy of the Starter Blocky rig's right hand),
art/guns/manifest/<Gun>.json, art/guns/renders/<Gun>/{side,exploded,persp,top}.png and runs blender_check (--render)."""
import sys, os, json, types, math
sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import importlib
import gunkit
importlib.reload(gunkit)
import bpy
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))       # tacticals_rebuild
GUNS = os.path.join(ROOT, "art", "guns")
ANIM = os.path.join(ROOT, "art", "anim", "guns")
RIG = r"C:/Users/aroki/OneDrive/Documents/Blender/Roblox Starter Rigs/Rigs/Starter_Blocky_Rig.blend"
CHECK = os.path.expanduser(r"~\Documents\roblox_kits\tools\checks\blender_check.py")


def load_spec(name):
    path = os.path.join(HERE, "specs", name + ".py")
    ns = {k: getattr(gunkit, k) for k in dir(gunkit) if not k.startswith("__")}
    ns["__file__"] = path
    exec(compile(open(path).read(), path, "exec"), ns)
    return types.SimpleNamespace(**{k: v for k, v in ns.items() if k.isupper()})


def run_check(objs, render_dir):
    g = {"__name__": "check"}
    exec(open(CHECK).read(), g)
    # check only the gun meshes (rig copy lives in another collection)
    col = bpy.data.collections.get(objs)
    # the kit check skips names containing "rig" (rig helpers): "Trigger" would be skipped, so rename while checking
    ren = {}
    for o in bpy.data.collections[objs].all_objects:
        if "rig" in o.name.lower() and o.type == "MESH":
            ren[o] = o.name
            o.name = o.name.replace("rigger", "r1gger").replace("Rig", "R1g").replace("rig", "r1g")
    rep = g["run"](collection=objs, render_dir=render_dir)
    for o, n in ren.items():
        o.name = n
    for f in rep["findings"]:
        f["object"] = f["object"].replace("r1gger", "rigger")
    return rep


def build(name):
    spec = load_spec(name)
    blend = os.path.join(ANIM, name + ".blend")
    fbx = os.path.join(ANIM, name + ".fbx")
    man = os.path.join(GUNS, "manifest", name + ".json")
    rdir = os.path.join(GUNS, "renders", name)
    os.makedirs(rdir, exist_ok=True)
    objs, manifest = gunkit.build_gun(spec, blend, fbx, man, rdir, rig_blend=RIG)
    meshes = list(objs.values())
    # renders at the gun's rest frame: detach the rig parent for clean framing
    arm = bpy.data.objects["GunRig_" + name]
    par = arm.parent
    mw = arm.matrix_world.copy()
    arm.parent = None
    from mathutils import Matrix
    arm.matrix_world = Matrix.Identity(4)
    bpy.context.view_layer.update()
    rig_col = bpy.data.collections.get("StarterRig_ref")
    if rig_col:
        for o in rig_col.all_objects:
            o.hide_render = True
    gunkit.render_ortho(meshes, os.path.join(rdir, "side.png"), "right")
    gunkit.render_ortho(meshes, os.path.join(rdir, "left.png"), "left")
    gunkit.render_ortho(meshes, os.path.join(rdir, "top.png"), "top")
    gunkit.render_ortho(meshes, os.path.join(rdir, "persp.png"), "persp", res=(1200, 900))
    off = {}
    for p in spec.PARTS:
        e = getattr(p, "explode", (0, 0, 0))
        if any(e):
            off[objs[p.name]] = Vector((e[2] if len(e) > 2 else 0, e[0], e[1]))
    # children follow their parent's explode (bone hierarchy): add parent offsets
    for p in spec.PARTS:
        par_name = p.parent
        acc = Vector()
        while par_name != "Handle":
            pp = next((q for q in spec.PARTS if q.name == par_name), None)
            if pp is None:
                break
            e = getattr(pp, "explode", (0, 0, 0))
            acc += Vector((e[2] if len(e) > 2 else 0, e[0], e[1]))
            par_name = pp.parent
        if acc.length:
            off[objs[p.name]] = off.get(objs[p.name], Vector()) + acc
    gunkit.render_ortho(meshes, os.path.join(rdir, "exploded.png"), "right", pad=1.08, offsets=off)
    rep = run_check("Gun_" + name, os.path.join(rdir, "check"))
    if rig_col:
        for o in rig_col.all_objects:
            o.hide_render = False
    # a render with the rig holding it (rest pose: arm down, muzzle down)
    arm.parent = par
    if par is not None:
        arm.matrix_parent_inverse = Matrix.Identity(4)
        arm.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    if rig_col:
        allm = [o for o in list(rig_col.all_objects) + meshes if o.type == "MESH"]
        gunkit.render_ortho(allm, os.path.join(rdir, "on_rig.png"), "persp", res=(900, 1100))
    bpy.ops.wm.save_as_mainfile(filepath=blend)
    summary = f"MODEL CHECK {name}: {rep['objects']} objects, {rep['triangles']} tris, {rep['fail']} FAIL, {rep['warn']} WARN"
    print(summary)
    for f in rep["findings"]:
        print(f"  {f['level']:4} {f['code']:5} {f['object']}: {f['message']}")
    json.dump({"summary": summary, "findings": rep["findings"], "renders": rep["renders"], "size": manifest["overall_size_LxHxW"],
               "tris": manifest["total_tris"]}, open(os.path.join(rdir, "check.json"), "w"), indent=1)
    return rep


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    fails = 0
    for n in argv:
        rep = build(n)
        fails += rep["fail"]
    sys.exit(1 if fails else 0)

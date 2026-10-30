"""Roblox-side FBX per gun: meshes only, at rest in Handle space (grip centre at the origin), plus a 10-stud ScaleCube and an
asymmetric Marker 20 studs to the left (delete both after import; measure the cube first: B1/B2).
  blender -b --factory-startup --python art/guns/tools/export_roblox.py -- Pistol [...]
Writes art/guns/fbx/<Gun>_roblox.fbx"""
import bpy, bmesh, os, sys
from mathutils import Matrix, Vector
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))


def one(name):
    bpy.ops.wm.open_mainfile(filepath=os.path.join(ROOT, "art", "anim", "guns", name + ".blend"))
    arm = bpy.data.objects["GunRig_" + name]
    arm.parent = None
    arm.matrix_world = Matrix.Identity(4)
    bpy.context.view_layer.update()
    gcol = bpy.data.collections["Gun_" + name]
    meshes = [o for o in bpy.data.objects if o.type == "MESH" and gcol.name in [c.name for c in o.users_collection]]
    out = bpy.data.collections.new("RobloxExport")
    bpy.context.scene.collection.children.link(out)
    copies = []
    for o in meshes:
        nm = o.name
        o.name = nm + "_src"
        c = bpy.data.objects.new(nm + "_rbx", o.data)
        c.matrix_world = o.matrix_world.copy()
        out.objects.link(c)
        copies.append(c)
    # scale cube (10 studs) and asymmetric L marker, 20 studs to the gun's left
    bm = bmesh.new(); bmesh.ops.create_cube(bm, size=10.0)
    me = bpy.data.meshes.new("ScaleCube"); bm.to_mesh(me); bm.free()
    cube = bpy.data.objects.new("ScaleCube", me); cube.location = (-20, 0, 0); out.objects.link(cube)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    r = bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.translate(bm, verts=r["verts"], vec=Vector((0, 1.5, 0)))   # second block toward the muzzle (+Y)
    r = bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.translate(bm, verts=r["verts"], vec=Vector((0, 0, 1.5)))   # third block up
    me = bpy.data.meshes.new("Marker"); bm.to_mesh(me); bm.free()
    mk = bpy.data.objects.new("Marker", me); mk.location = (-35, 0, 0); out.objects.link(mk)
    for o in bpy.context.scene.objects:
        o.select_set(False)
    for o in copies + [cube, mk]:
        o.select_set(True)
    for o in copies:
        o.name = o.name[:-4]   # original names back on the copies (originals renamed out of the way first)
    path = os.path.join(ROOT, "art", "guns", "fbx", name + "_roblox.fbx")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.fbx(filepath=path, use_selection=True, object_types={"MESH"}, apply_unit_scale=True, global_scale=1.0,
                             mesh_smooth_type="FACE", bake_anim=False, axis_forward="-Z", axis_up="Y")
    print("exported", path, len(copies), "meshes")


argv = sys.argv[sys.argv.index("--") + 1:]
for n in argv:
    one(n)

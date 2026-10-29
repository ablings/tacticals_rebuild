"""Preview renders (Workbench, textures, backface culling ON so a hole or an inside-out face shows the magenta world):
  blender -b art/house/illusion/house_illusion.blend --python art/house/illusion/tools/preview.py
mid_lineup_front / _back: every mid piece in a row with a 5-stud figure; near_*: the near pieces in context with the v2
house shell and v2 exterior appended READ-ONLY (linked data, this file is never saved)."""
import bpy, math, os
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
IROOT = os.path.abspath(os.path.join(HERE, ".."))
OUT = os.path.join(IROOT, "renders")
V2 = os.path.abspath(os.path.join(IROOT, "..", "v2"))
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sh = sc.display.shading
sh.light = "STUDIO"; sh.color_type = "TEXTURE"; sh.show_backface_culling = True; sh.show_shadows = True
sh.show_cavity = False
w = bpy.data.worlds.new("mag"); sc.world = w; w.color = (1.0, 0.0, 1.0); sh.background_type = "WORLD"
sc.render.resolution_x, sc.render.resolution_y = 1800, 900
cam = bpy.data.cameras.new("cam"); cam.lens_unit = "FOV"; cam.clip_end = 20000; cam.clip_start = 0.1
co = bpy.data.objects.new("cam", cam); sc.collection.objects.link(co); sc.camera = co


def shoot(name, loc, target, fov=50):
    co.location = loc
    d = Vector(target) - Vector(loc)
    co.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    cam.angle = math.radians(fov)
    sc.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)


def figure(loc):
    me = bpy.data.meshes.new("fig")
    import bmesh
    bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=(2, 1, 5), verts=bm.verts); bmesh.ops.translate(bm, vec=(0, 0, 2.5), verts=bm.verts)
    bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new("R15_fig", me); sc.collection.objects.link(o); o.location = loc
    return o


far = [o for o in bpy.data.objects if o.name.startswith(("X_Skirt", "X_Mesa"))]
near = [o for o in bpy.data.objects if o.name.startswith(("X_Porch", "X_Back", "X_Drive", "X_Found"))]
mid = [o for o in bpy.data.objects if o.type == "MESH" and o.users_collection and o.users_collection[0].name == "Mid"]
for o in far + near:
    o.hide_render = True
for o in bpy.data.objects:
    if o.name.startswith("K_"):
        o.hide_render = True
# ---- mid lineup on a sand ground
gm = bpy.data.meshes.new("g"); gm.from_pydata([(-400, -300, -0.02), (400, -300, -0.02), (400, 300, -0.02), (-400, 300, -0.02)], [], [(0, 1, 2, 3)])
g = bpy.data.objects.new("ground", gm); sc.collection.objects.link(g)
gmat = bpy.data.materials.new("sand"); gmat.diffuse_color = (0.55, 0.45, 0.32, 1); gm.materials.append(gmat)
order = ["X_TownHouse_A_Butter", "X_TownHouse_B_Salmon", "X_TownHouse_A_Mint", "X_TownHouse_B_White", "X_WaterTower", "X_Bunker",
         "X_Quonset", "X_ObservationStand", "X_ChainLink"]
x = -230.0
for nm in order:
    o = bpy.data.objects[nm]
    wid = o.dimensions.x
    o.location = (x + wid / 2, 0, 0)
    figure((x + wid / 2 + wid / 2 + 3, -8, 0))
    x += wid + 14
pl = bpy.data.objects["X_PoleLine"]; pl.location = (0, 70, 0)
hide = [o for o in mid if o.name not in order and o.name != "X_PoleLine"]
for o in hide:
    o.hide_render = True
sc.display.shading.studio_light = "Default"
shoot("mid_lineup_front", (0, -330, 60), (0, 0, 15), 62)
shoot("mid_lineup_back", (0, 330, 60), (0, 0, 15), 62)
shoot("mid_houses_close", (-150, -95, 22), (-150, 0, 10), 70)
shoot("mid_site_close", (100, -110, 30), (100, 0, 18), 75)
q = bpy.data.objects["X_Quonset"].location; st = bpy.data.objects["X_ObservationStand"].location; wt = bpy.data.objects["X_WaterTower"].location
shoot("mid_quonset_end_close", (q.x + 14, q.y - 62, 6), (q.x, q.y - 40, 9), 60)
shoot("mid_stand_back_close", (st.x + 12, st.y + 26, 9), (st.x, st.y, 6), 60)
shoot("mid_tower_below", (wt.x + 30, wt.y - 30, 3), (wt.x, wt.y, 50), 60)
# ---- near pieces in context (v2 house + exterior appended)
for o in mid + [g] + [o for o in bpy.data.objects if o.name == "R15_fig" or o.name.startswith("R15_fig")]:
    o.hide_render = True
for o in near:
    o.hide_render = False
def append(blend, pred):
    with bpy.data.libraries.load(blend, link=True) as (src, dst):
        dst.objects = [n for n in src.objects if pred(n)]
    for o in dst.objects:
        if o is not None:
            sc.collection.objects.link(o)
append(os.path.join(V2, "house.blend"), lambda n: n.startswith(("Shell_", "Roof_", "Win_", "Door_", "DoorFrame_")))
append(os.path.join(V2, "house_exterior.blend"), lambda n: n.startswith(("Ext_", "Car_", "Dry", "Mast", "Sign", "Power")))
shoot("near_porch_street", (6, -70, 9), (3, -33, 4), 50)
shoot("near_porch_from_FY_window", (2, -30.8, 19.5), (2, -40, 4), 75)
shoot("near_backstoop", (-3, 52, 7), (-3, 33, 1), 50)
shoot("near_driveway_from_DR_window", (18, -30.8, 6.5), (23, -50, -1), 75)
shoot("near_corner_SW", (-44.5, -38.5, 4.0), (-40.5, -31, -0.8), 60)
shoot("near_strip_porch_drive", (12, -42, 5), (12, -31, -0.8), 75)
print("previews in", OUT)

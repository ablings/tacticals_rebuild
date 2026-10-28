# Grader: lays the kit out IN MEMORY as a warehouse bay (map surface colours from fix/map_warehouse2.lua) and renders
# player-height views with Cycles. Read-only: the .blend is never saved.
import bpy, sys, os, math
from mathutils import Vector, Matrix
argv = sys.argv[sys.argv.index("--") + 1:]
outdir, device, samples, light_mode = argv[0], argv[1], int(argv[2]), argv[3]
only = argv[4].split(",") if len(argv) > 4 and argv[4] != "all" else None
os.makedirs(outdir, exist_ok=True)
sc = bpy.context.scene
sc.render.engine = "CYCLES"
prefs = bpy.context.preferences.addons["cycles"].preferences
if device != "CPU":
    prefs.compute_device_type = device
    prefs.get_devices()
    for d in prefs.devices:
        d.use = d.type == device
    sc.cycles.device = "GPU"
else:
    sc.cycles.device = "CPU"
sc.cycles.samples = samples
sc.cycles.use_denoising = True
sc.cycles.max_bounces = 6
sc.view_settings.view_transform = "Standard"
sc.view_settings.look = "None"
sc.render.resolution_x, sc.render.resolution_y, sc.render.resolution_percentage = 1600, 900, 100
sc.render.image_settings.file_format = "PNG"

def lin(c):
    return tuple(((x / 255) / 12.92) if x / 255 <= 0.04045 else (((x / 255) + 0.055) / 1.055) ** 2.4 for x in c)

def mat(name, rgb, rough=0.9, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*lin(rgb), 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    return m

def box(name, x0, x1, y0, y1, z0, z1, m):
    bpy.ops.mesh.primitive_cube_add(size=1, location=((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2))
    o = bpy.context.active_object
    o.name = name
    o.scale = (x1 - x0, y1 - y0, z1 - z0)
    o.data.materials.append(m)
    return o

for o in list(sc.objects):
    if o.name.startswith("K_"):
        o.hide_render = True
kit = bpy.data.collections["Kit"]
groups = {}
for o in list(kit.all_objects):
    if o.type == "MESH":
        groups.setdefault(o.name.split("__")[0], []).append(o)
for o in list(kit.all_objects):
    o.hide_render = True

def place(name, x, y, rot=0.0, z=0.0, copy=False):
    obs = groups[name]
    if copy:
        new = []
        for o in obs:
            c = o.copy()
            sc.collection.objects.link(c)
            new.append(c)
        obs = new
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ Vector(c) for o in obs for c in o.bound_box]
    cx = (min(p.x for p in pts) + max(p.x for p in pts)) / 2
    cy = (min(p.y for p in pts) + max(p.y for p in pts)) / 2
    cz = min(p.z for p in pts)
    M = Matrix.Translation((x, y, z)) @ Matrix.Rotation(math.radians(rot), 4, "Z") @ Matrix.Translation((-cx, -cy, -cz))
    for o in obs:
        o.matrix_world = M @ o.matrix_world
        o.hide_render = False
    return obs

floor_m = mat("g_floor", (128, 127, 123), 0.85)
kick_m = mat("g_kick", (96, 96, 93))
block_m = mat("g_block", (178, 175, 168))
stripe_m = mat("g_stripe", (52, 52, 50))
roof_m = mat("g_roof", (150, 152, 150), 0.6, 0.6)
beam_m = mat("g_beam", (46, 48, 48), 0.5, 0.5)
box("Floor", -34, 34, -34, 30, -1, 0, floor_m)
def wall(x0, x1, y0, y1):
    for nm, z0, z1, m in (("Kick", 0, 1.2, kick_m), ("Block", 1.2, 4.0, block_m), ("Stripe", 4.0, 4.6, stripe_m), ("Up", 4.6, 18, block_m)):
        box("W" + nm, x0, x1, y0, y1, z0, z1, m)
wall(-31.5, -30, -34, 30)
wall(30, 31.5, -34, 30)
for nm, z0, z1, m in (("Kick", 0, 1.2, kick_m), ("Block", 1.2, 4.0, block_m), ("Stripe", 4.0, 4.6, stripe_m), ("Up", 4.6, 18, block_m)):
    box("BL" + nm, -31.5, -10.6, 26, 27.5, z0, z1, m)
    box("BR" + nm, 10.6, 31.5, 26, 27.5, z0, z1, m)
box("BHead", -10.6, 10.6, 26, 27.5, 14, 18, block_m)
box("Roof", -34, 34, -34, 30, 18, 18.5, roof_m)
for y in (-18, -2, 14):
    box("Beam", -30, 30, y - 0.3, y + 0.3, 13.0, 14.3, beam_m)
box("Yard", -12, 12, 27.5, 60, -1, 0, mat("g_yard", (122, 121, 117)))
box("YardBack", -40, 40, 60, 61, 0, 30, mat("g_yardback", (20, 22, 26)))

L = [("W2_Cover_Wall", 0, 10, 0), ("W2_Cover_Low", -8, 2, 0), ("W2_Cover_Low", 8.5, 3, 8, True), ("W2_Cover_Low", -1, -6, 0, True),
     ("W2_Cover_Tall", -14, 12, 5), ("W2_Cover_TallPly", 14, 12, -4), ("W2_FireBarrel", 4.4, -1.4, 30),
     ("W2_OilDrum_Grey", -24.5, 19, 0), ("W2_OilDrum_Black", -22.2, 19.4, 40), ("W2_AmmoCan", -4.4, -1.4, 18),
     ("W2_AmmoCan", 2.2, 6.2, -12, True), ("W2_PalletSacks", 7.5, 17, -8), ("W2_SupplyCrate", -19.5, 15, 0),
     ("W2_Pallet", 21, 18, 80), ("W2_Workbench", -28.6, 4, 90), ("W2_ShelfRack", 28.6, 6, 90), ("W2_TyreStack", 23, -3, 0),
     ("W2_Forklift", 16, 22.5, 100), ("W2_FireBarrel_Burnt", -19, -5, 0), ("W2_LongCrate", -20, 22, 0),
     ("W2_SteelCrate", 22, 10.5, 90)]
for e in L:
    place(e[0], e[1], e[2], e[3], 0.0, e[4] if len(e) > 4 else False)
door = place("W2_RollDoor_HalfOpen", 0, 26 - 1.1, 180)
LAMPS = [(-15, -10), (0, -10), (15, -10), (-15, 6), (0, 6), (15, 6), (-15, 20), (15, 20)]
for i, (x, y) in enumerate(LAMPS):
    place("W2_HighBayLamp", x, y, 0, 8.25, i > 0)

world = bpy.data.worlds.new("g_world")
world.use_nodes = True
bg = world.node_tree.nodes["Background"]
sc.world = world
warm = (1.0, 238 / 255, 214 / 255)
if light_mode == "night":
    bg.inputs["Color"].default_value = (*lin((16, 17, 20)), 1)
    bg.inputs["Strength"].default_value = 1.0
    for (x, y) in LAMPS:
        ld = bpy.data.lights.new("g_spot", "SPOT")
        ld.energy, ld.color, ld.spot_size, ld.spot_blend, ld.shadow_soft_size = 3200, warm, math.radians(110), 0.6, 0.8
        lo = bpy.data.objects.new("g_spot", ld)
        lo.location = (x, y, 8.0)
        sc.collection.objects.link(lo)
        pd = bpy.data.lights.new("g_pt", "POINT")
        pd.energy, pd.color, pd.shadow_soft_size = 900, warm, 0.5
        po = bpy.data.objects.new("g_pt", pd)
        po.location = (x, y, 7.9)
        sc.collection.objects.link(po)
else:
    bg.inputs["Color"].default_value = (0.8, 0.8, 0.8, 1)
    bg.inputs["Strength"].default_value = 0.35
    for (x, y) in [(-15, -10), (15, -10), (-15, 10), (15, 10), (0, 0)]:
        ad = bpy.data.lights.new("g_area", "AREA")
        ad.energy, ad.color, ad.size = 9000, (1, 1, 1), 10
        ao = bpy.data.objects.new("g_area", ad)
        ao.location = (x, y, 17)
        sc.collection.objects.link(ao)

cam_d = bpy.data.cameras.new("g_cam")
cam_d.lens_unit = "FOV"
cam_d.angle = math.radians(70)
cam = bpy.data.objects.new("g_cam", cam_d)
sc.collection.objects.link(cam)
sc.camera = cam
views = {
    "hall_spawn_eye": ((0, -24, 5.0), (0, 8, 2.5)),
    "wall_10": ((3, -0.5, 5.0), (0, 10, 3.0)),
    "barrel_10": ((10, -8, 5.0), (3.5, -0.5, 1.8)),
    "tall_15": ((0, -2, 5.0), (-14, 12, 3.5)),
    "ply_10": ((12, 2, 5.0), (14, 12, 3.5)),
    "lowcover_10": ((-10, -10, 5.0), (-6, 1.5, 1.7)),
    "third_person_20": ((-6, -18, 8.0), (0, 2, 2.0)),
    "clutter_west_15": ((-12, 0, 5.0), (-25, 12, 2.0)),
    "clutter_east_15": ((12, 0, 5.0), (24, 14, 2.5)),
    "door_20": ((0, 2, 5.0), (0, 26, 7.0)),
    "drums_burnt_12": ((-12, 4, 5.0), (-21, 14, 1.5)),
    "bench_10": ((-19, 0, 5.0), (-28.6, 4, 3.0)),
    "forklift_sacks_15": ((4, 6, 5.0), (14, 20, 2.5)),
    "burnt_8": ((-13, -10, 5.0), (-19, -5, 1.2)),
}
for name, (pos, tgt) in views.items():
    if only and name not in only:
        continue
    cam.location = Vector(pos)
    cam.rotation_euler = (Vector(tgt) - Vector(pos)).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = os.path.join(outdir, light_mode + "_" + name + ".png")
    bpy.ops.render.render(write_still=True)
    print("RENDERED", sc.render.filepath)

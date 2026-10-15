"""Eevee previews for rooms2 (Shop, Armory, corridors). exec() in Blender after rooms2_kit.py. Studio coords for cameras.
Lights: warm area lights under every lamp strip (SurfaceLight role) + warm points at the RoomLight homes."""
import bpy, math
from mathutils import Vector

ROOT = r"C:/Users/aroki/Documents/tacticals_rebuild"
OUTD = ROOT + "/out/rooms2/"

def sb(p):
    return Vector((-p[0], p[2], p[1]))

def _light(kind, name, loc, energy, color=(1.0, 0.93, 0.82), **kw):
    l = bpy.data.lights.new(name, kind); l.energy = energy; l.color = color
    for k, v in kw.items():
        setattr(l, k, v)
    o = bpy.data.objects.new(name, l); bpy.context.scene.collection.objects.link(o)
    o.location = sb(loc)
    return o

def setup():
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x, sc.render.resolution_y = 1440, 810
    sc.render.resolution_percentage = 100
    ee = sc.eevee
    for k, v in (("use_raytracing", True), ("taa_render_samples", 32), ("use_shadows", True)):
        try:
            setattr(ee, k, v)
        except Exception:
            pass
    sc.view_settings.view_transform = "AgX"
    sc.view_settings.exposure = 0.0
    w = bpy.data.worlds.get("HubSky") or bpy.data.worlds.new("HubSky")
    sc.world = w; w.use_nodes = True
    nt = w.node_tree; N = nt.nodes
    for n in list(N):
        if n.type != "OUTPUT_WORLD":
            N.remove(n)
    out = [n for n in N if n.type == "OUTPUT_WORLD"][0]
    bg = N.new("ShaderNodeBackground"); bg.inputs["Color"].default_value = (0.62, 0.60, 0.55, 1); bg.inputs["Strength"].default_value = 0.75
    nt.links.new(bg.outputs[0], out.inputs["Surface"])
    for ob in list(bpy.data.objects):
        if ob.name.startswith("PV_"):
            bpy.data.objects.remove(ob, do_unlink=True)
    _light("SUN", "PV_Sun", (0, 200, 0), 3.0, (1.0, 0.85, 0.72), angle=math.radians(6)).rotation_euler = (math.radians(28), math.radians(12), math.radians(35))
    # shop strips (y 12.8) and armory strips (y 21.3): one area light per strip column per room
    for x in (-25.0, -15.0, -5.0, 5.0, 15.0, 25.0):
        o = _light("AREA", "PV_ShopFill", (x, 12.6, 89.75), 2200, shape="RECTANGLE", size=1.2, size_y=36)
        o.rotation_euler = (0, 0, 0)
        o = _light("AREA", "PV_ArmFill", (x * 1.03, 21.1, -89.75), 6500, shape="RECTANGLE", size=1.2, size_y=40)
    for (x, y, z, e) in ((0, 12.2, 97, 900), (22, 12.2, 86, 700), (-17.5, 12.2, 85, 700), (0, 12.2, 74, 700),
                         (-10, 18.3, -96, 6000), (0, 13.6, -90, 2500), (12, 5.9, -83, 300), (20, 5.9, -87.5, 300), (-6, 17, -106, 2500)):
        if z == -96:
            o = _light("SPOT", "PV_Spot", (x, y, z), e, (1.0, 0.89, 0.68), spot_size=math.radians(50))
        else:
            _light("POINT", "PV_Pt", (x, y, z), e, (1.0, 0.92, 0.80), shadow_soft_size=0.6)
    for (z, e) in ((56.5, 900), (-56.5, 900)):
        _light("AREA", "PV_Corr", (0, 12.3, z), e, shape="RECTANGLE", size=1.0, size_y=14)
    # hub fill so the gate side of the corridor shots is not black
    for zz in (-24.0, 24.0):
        for xx in (-20.0, 20.0):
            _light("AREA", "PV_Hub", (xx, 62.5, zz), 9000, shape="RECTANGLE", size=30, size_y=3)
    c = bpy.data.collections.get("R2_Markers")
    if c:
        c.hide_render = True
    cam = bpy.data.cameras.new("PV_Cam"); cam.lens = 18
    co = bpy.data.objects.new("PV_Cam", cam); bpy.context.scene.collection.objects.link(co)
    sc.camera = co
    return co

def shot(name, eye, look, lens=18):
    co = bpy.context.scene.camera
    co.data.lens = lens
    co.data.clip_start = 0.1
    co.location = sb(eye)
    d = sb(look) - sb(eye)
    co.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.render.filepath = OUTD + f"bl_{name}.png"
    bpy.ops.render.render(write_still=True)
    return bpy.context.scene.render.filepath

SHOTS = {
    "shop_entry":     ((0, 6, 70.5), (0, 4, 105), 16),
    "shop_counter":   ((-12, 5.5, 90), (6, 3, 106), 18),
    "shop_west":      ((10, 6, 79), (-30, 4, 92), 18),
    "shop_east":      ((-8, 6, 78), (30, 4, 92), 18),
    "shop_plinth":    ((6, 5, 79), (0, 2.5, 88), 22),
    "shop_back":      ((0, 7, 92), (0, 6, 70), 16),
    "corr_north":     ((0, 6, 32), (0, 5, 80), 18),
    "armory_entry":   ((0, 7, -68.5), (-4, 5, -108), 16),
    "armory_gunwall": ((-6, 7, -95), (-6, 7, -112.5), 18),
    "armory_dais":    ((1, 7, -85), (-10, 2.5, -96), 22),
    "armory_supply":  ((-1, 6, -95), (12, 4, -110), 18),
    "armory_benches": ((2, 7, -96), (20, 3, -82), 18),
    "armory_west":    ((-14, 6, -80), (-31, 4, -92), 18),
    "armory_high":    ((28, 19, -70), (-10, 0, -100), 14),
    "corr_south":     ((0, 6, -32), (0, 5, -80), 18),
}

def render_all(names=None):
    out = []
    for k, (e, l, lens) in SHOTS.items():
        if names and k not in names:
            continue
        out.append(shot(k, e, l, lens))
    return out

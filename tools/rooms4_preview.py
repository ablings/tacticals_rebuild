"""Eevee previews for rooms4 (Showroom). exec() in Blender after rooms4_kit.py. Studio coords for cameras.
PV_ objects (lights, camera, the grey item proxy on DisplayPoint) are preview-only and never exported.
bl_cam = the Kit-menu view: CameraPoint (0, 407.5, -5) looking at DisplayPoint (0, 406, 8), vertical FOV 40 (Armory.lua tr.reveal fov 40)."""
import bpy, math
from mathutils import Vector

ROOT = r"C:/Users/aroki/Documents/tacticals_rebuild"
OUTD = ROOT + "/out/rooms4/"

def sb(p):
    return Vector((-p[0], p[2], p[1]))

def _light(kind, name, loc, energy, color=(1.0, 0.93, 0.82), **kw):
    l = bpy.data.lights.new(name, kind); l.energy = energy; l.color = color
    for k, v in kw.items():
        setattr(l, k, v)
    o = bpy.data.objects.new(name, l); bpy.context.scene.collection.objects.link(o)
    o.location = sb(loc)
    return o

def _pmat(name, rgb, rough=0.5, metal=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*rgb, 1); b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    return m

def proxies():
    c = bpy.data.collections.get("PV_Proxies")
    if c:
        for o in list(c.objects):
            bpy.data.objects.remove(o, do_unlink=True)
    else:
        c = bpy.data.collections.new("PV_Proxies"); bpy.context.scene.collection.children.link(c)
    m = _pmat("PV_item", (0.05, 0.05, 0.05), 0.35, 0.6)
    # stand-in item (rifle-sized, ~7 studs long like SHOW_FIT 7.5) centred on DisplayPoint, angled like the icon view
    for (sz, off) in (((6.6, 1.0, 0.45), (0, 0, 0)), ((1.2, 1.4, 0.35), (-1.6, -0.9, 0)), ((0.6, 1.3, 0.3), (0.6, -0.9, 0)), ((1.6, 0.5, 0.4), (-0.6, 0.75, 0))):
        me = bpy.data.meshes.new("PV_item")
        import bmesh
        bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1.0); bm.to_mesh(me); bm.free()
        me.materials.append(m)
        o = bpy.data.objects.new("PV_item", me); c.objects.link(o)
        o.scale = (sz[0], sz[2], sz[1])
        o.location = sb((0.0 - off[0], 406.0 + off[1], 8.0 + off[2]))
        o.rotation_euler = (0, 0, math.radians(-12))
    return c

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
    bg = N.new("ShaderNodeBackground"); bg.inputs["Color"].default_value = (0.42, 0.62, 0.85, 1); bg.inputs["Strength"].default_value = 0.25
    nt.links.new(bg.outputs[0], out.inputs["Surface"])
    for ob in list(bpy.data.objects):
        if ob.name.startswith("PV_") and ob.type in ("LIGHT", "CAMERA"):
            bpy.data.objects.remove(ob, do_unlink=True)
    # Showroom lights at the real light Parts: Pendant1-4, Fill, KeyLight + ceiling strips + bay slots
    for (x, y, z) in ((4.0, 413.4, 8.5), (-4.0, 413.4, 8.5), (-20.0, 413.4, 12.0), (20.0, 413.4, 11.0)):
        _light("SPOT", "PV_Pendant", (x, y, z), 900, (1.0, 0.94, 0.82), spot_size=math.radians(90), shadow_soft_size=0.6)
    _light("AREA", "PV_Fill", (0.0, 418.4, 18.0), 1500, shape="RECTANGLE", size=3, size_y=1.2)
    k = _light("SPOT", "PV_Key", (-3.0, 414.6, -1.0), 2500, (1.0, 0.95, 0.86), spot_size=math.radians(55), shadow_soft_size=0.5)
    k.rotation_euler = (sb((0, 406, 8)) - sb((-3.0, 414.6, -1.0))).to_track_quat("-Z", "Y").to_euler()
    for x in (-21.0, 21.0):
        _light("AREA", "PV_Strip", (x, 426.2, 8.0), 1800, shape="RECTANGLE", size=1.2, size_y=50)
    for x in (-9.9, 9.9):
        a = _light("AREA", "PV_Slot", (x, 409.0, 32.2), 500, shape="RECTANGLE", size=0.5, size_y=15.5)
        a.rotation_euler = (math.radians(90), 0, 0)
    for (x, z) in ((-12.2, 31.4), (12.2, 31.4), (-31 + 1.6, 0.0), (31 - 1.6, 0.0), (-29.4, 18.0), (29.4, 18.0)):
        _light("POINT", "PV_Cap", (x, 414.2, z), 250, (1.0, 0.9, 0.78), shadow_soft_size=0.6)
    for c in ("R4_Markers", "R4_Clip", "R4_Training", "R4_Cover"):
        cc = bpy.data.collections.get(c)
        if cc:
            cc.hide_render = True
    proxies()
    cam = bpy.data.cameras.new("PV_Cam")
    co = bpy.data.objects.new("PV_Cam", cam); bpy.context.scene.collection.objects.link(co)
    sc.camera = co
    return co

def shot(name, eye, look, lens=None, vfov=None):
    co = bpy.context.scene.camera
    if vfov:
        co.data.sensor_fit = "VERTICAL"; co.data.lens_unit = "FOV"; co.data.angle = math.radians(vfov)
    else:
        co.data.sensor_fit = "AUTO"; co.data.lens_unit = "MILLIMETERS"; co.data.lens = lens or 18
    co.data.clip_start = 0.1
    co.data.clip_end = 2000
    co.location = sb(eye)
    d = sb(look) - sb(eye)
    co.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.render.filepath = OUTD + f"bl_{name}.png"
    bpy.ops.render.render(write_still=True)
    return bpy.context.scene.render.filepath

SHOTS = {
    "cam":        ((0.0, 407.5, -5.0), (0.0, 406.0, 8.0), None, 40),     # the Kit-menu camera (game FOV)
    "cam_wide":   ((0.0, 407.5, -5.0), (0.0, 406.0, 8.0), None, 70),     # same camera at 70 deg (survey capture FOV)
    "overview":   ((26.0, 421.0, -16.0), (0.0, 404.0, 16.0), 16, None),
    "backdrop":   ((-9.0, 406.0, 14.0), (2.0, 409.0, 33.0), 18, None),
    "bench":      ((9.0, 407.0, 0.0), (0.0, 403.5, 8.5), 22, None),
    "rack":       ((8.0, 405.5, 20.0), (19.0, 403.0, 31.0), 18, None),
}

def render_all(names=None):
    out = []
    for k, (e, l, lens, vfov) in SHOTS.items():
        if names and k not in names:
            continue
        out.append(shot(k, e, l, lens, vfov))
    return out

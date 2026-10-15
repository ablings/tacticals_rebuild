"""Eevee previews for rooms3 (Duels hall + west deck, Exfil hangar + pad). exec() in Blender after rooms3_kit.py.
Studio coords for cameras. Adds grey PV_ proxies of the hook parts (pad plates + posts + Holo, heli, ExfilBarrier) that are
NOT exported (they live in the PV_Proxies collection), so previews show what the kit dresses around."""
import bpy, math
from mathutils import Vector

ROOT = r"C:/Users/aroki/Documents/tacticals_rebuild"
OUTD = ROOT + "/out/rooms3/"

def sb(p):
    return Vector((-p[0], p[2], p[1]))

def _light(kind, name, loc, energy, color=(1.0, 0.93, 0.82), **kw):
    l = bpy.data.lights.new(name, kind); l.energy = energy; l.color = color
    for k, v in kw.items():
        setattr(l, k, v)
    o = bpy.data.objects.new(name, l); bpy.context.scene.collection.objects.link(o)
    o.location = sb(loc)
    return o

def _pmat(name, rgb, alpha=1.0, emit=0.0):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*rgb, 1); b.inputs["Roughness"].default_value = 0.6
    b.inputs["Alpha"].default_value = alpha
    if emit:
        b.inputs["Emission Color"].default_value = (*rgb, 1); b.inputs["Emission Strength"].default_value = emit
    try:
        m.surface_render_method = "BLENDED" if alpha < 1 else "DITHERED"
    except Exception:
        pass
    return m

def _pbox(coll, name, a, b, mat):
    a = Vector(a); b = Vector(b)
    me = bpy.data.meshes.new(name)
    lo = Vector((min(a.x, b.x), min(a.y, b.y), min(a.z, b.z))); hi = Vector((max(a.x, b.x), max(a.y, b.y), max(a.z, b.z)))
    vs = [(-x, z, y) for x in (lo.x, hi.x) for y in (lo.y, hi.y) for z in (lo.z, hi.z)]
    fs = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    me.from_pydata(vs, [], fs); me.materials.append(mat)
    o = bpy.data.objects.new(name, me); coll.objects.link(o)

def proxies():
    c = bpy.data.collections.get("PV_Proxies")
    if c:
        for o in list(c.objects):
            bpy.data.objects.remove(o, do_unlink=True)
    else:
        c = bpy.data.collections.new("PV_Proxies"); bpy.context.scene.collection.children.link(c)
    plate1 = _pmat("PV_plate1", (0.16, 0.16, 0.155)); plate2 = _pmat("PV_plate2", (0.12, 0.13, 0.08))
    holo = _pmat("PV_holo", (0.6, 0.6, 0.55), 0.6, 2.0); heli = _pmat("PV_heli", (0.08, 0.1, 0.06))
    bar = _pmat("PV_barrier", (0.75, 0.8, 0.7), 0.25, 0.5)
    import sys
    g = bpy.app.driver_namespace.get("R3") or {}
    pads = g.get("PADS", [])
    for name, (x0, x1, z0, z1), ax, split, t1, post in pads:
        if ax == "z":
            c1 = (x0 + 1, split, z1 - 1) if t1 > 0 else (x0 + 1, z0 + 1, split)
            _pbox(c, f"PV_{name}_T1", (x0 + 1, 16.0, split if t1 > 0 else z0 + 1), (x1 - 1, 16.3, z1 - 1 if t1 > 0 else split), plate1)
            _pbox(c, f"PV_{name}_T2", (x0 + 1, 16.0, z0 + 1 if t1 > 0 else split), (x1 - 1, 16.3, split if t1 > 0 else z1 - 1), plate2)
        else:
            _pbox(c, f"PV_{name}_T1", (split, 16.0, z0 + 1), (x1 - 1, 16.3, z1 - 1), plate1)
            _pbox(c, f"PV_{name}_T2", (x0 + 1, 16.0, z0 + 1), (split, 16.3, z1 - 1), plate2)
        px, pz = (post[0] + post[1]) / 2, (post[2] + post[3]) / 2
        _pbox(c, f"PV_{name}_Board", (px - 0.05, 24.1, pz - 5.5), (px + 0.05, 30.1, pz + 5.5), holo) if ax == "x" and False else None
    # heli proxy (survey bounds): fuselage along z, tail boom, rotor disc
    _pbox(c, "PV_Heli_body", (129.0, 0.8, -12.0), (136.0, 7.5, 7.0), heli)
    _pbox(c, "PV_Heli_tail", (131.8, 6.0, 7.0), (133.2, 8.0, 21.0), heli)
    _pbox(c, "PV_Heli_fin", (132.2, 7.0, 20.0), (132.8, 10.5, 23.0), heli)
    _pbox(c, "PV_Heli_skidL", (129.0, 0.0, -9.0), (129.6, 0.6, 4.0), heli)
    _pbox(c, "PV_Heli_skidR", (135.4, 0.0, -9.0), (136.0, 0.6, 4.0), heli)
    _pbox(c, "PV_Heli_rotor1", (119.0, 10.0, -0.4), (147.0, 10.2, 0.4), heli)
    _pbox(c, "PV_Heli_rotor2", (132.6, 10.0, -14.0), (133.4, 10.2, 14.0), heli)
    _pbox(c, "PV_ExfilBarrier", (127.35, 0.0, -12.0), (127.65, 13.2, 12.0), bar)
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
    bg = N.new("ShaderNodeBackground"); bg.inputs["Color"].default_value = (0.42, 0.62, 0.85, 1); bg.inputs["Strength"].default_value = 0.9
    nt.links.new(bg.outputs[0], out.inputs["Surface"])
    for ob in list(bpy.data.objects):
        if ob.name.startswith("PV_") and ob.type in ("LIGHT", "CAMERA"):
            bpy.data.objects.remove(ob, do_unlink=True)
    _light("SUN", "PV_Sun", (0, 200, 0), 3.2, (1.0, 0.86, 0.74), angle=math.radians(6)).rotation_euler = (math.radians(30), math.radians(14), math.radians(40))
    # Duels: ring lamp strips + truss floods + wall capsules
    for x in (-135.5, -99.5):
        _light("AREA", "PV_DRing", (x, 65.0, 0.0), 9000, shape="RECTANGLE", size=1.5, size_y=60)
    for z in (-40.5, 40.5):
        _light("AREA", "PV_DRing", (-117.5, 65.0, z), 9000, shape="RECTANGLE", size=40, size_y=1.5)
    for x in (-124.5, -117.5, -110.5):
        for z in (-18.0, -6.0, 6.0, 18.0):
            _light("SPOT", "PV_DFlood", (x, 61.4, z), 9000, (1.0, 0.92, 0.80), spot_size=math.radians(70)).rotation_euler = (0, 0, 0)
    for (x, z) in ((-106.25, 43.0), (-117.5, 43.0), (-128.75, 43.0), (-106.25, -43.0), (-117.5, -43.0), (-128.75, -43.0), (-97.0, 37.5), (-97.0, -37.5), (-138.0, 26.0), (-138.0, -26.0)):
        _light("POINT", "PV_DCap", (x, 30.2, z), 900, (1.0, 0.9, 0.78), shadow_soft_size=1.0)
    _light("AREA", "PV_Pass", (-148.5, 28.1, 0.0), 700, shape="RECTANGLE", size=12, size_y=1.0)
    # Exfil: hangar lamp strips, L_Hangar, pier capsules
    for x in (107.5, 119.0, 124.0):
        _light("AREA", "PV_HStrip", (x, 19.3, 0.0), 2600, shape="RECTANGLE", size=1.2, size_y=48)
    _light("POINT", "PV_LHangar", (114.0, 19.0, 0.0), 1800, (1.0, 0.9, 0.76), shadow_soft_size=0.8)
    for (x, z) in ((110.0, 25.0), (116.0, 25.0), (110.0, -25.0), (116.0, -25.0)):
        _light("POINT", "PV_HCap", (x, 13.0, z), 300, (1.0, 0.9, 0.78), shadow_soft_size=0.6)
    _light("POINT", "PV_LPad", (133.0, 24.0, 0.0), 6000, (1.0, 0.92, 0.82), shadow_soft_size=1.0)
    for c in ("R3_Markers", "R3_Clip"):
        cc = bpy.data.collections.get(c)
        if cc:
            cc.hide_render = True
    proxies()
    cam = bpy.data.cameras.new("PV_Cam"); cam.lens = 18
    co = bpy.data.objects.new("PV_Cam", cam); bpy.context.scene.collection.objects.link(co)
    sc.camera = co
    return co

def shot(name, eye, look, lens=18):
    co = bpy.context.scene.camera
    co.data.lens = lens
    co.data.clip_start = 0.1
    co.data.clip_end = 2000
    co.location = sb(eye)
    d = sb(look) - sb(eye)
    co.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.render.filepath = OUTD + f"bl_{name}.png"
    bpy.ops.render.render(write_still=True)
    return bpy.context.scene.render.filepath

SHOTS = {
    "duels_entry":   ((-97.5, 22.5, 0.0), (-140, 22, 0), 16),
    "duels_pads_n":  ((-110, 23, -22), (-118, 17, 38), 16),
    "duels_1v1":     ((-122, 21.5, -3), (-97, 18, 18), 18),
    "duels_2v2":     ((-108, 21.5, 2), (-136, 18, -22), 18),
    "duels_high":    ((-98, 52, -42), (-124, 16, 12), 14),
    "duels_west":    ((-108, 23, 12), (-140, 30, -6), 16),
    "duels_roof":    ((-117, 20, -24), (-117, 68, 10), 14),
    "deck":          ((-158, 22, 18), (-200, 17, -12), 16),
    "deck_back":     ((-196, 23, -22), (-140, 30, 10), 16),
    "hangar_entry":  ((106.8, 6, 0), (140, 4, 0), 16),
    "hangar_north":  ((119, 6, 4), (106, 4, 26), 16),
    "hangar_south":  ((123, 7, 6), (104, 3, -26), 16),
    "exfil_cutcam":  ((120, 9, -18), (133, 4, 2), 14.5),
    "pad":           ((146.5, 8, 13), (126, 4, -14), 16),
    "pad_edge":      ((140, 7, 12), (152, 3, -24), 16),
    "exfil_high":    ((165, 42, -50), (125, 0, 5), 16),
}

def render_all(names=None):
    out = []
    for k, (e, l, lens) in SHOTS.items():
        if names and k not in names:
            continue
        out.append(shot(k, e, l, lens))
    return out

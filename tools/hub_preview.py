"""Eevee preview renders for the hub1 kit. exec() in Blender after hub_kit.py. Studio coords for cameras."""
import bpy, math, os
from mathutils import Vector

ROOT = r"C:/Users/aroki/Documents/tacticals_rebuild"
OUTD = ROOT + "/out/hub1/"

def sb(p):  # studio -> blender
    return Vector((-p[0], p[2], p[1]))

def setup():
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x, sc.render.resolution_y = 1600, 900
    sc.render.resolution_percentage = 100
    ee = sc.eevee
    for k, v in (("use_raytracing", True), ("taa_render_samples", 48), ("use_shadows", True), ("fast_gi_method", "GLOBAL_ILLUMINATION")):
        try:
            setattr(ee, k, v)
        except Exception:
            pass
    try:
        ee.ray_tracing_options.resolution_scale = "2"
    except Exception:
        pass
    sc.view_settings.view_transform = "AgX"
    sc.view_settings.look = "AgX - Base Contrast" if "AgX - Base Contrast" in [i.identifier for i in sc.view_settings.bl_rna.properties["look"].enum_items] else "None"
    sc.view_settings.exposure = 0.0
    # world: RIVALS atmosphere blue sky, bright ambient
    w = bpy.data.worlds.get("HubSky") or bpy.data.worlds.new("HubSky")
    sc.world = w; w.use_nodes = True
    nt = w.node_tree; N = nt.nodes
    for n in list(N):
        if n.type not in ("OUTPUT_WORLD",):
            N.remove(n)
    out = [n for n in N if n.type == "OUTPUT_WORLD"][0]
    sky = N.new("ShaderNodeBackground"); sky.inputs["Color"].default_value = (0.26, 0.55, 0.80, 1); sky.inputs["Strength"].default_value = 1.4
    amb = N.new("ShaderNodeBackground"); amb.inputs["Color"].default_value = (0.62, 0.60, 0.55, 1); amb.inputs["Strength"].default_value = 0.9
    lp = N.new("ShaderNodeLightPath"); mx = N.new("ShaderNodeMixShader")
    nt.links.new(lp.outputs["Is Camera Ray"], mx.inputs[0])
    nt.links.new(amb.outputs[0], mx.inputs[1]); nt.links.new(sky.outputs[0], mx.inputs[2])
    nt.links.new(mx.outputs[0], out.inputs["Surface"])
    # warm sun (ColorShift_Top 255,217,184) high noon-ish, angled to come through the skylight
    for ob in list(bpy.data.objects):
        if ob.name.startswith("PV_"):
            bpy.data.objects.remove(ob, do_unlink=True)
    sun = bpy.data.lights.new("PV_Sun", "SUN"); sun.energy = 4.5; sun.color = (1.0, 0.85, 0.72); sun.angle = math.radians(6)
    so = bpy.data.objects.new("PV_Sun", sun); bpy.context.scene.collection.objects.link(so)
    so.rotation_euler = (math.radians(28), math.radians(12), math.radians(35))
    # fill: area lights under the ceiling strips and catwalks (SurfaceLight role), warm white
    for zz in (-24.0, 24.0):
        for xx in (-60.0, -20.0, 20.0, 60.0):
            l = bpy.data.lights.new("PV_Fill", "AREA"); l.shape = "RECTANGLE"; l.size = 30; l.size_y = 3; l.energy = 9000
            l.color = (1.0, 0.93, 0.82)
            o = bpy.data.objects.new("PV_Fill", l); bpy.context.scene.collection.objects.link(o)
            o.location = sb((xx, 62.5, zz))
    for zz in (-38.0, 38.0):
        for xx in (-60.0, -20.0, 20.0, 60.0):
            l = bpy.data.lights.new("PV_Low", "AREA"); l.shape = "RECTANGLE"; l.size = 30; l.size_y = 2; l.energy = 2500
            l.color = (1.0, 0.92, 0.80)
            o = bpy.data.objects.new("PV_Low", l); bpy.context.scene.collection.objects.link(o)
            o.location = sb((xx, 28.5, zz))
    # shadowed warm spot on the spawn disc (truss spot role)
    sp = bpy.data.lights.new("PV_Spot", "SPOT"); sp.energy = 60000; sp.spot_size = math.radians(40); sp.color = (1.0, 0.89, 0.68)
    o = bpy.data.objects.new("PV_Spot", sp); bpy.context.scene.collection.objects.link(o)
    o.location = sb((0, 60, 0)); o.rotation_euler = (0, 0, 0)
    # hide the origin kit and markers from the hall renders
    for cn in ("Kit_Origin", "Markers"):
        c = bpy.data.collections.get(cn)
        if c:
            c.hide_render = True; c.hide_viewport = True
    cam = bpy.data.cameras.new("PV_Cam"); cam.lens = 18
    co = bpy.data.objects.new("PV_Cam", cam); bpy.context.scene.collection.objects.link(co)
    sc.camera = co
    return co

def shot(name, eye, look, lens=18):
    co = bpy.context.scene.camera
    co.data.lens = lens
    co.location = sb(eye)
    d = sb(look) - sb(eye)
    co.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.render.filepath = OUTD + f"bl_{name}.png"
    bpy.ops.render.render(write_still=True)
    return bpy.context.scene.render.filepath

SHOTS = {
    "hall_east":   ((-60, 6, -8), (60, 14, 4), 16),
    "hall_west":   ((70, 7, 10), (-80, 14, -2), 16),
    "gate_north":  ((8, 5.5, -10), (0, 12, 44), 18),
    "wall_bays":   ((10, 6, -22), (40, 16, -44), 18),
    "stairs_west": ((-50, 8, -18), (-86, 12, 6), 18),
    "tunnel_east": ((55, 6, -12), (92, 9, 0), 18),
    "spawn_disc":  ((14, 9, -16), (0, 0, 0), 24),
    "catwalk":     ((-20, 33, 37.5), (40, 30, 30), 16),
    "ceiling":     ((0, 4, -30), (10, 60, 10), 14),
    "overview":    ((-70, 58, -36), (10, 0, 10), 16),
}

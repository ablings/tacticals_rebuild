"""Sky-leak check (rays that land on the v2 ground square |x|,|y| <= 900 at z -1 count as covered) for the far field (run on the built .blend):
  blender -b art/house/illusion/house_illusion.blend --python art/house/illusion/tools/check_far.py -- [--render]
From each window eye point, for every azimuth (0.25 deg) cast rays from -3 deg up to 14 deg (0.05 deg): the skyline is the
highest hit; every ray below it must hit far geometry (skirt or a tier). Any miss = sky visible below a ridge. Only the
far field is loaded (no v2 ground, no v2 mesas), so this is the strict case. Also reports which tier makes the skyline
per azimuth and the largest single-tier stretch of the skyline. --render: 8 panorama frames per eye on magenta."""
import bpy, math, sys, os, json
from mathutils import Vector
from mathutils.bvhtree import BVHTree
import bmesh

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.abspath(os.path.join(HERE, "..")), "renders")
ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
EYES = {"FY_S_up": (2.0, -31.6, 19.5), "LR_S_ground": (-20.0, -31.6, 5.0), "DR_E_ground": (41.6, -22.0, 5.0),
        "BR3_W_up": (-41.6, 14.0, 19.5), "BR3_N_up": (-30.0, 31.6, 19.5), "BR2_E_up": (41.6, -20.0, 19.5),
        "crouch_KT_E": (41.6, 15.0, 2.5)}

objs = [o for o in bpy.data.objects if o.type == "MESH" and (o.name.startswith("X_Skirt") or o.name.startswith("X_Mesa"))]
bm = bmesh.new()
tier_of_face = []
for o in objs:
    n0 = len(bm.faces)
    tmp = bmesh.new(); tmp.from_mesh(o.data); tmp.transform(o.matrix_world)
    me = bpy.data.meshes.new("tmp"); tmp.to_mesh(me); tmp.free()
    bm.from_mesh(me); bpy.data.meshes.remove(me)
    t = 0 if o.name.startswith("X_Skirt") else int(o.name[6])
    tier_of_face += [t] * (len(bm.faces) - n0)
bm.faces.ensure_lookup_table()
tree = BVHTree.FromBMesh(bm)
rep = {}
for eye, p in EYES.items():
    E = Vector(p)
    leaks, sky_tier, skyline = [], [], []
    for ai in range(0, 1440):
        az = math.radians(ai * 0.25)
        hits = []
        for ei in range(-60, 281):
            el = math.radians(ei * 0.05)
            d = Vector((math.cos(az) * math.cos(el), math.sin(az) * math.cos(el), math.sin(el)))
            loc, nrm, idx, dist = tree.ray_cast(E, d, 9000.0)
            if idx is None and d.z < 0:          # lands on the v2 1,800-square ground (z -1) inside |x|, |y| <= 900?
                t = (E.z + 1.0) / -d.z
                q = E + d * t
                if abs(q.x) <= 899.0 and abs(q.y) <= 899.0:
                    idx = -1
            hits.append((ei, idx))
        top = max((ei for ei, idx in hits if idx is not None), default=None)
        if top is None:
            leaks.append((ai * 0.25, "no hit at all")); sky_tier.append(-1); skyline.append(None); continue
        miss = [ei * 0.05 for ei, idx in hits if idx is None and ei < top]
        if miss:
            leaks.append((ai * 0.25, f"{len(miss)} rays miss below the skyline {top * 0.05:.2f} deg, e.g. {miss[:3]}"))
        top_idx = [idx for ei, idx in hits if ei == top][0]
        sky_tier.append(tier_of_face[top_idx] if top_idx >= 0 else 0); skyline.append(round(top * 0.05, 2))
    share = {t: round(100.0 * sky_tier.count(t) / len(sky_tier), 1) for t in sorted(set(sky_tier))}
    run, best, prev = 0, 0, None
    for t in sky_tier + sky_tier:
        run = run + 1 if t == prev else 1; prev = t; best = max(best, run)
    vals = [s for s in skyline if s is not None]
    rep[eye] = dict(leaks=len(leaks), leak_examples=leaks[:5], skyline_tier_share_pct=share,
                    longest_single_tier_run_deg=min(360.0, best * 0.25), skyline_deg_min=min(vals), skyline_deg_max=max(vals))
    print(eye, rep[eye])
os.makedirs(OUT, exist_ok=True)
json.dump(rep, open(os.path.join(OUT, "far_sightcheck.json"), "w"), indent=1)
total = sum(r["leaks"] for r in rep.values())
print("SIGHTCHECK", "PASS" if total == 0 else "FAIL", total, "leaking azimuths over", len(EYES), "eyes")

if "--render" in ARGV:
    for o in bpy.data.objects:
        if o.type == "MESH" and o not in objs:
            o.hide_render = True             # far field only (the Mid pieces sit at the origin, inside the house)
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sh = sc.display.shading
    sh.light = "FLAT"; sh.color_type = "TEXTURE"; sh.show_backface_culling = True
    w = bpy.data.worlds.new("mag"); sc.world = w
    w.color = (1.0, 0.0, 1.0)
    sh.background_type = "WORLD"
    sc.render.resolution_x, sc.render.resolution_y = 1600, 500
    cam = bpy.data.cameras.new("pano"); cam.lens_unit = "FOV"; cam.angle = math.radians(80); cam.clip_end = 10000; cam.clip_start = 1
    co = bpy.data.objects.new("pano", cam); sc.collection.objects.link(co); sc.camera = co
    for eye in ("FY_S_up", "BR3_N_up"):
        for k in range(8):
            co.location = EYES[eye]
            co.rotation_euler = (math.radians(88.0), 0, math.radians(-90 + 45 * k))
            sc.render.filepath = os.path.join(OUT, f"far_{eye}_{k * 45:03d}.png")
            bpy.ops.render.render(write_still=True)
    print("renders in", OUT)
    try:     # one sheet per eye (top 220 px of each frame = the skyline band), frames removed
        from PIL import Image
        for eye in ("FY_S_up", "BR3_N_up"):
            out = Image.new("RGB", (1600, 440))
            for k in range(8):
                f = os.path.join(OUT, f"far_{eye}_{k * 45:03d}.png")
                out.paste(Image.open(f).convert("RGB").crop((0, 0, 1600, 220)).resize((800, 110)), ((k % 2) * 800, (k // 2) * 110))
                os.remove(f)
            out.save(os.path.join(OUT, f"far_pano_{eye}_sheet.jpg"), quality=88)
    except ImportError:
        pass

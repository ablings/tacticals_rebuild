"""make_body.py: build body / movement clips in Blender and export them for Studio (anim-body animator).

  blender -b art/anim/rig/Starter_Blocky_Rig.blend --python art/anim/body/blender/make_body.py -- <set> [clip ...] [--preview]

<set> = a module in art/anim/body/blender/clips/. Each module has CLIPS = {name: builder() -> Clip} and
MIRROR = {name: mirrored_name} for the clips that get a mirrored copy (e.g. "...Left").
Saves art/anim/body/blender/sets/<set>.blend and writes out/anim_body/json/<Clip>.json (+ mirrors).
--preview also renders workbench frames to out/anim_body/preview/<Clip>/ (front, side, 3/4 at 10 fps) for quick checks.
"""
import bpy, sys, os, importlib, json, math
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "clips"))
import bodyanim  # sets rbxanim.R15_JSON
import rbxanim
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
preview = "--preview" in argv
argv = [a for a in argv if not a.startswith("--")]
setname = argv[0]
only = set(argv[1:])
mod = importlib.import_module(setname)
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
OUT = os.path.join(ROOT, "out", "anim_body", "json")
rbxanim.setup_rig()


def fix_source(path, clipname, clip=None, mirrored=False):
    with open(path) as f:
        d = json.load(f)
    d["attrs"]["Source"] = "art/anim/body/blender/clips/%s.py (%s)" % (setname, clipname)
    if clip is not None:
        own = [rbxanim.mirror_name(j) if mirrored else j for j in clip.joints]
        d["owned"] = own  # build_clips writes every other (parent-chain) pose at Weight 0: layers key only what they own
        if mirrored:
            for m in d["markers"]:
                if m["name"] == "Footstep" and m["value"] in ("L", "R"):
                    m["value"] = "R" if m["value"] == "L" else "L"
        # a loop's closing key at exactly the code length (60 fps sampling stops at a whole frame)
        last = max(k["t"] for k in d["keys"])
        if d["loop"] and d["length"] - last > 1e-4:
            first = [dict(k, t=round(d["length"], 4)) for k in d["keys"] if k["t"] == 0]
            d["keys"] += first
    with open(path, "w") as f:
        json.dump(d, f)


def render_preview(clip):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.render.resolution_x, sc.render.resolution_y = 300, 400
    sc.render.film_transparent = False
    sc.display.shading.light = "STUDIO"
    sc.display.shading.color_type = "MATERIAL"
    sc.display.shading.show_shadows = True
    ob = bpy.data.objects["Blocky Rig"]
    for o in bpy.data.objects:  # the starter file's widget shapes / second head
        if (o.type == "MESH" and o.parent is None) or o.name == "Woman Head":
            o.hide_render = True
    if "GunProxy" not in bpy.data.objects:
        bpy.ops.mesh.primitive_cube_add(size=1)
        g = bpy.context.active_object; g.name = "GunProxy"
        g.scale = (0.18, 0.9, 0.35)
        g.parent = ob; g.parent_type = "BONE"; g.parent_bone = "Gun"
        g.location = (0, -0.65, 0.1)
    if "_Floor" not in bpy.data.objects:
        bpy.ops.mesh.primitive_plane_add(size=12)
        bpy.context.active_object.name = "_Floor"
    cam = bpy.data.objects.get("_PrevCam")
    if not cam:
        cam = bpy.data.objects.new("_PrevCam", bpy.data.cameras.new("_PrevCam"))
        sc.collection.objects.link(cam)
    sc.camera = cam
    cam.data.lens = 50
    views = {"front": (Vector((1.5, 11, 3.6)), Vector((0, 0, 2.6))),
             "side": (Vector((11, 1.0, 3.4)), Vector((0, 0.5, 2.6))),
             "game": (Vector((2.6, -7.5, 5.6)), Vector((0.4, 3.0, 3.6)))}
    d = os.path.join(ROOT, "out", "anim_body", "preview", clip.name)
    os.makedirs(d, exist_ok=True)
    for f in os.listdir(d):
        os.remove(os.path.join(d, f))
    n = int(round(clip.length * 10))
    for vn, (p, look) in views.items():
        cam.location = p
        cam.rotation_euler = (look - p).to_track_quat("-Z", "Y").to_euler()
        for i in range(n + 1):
            sc.frame_set(int(round(i * 6)))
            sc.render.filepath = os.path.join(d, "%s_%02d.png" % (vn, i))
            bpy.ops.render.render(write_still=True)


def body_quality(clip):
    """knee / elbow bend range, ankle height over the floor (rest ankle pivot = 0.262), head forward (+ = in front of the
    hips), sampled every frame. Printed and stored in the JSON's quality block."""
    ob = clip.ob; sc = bpy.context.scene; pb = ob.pose.bones
    n = int(round(clip.length * 60))
    q = {"kneeR": [], "kneeL": [], "elbowR": [], "elbowL": [], "ankleR": [], "ankleL": [], "headFwd": [], "headTop": []}
    for i in range(n + 1):
        sc.frame_set(i)
        for s, S in (("R", "R"), ("L", "L")):
            a = pb["Upperleg." + s].matrix.to_3x3().col[1]; b = pb["Lowerleg." + s].matrix.to_3x3().col[1]
            q["knee" + S].append(math.degrees(a.angle(b)))
            a = pb["Upperarm." + s].matrix.to_3x3().col[1]; b = pb["Lowerarm." + s].matrix.to_3x3().col[1]
            q["elbow" + S].append(math.degrees(a.angle(b)))
            q["ankle" + S].append(pb["Foot." + s].head.z - 0.262)
        h = pb["Head"].head
        q["headFwd"].append(h.y - pb["Lowertorso"].head.y)
        q["headTop"].append((pb["Head"].matrix @ Vector((0, 1.2, 0))).z)
    out = {k: [round(min(v), 3), round(max(v), 3)] for k, v in q.items()}
    tr = getattr(clip, "travel", None)  # (vx, vz) studs/s of the character in Roblox axes: planted feet must hold still
    if tr:
        for s in ("R", "L"):
            runs, cur = [], []
            for i in range(n + 1):
                sc.frame_set(i)
                h = pb["Foot." + s].head
                wx, wz = h.x + tr[0] * i / 60.0, -h.y + tr[1] * i / 60.0
                if h.z - 0.262 < 0.02:
                    cur.append((wx, wz))
                elif cur:
                    runs.append(cur); cur = []
            if cur:
                runs.append(cur)
            out["slide" + s] = round(max((max(math.hypot(a[0] - b[0], a[1] - b[1]) for a in r for b in r) for r in runs), default=0), 3)
    print("BODYQ", clip.name, out)
    return out


results = []
mirrors = getattr(mod, "MIRROR", {})
for name, builder in mod.CLIPS.items():
    if only and name not in only:
        continue
    clip = builder()
    clip.finish()
    clip.act.use_fake_user = True
    bq = body_quality(clip)
    out = rbxanim.export_clip(clip, OUT)
    fix_source(os.path.join(OUT, out["name"] + ".json"), name, clip)
    _p = os.path.join(OUT, out["name"] + ".json"); _d = json.load(open(_p)); _d["quality"]["body"] = bq; json.dump(_d, open(_p, "w"))
    results.append(out)
    if name in mirrors:
        mo = rbxanim.export_clip(clip, OUT, mirror=True, name=mirrors[name])
        fix_source(os.path.join(OUT, mo["name"] + ".json"), name, clip, True)
    if preview:
        render_preview(clip)
os.makedirs(os.path.join(HERE, "sets"), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "sets", setname + ".blend"), copy=True)
print("MADE", [r["name"] for r in results])

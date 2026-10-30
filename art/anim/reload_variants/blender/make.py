"""make.py: build the ammo-aware reload variants in Blender and export them for Studio.

  blender -b art/anim/rig/Starter_Blocky_Rig.blend --python art/anim/reload_variants/blender/make.py -- <set> [clip ...]

<set> = a module in reload_variants/blender/clips (rv_pistol, rv_smg, ...). Reuses the weapons animator's rbxanim and
clip helpers (read-only import from art/anim/weapons/blender). Writes out/anim_reload_variants/json/<clip>(Left).json and
saves reload_variants/blender/sets/<set>.blend. Every clip must be exactly the gun's base reload length (checked here)."""
import bpy, sys, os, importlib, json
HERE = os.path.dirname(os.path.abspath(__file__))
WB = os.path.join(HERE, "..", "..", "weapons", "blender")
sys.path.insert(0, os.path.join(HERE, "clips"))
sys.path.insert(0, WB)
sys.path.insert(0, os.path.join(WB, "clips"))
import rbxanim
_kp = rbxanim.Clip.key_prop
def _key_prop_float(self, bone, prop, t, value, **kw):
    # an int value makes the custom property an int: its f-curve then steps at the midpoint instead of blending
    return _kp(self, bone, prop, t, float(value), **kw)
rbxanim.Clip.key_prop = _key_prop_float
argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
setname = argv[0]
only = set(argv[1:])
mod = importlib.import_module(setname)
OUT = os.path.join(HERE, "..", "..", "..", "..", "out", "anim_reload_variants", "json")
gdef = mod.gun_def() if hasattr(mod, "gun_def") else (rbxanim.load_gun(mod.GUN) if getattr(mod, "GUN", None) else None)
rbxanim.setup_rig(tool=getattr(mod, "TOOL", "Pistol"), gun=gdef)
made = []


def pop_check(clip, parts):
    """carried / plucked parts: biggest per-frame jump in the gun frame (a hand switch that pops shows up here)"""
    from mathutils import Matrix, Vector
    ob, r15 = clip.ob, clip.r15
    sc = bpy.context.scene
    n = int(round(clip.length * rbxanim.FPS))
    hidden = {}
    for m in clip.markers:
        hidden.setdefault(m["value"], []).append((m["name"], int(round(m["t"] * rbxanim.FPS))))
    prev = {}
    worst = {p: (0.0, -1) for p in parts}
    for i in range(n + 1):
        sc.frame_set(i)
        bpy.context.view_layer.update()
        G = ob.pose.bones["Gun"].matrix
        for p in parts:
            pb = ob.pose.bones["P_" + p]
            pos = (G.inverted() @ pb.matrix).translation.copy()
            if p in prev:
                d = (pos - prev[p]).length
                if d > worst[p][0]:
                    worst[p] = (d, i)
                if d > 0.12:
                    print("  JUMP", clip.name, p, "f%d" % i, round(d, 3), "inhand", round(pb.get("inhand", 0), 2),
                          "H", [round(x, 2) for x in ob.pose.bones["H_" + p].matrix.translation] if ("H_" + p) in ob.pose.bones else "",
                          "handL", [round(x, 2) for x in ob.pose.bones["Hand.L"].matrix.translation])
            prev[p] = pos
        if os.environ.get("DBGF") and int(os.environ["DBGF"].split("-")[0]) <= i <= int(os.environ["DBGF"].split("-")[1]):
            pl = ob.pose.bones["IK_Hand.L"]
            print("  DBGP f%d" % i, {p: [round(x, 3) for x in (G.inverted() @ ob.pose.bones["P_" + p].matrix).translation] for p in parts},
                  {p: [round(x, 3) for x in (G.inverted() @ ob.pose.bones["H_" + p].matrix).translation] for p in parts if ("H_" + p) in ob.pose.bones})
            print("  DBG f%d" % i, "free", round(pl.get("free", 0), 3), "IK", [round(x, 2) for x in pl.matrix.translation],
                  "Lgun", [round(x, 2) for x in ob.pose.bones["L_Gun"].matrix.translation],
                  "Lfree", [round(x, 2) for x in ob.pose.bones["L_Free"].matrix.translation])
    print("POPCHECK", clip.name, {p: (round(v[0], 3), v[1]) for p, v in worst.items()})

for name, builder in mod.CLIPS.items():
    if only and name not in only:
        continue
    clip = builder()
    assert clip.name == name, (clip.name, name)
    base = getattr(mod, "BASE_LENS", {}).get(name, getattr(mod, "BASE_LEN", None))
    assert abs(clip.length - base) < 1e-6, "%s length %.3f != base %.3f" % (name, clip.length, base)
    clip.finish()
    clip.act.use_fake_user = True
    if getattr(mod, "POP_CHECK", None):
        pop_check(clip, mod.POP_CHECK)
    for mirror in (False, True):
        out = rbxanim.export_clip(clip, OUT, mirror=mirror)
        p = os.path.join(OUT, out["name"] + ".json")
        d = json.load(open(p))
        d["attrs"]["Source"] = "art/anim/reload_variants/blender/clips/%s.py (%s)" % (setname, name)
        d["attrs"]["BaseReload"] = getattr(mod, "BASE_NAMES", {}).get(name, getattr(mod, "BASE_NAME", ""))
        d["attrs"]["RoundsLeft"] = mod.ROUNDS.get(name, "")
        json.dump(d, open(p, "w"))
        made.append(out["name"])
os.makedirs(os.path.join(HERE, "sets"), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "sets", setname + ".blend"), copy=True)
print("MADE", made)

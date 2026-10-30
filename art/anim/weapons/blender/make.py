"""make.py: build clips in Blender and export them for Studio.

  blender -b art/anim/rig/Starter_Blocky_Rig.blend --python art/anim/weapons/blender/make.py -- <set> [clip ...]

<set> = a module in clips/ (pistol, revolver, smg, rifle, shotgun, sniper, melee, gadgets). Each module has
CLIPS = {name: builder(rig) -> rbxanim.Clip} and optional GUN = {"parts": {...}, "joints": {...}}.
Saves art/anim/weapons/blender/sets/<set>.blend (rig + one action per clip) and writes
out/anim_weapons/json/<clip>.json and <clip>Left.json (mirror) for studio/build_clips.lua.
"""
import bpy, sys, os, importlib, json
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "clips"))
import rbxanim
importlib.reload(rbxanim)

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
setname = argv[0]
only = set(argv[1:])
mod = importlib.import_module(setname)
OUT = os.path.join(HERE, "..", "..", "..", "..", "out", "anim_weapons", "json")
gun = getattr(mod, "GUN", None)
rbxanim.setup_rig(gun_parts=gun and gun.get("parts_b"), tool=getattr(mod, "TOOL", "Pistol"))
results = []
for name, builder in mod.CLIPS.items():
    if only and name not in only:
        continue
    clip = builder()
    clip.finish()
    clip.act.use_fake_user = True
    out = rbxanim.export_clip(clip, OUT, gun_joints=gun and gun.get("joints"))
    results.append(out)
    if getattr(mod, "MIRROR", True) and name not in getattr(mod, "NO_MIRROR", ()):
        rbxanim.export_clip(clip, OUT, gun_joints=gun and gun.get("joints"), mirror=True)
os.makedirs(os.path.join(HERE, "sets"), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "sets", setname + ".blend"), copy=True)
print("MADE", [r["name"] for r in results])

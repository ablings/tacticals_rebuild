"""capture_batch.py <batch_dir_name> <spec.json>: proof captures for a batch into captures/anim/body/<batch>/.
spec: [{"clip": name, "layers": [..under], "over": [..on top], "where": "tall|low|flat", "len": s, "loop": bool,
        "gun": "Pistol"|"none", "mirror": name?, "span": [a,b]?}]
Per clip: <clip>_1x.png (10 fps, game / side / first on a real avatar), <clip>_025x.png (0.25x = 40 samples/s of clip
time, side + game, blocky avatar), <clip>_stairs.png (1x on the stairs, game + side); mirrors: one frame front/game."""
import json, os, sys
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
from mcpsess import Session
from shoot import shoot, ROOT
batch, spec = sys.argv[1], json.load(open(sys.argv[2]))
only = set(sys.argv[3:])
D = os.path.join(ROOT, "captures/anim/body", batch)
s = Session(open(os.path.join(ROOT, "out/anim_body/studio_id.txt")).read().strip())


def rng(a, b, step):
    out, t = [], a
    while t <= b + 1e-6:
        out.append(round(t, 4)); t += step
    return out


for c in spec:
    if only and c["clip"] not in only:
        continue
    under, over = c.get("layers", []), c.get("over", [])
    base = under[0] if under else c["clip"]
    layer = "+".join(under[1:] + ([c["clip"]] if under else []) + over) or None
    L = c["len"]; gun = c.get("gun", "Pistol"); where = c.get("where", "flat")
    t1 = rng(0, L - (0.1 if c.get("loop") else 0), 0.1)
    shoot(s, os.path.join(D, c["clip"] + "_1x.png"), base, t1, ["game", "side", "first"], "AvatarA", gun, "R", where, layer,
          title="%s 1x (10 fps) on a player avatar, %s" % (c["clip"], where), size=230, dist=0.55)
    a, b = c.get("span", [0, min(L, 0.5) if c.get("loop") else L])
    shoot(s, os.path.join(D, c["clip"] + "_025x.png"), base, rng(a, b, 0.025), ["side", "game"], "Blocky", gun, "R", where, layer,
          title="%s 0.25x (every 1.5 frames) %.2f-%.2f s, blocky" % (c["clip"], a, b), size=130, dist=0.6)
    shoot(s, os.path.join(D, c["clip"] + "_stairs.png"), base, t1[::2], ["game", "side"], "AvatarB", gun, "R", "stairs", layer,
          title="%s on stairs (1x, 5 fps), player avatar" % c["clip"], size=230, dist=0.55)
    if c.get("mirror"):
        m = c["mirror"]
        mb = (under[0] + "Left") if under and not under[0].endswith("Left") and c.get("mirror_under") else base
        shoot(s, os.path.join(D, m + "_mirror.png"), m if not under else mb, [0, L / 2], ["front", "game"], "AvatarA", gun, "L", where,
              None if not under else m, title="%s (mirror, gun in the left hand)" % m, size=200, dist=0.6)
    print("done", c["clip"])
s.close()

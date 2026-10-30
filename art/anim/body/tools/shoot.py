"""shoot.py: pose clips on avatars in the anim-body Studio and capture views -> a contact sheet (one MCP session).
  python shoot.py <sheet.png> --clip C [--layer L] --times 0,0.25,0.5 | --fps 10 [--speed 0.25] [--span 0,0.5]
        --views front,side,game,first [--avatar AvatarA] [--gun Pistol|none] [--hand R] [--where flat|stairs|tall|low]
Views are relative to the puppet (it faces -Z). In cover spots (tall / low) the gameplay camera looks at the wall."""
import argparse, json, os, sys
from PIL import Image, ImageDraw, ImageFont
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from mcpsess import Session
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", "..", ".."))
POSE = open(os.path.join(ROOT, "art/anim/body/studio/pose.lua"), encoding="utf-8").read()
SPOTS = {"flat": (0, 0, -8), "tall": (0, 0, 0.45), "low": (-14, 0, 0.45), "stairs": (14, 2.0, -2.0)}


def views_for(where, k=1.0):
    v = {
        "front": ((1.2 * k, 3.6, -9 * k), (0, 2.6, 0)),
        "side": ((9 * k, 3.2, -0.5), (0, 2.6, -0.5)),
        "game": ((2.4, 5.0, 8.5 * k), (0.6, 3.6, -4)),
        "first": ((0.0, 4.9, -0.55), (0.0, 4.3, -6)),
        "back": ((-1.0, 3.6, 9 * k), (0, 2.6, 0)),
        "top": ((0.01, 14, -0.5), (0, 0, -0.5)),
        "sideL": ((-9 * k, 3.2, -0.5), (0, 2.6, -0.5)),
    }
    if where in ("tall", "low"):
        v["game"] = ((2.6, 5.0, -8.5 * k), (0.3, 3.0, 1.0))
    return v


def pose_code(avatar, layers, where, gun, hand, extra_at=None):
    sp = SPOTS[where]
    pre = ('local av = game.ServerStorage._AnimAvatars["%s"]\nlocal hh = av.Humanoid.HipHeight + av.HumanoidRootPart.Size.Y / 2\n' % avatar)
    lay = "{" + ",".join('{"%s", %g}' % (c, t) for c, t in layers) + "}"
    at = "CFrame.new(%g, %g + hh, %g)" % (sp[0], 800 + sp[1], sp[2])
    if extra_at:
        at += " * " + extra_at
    pre += 'PUPPETS = {{avatar="%s", layers=%s, at=%s, gun=%s, hand="%s"}}\n' % (
        avatar, lay, at, ('"%s"' % gun) if gun and gun != "none" else "nil", hand)
    return pre + POSE


def shoot(s, sheet, clip, times, views, avatar="AvatarA", gun="Pistol", hand="R", where="flat", layer=None,
          title=None, size=230, dist=1.0, extra_at=None):
    V = views_for(where, dist)
    sp = SPOTS[where]
    tiles = []
    for t in times:
        layers = [(clip, t)] + ([(l, t) for l in layer.split("+")] if layer else [])
        s.luau(pose_code(avatar, layers, where, gun, hand, extra_at))
        for v in views:
            c, l = V[v]
            out = os.path.join(ROOT, "out/anim_body/shots", "%s_%s_%s_%.3f.png" % (clip, where, v, t))
            s.capture(out, (sp[0] + c[0], 800 + sp[1] + c[1], sp[2] + c[2]), (sp[0] + l[0], 800 + sp[1] + l[1], sp[2] + l[2]))
            tiles.append((t, v, out))
    S = size
    H = int(S * 0.86)
    try:
        font = ImageFont.truetype("arialbd.ttf", 12); ft = ImageFont.truetype("arialbd.ttf", 16)
    except Exception:
        font = ft = ImageFont.load_default()
    sheet_im = Image.new("RGB", (S * len(times), H * len(views) + 26), (10, 12, 10))
    d = ImageDraw.Draw(sheet_im)
    d.text((6, 4), title or ("%s on %s (%s, %s)" % (clip, avatar, where, gun)), fill=(236, 232, 218), font=ft)
    for t, v, p in tiles:
        ci, ri = times.index(t), views.index(v)
        if p and os.path.exists(p):
            im = Image.open(p).convert("RGB")
            im = im.resize((S, int(im.height * S / im.width)))
            top = max(0, (im.height - H) // 2)
            sheet_im.paste(im.crop((0, top, S, top + H)), (ci * S, 26 + ri * H))
        d.text((ci * S + 3, 26 + ri * H + 2), "%s %.3gs" % (v, t), fill=(167, 173, 152), font=font)
    os.makedirs(os.path.dirname(os.path.abspath(sheet)), exist_ok=True)
    sheet_im.save(sheet)
    return sheet


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("sheet"); ap.add_argument("--clip", required=True); ap.add_argument("--layer", default=None)
    ap.add_argument("--times", default=None); ap.add_argument("--fps", type=float, default=None)
    ap.add_argument("--speed", type=float, default=1.0); ap.add_argument("--span", default=None); ap.add_argument("--length", type=float, default=1.0)
    ap.add_argument("--views", default="front,side,game"); ap.add_argument("--avatar", default="AvatarA")
    ap.add_argument("--gun", default="Pistol"); ap.add_argument("--hand", default="R"); ap.add_argument("--where", default="flat")
    ap.add_argument("--title", default=None); ap.add_argument("--size", type=int, default=230); ap.add_argument("--dist", type=float, default=1.0)
    a = ap.parse_args()
    if a.times:
        times = [float(x) for x in a.times.split(",")]
    else:
        lo, hi = (0, a.length) if not a.span else [float(x) for x in a.span.split(",")]
        step = a.speed / a.fps  # clip seconds per captured frame (0.25x at 10 fps = 0.025 s)
        times, t = [], lo
        while t <= hi + 1e-6:
            times.append(round(t, 4)); t += step
    s = Session(open(os.path.join(ROOT, "out/anim_body/studio_id.txt")).read().strip())
    print(shoot(s, a.sheet, a.clip, times, a.views.split(","), a.avatar, a.gun, a.hand, a.where, a.layer, a.title, a.size, a.dist))
    s.close()

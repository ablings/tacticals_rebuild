"""sheets.py [gun ...]: Blender renders -> comparison sheets in captures/anim/reload_variants/:
  <gun>_<view>_1x.png   rows = the base reload (time-scaled to the variants' game length, as the code's AdjustSpeed plays it)
                        + every variant; columns = game time at 10 fps (same column = same moment in game)
  <gun>_fp_025x.png     every frame (60 fps = 0.25x of 15 fps playback) over the window where the variants differ."""
import os, subprocess, sys, shutil
from PIL import Image, ImageDraw
R = "C:/Users/aroki/Documents/tacticals_rebuild"
BL = "C:/Program Files/Blender Foundation/Blender 4.5/blender.exe"
WS = R + "/art/anim/weapons/blender/sets/"
VS = R + "/art/anim/reload_variants/blender/sets/"
RD = R + "/out/anim_reload_variants/render/sheets"
CAP = R + "/captures/anim/reload_variants"
REN = R + "/art/anim/reload_variants/blender/render.py"
GUNS = {
    "pistol": ("pistol", "PistolReload", 1.5, "rv_pistol", ["PistolReload_Retain", "PistolReload_Drop", "PistolReload_Dry"], 1.3, (36, 56)),
    "smg": ("smg", "SMGReload", 1.9, "rv_smg", ["SMGReload_Retain", "SMGReload_Drop", "SMGReload_Dry"], 1.7, (56, 76)),
    "rifle": ("rifle", "RifleReload", 2.4, "rv_rifle", ["RifleReload_Retain", "RifleReload_Drop", "RifleReload_Dry"], 2.2, (74, 96)),
    "sniper": ("sniper", "SniperReload", 3.0, "rv_sniper", ["SniperReload_TopUp", "SniperReload_Dry"], 3.0, (96, 122)),
    "revolver": ("revolver", "RevolverReload", 2.4, "rv_revolver",
                 ["RevolverReload_Pluck1", "RevolverReload_Pluck2", "RevolverReload_Dump", "RevolverReload_Dry"], 2.0, (20, 42)),
    "shotgun_shell": ("shotgun", "ShotgunReloadShell", 0.5, "rv_shotgun",
                      ["ShotgunReloadShell_Port", "ShotgunReloadShell_B", "ShotgunReloadShell_Last"], 0.5, (6, 26)),
    "shotgun_start": ("shotgun", "ShotgunReloadStart", 0.2, "rv_shotgun", ["ShotgunReloadStart_Dry"], 0.2, (0, 12)),
}
COLW = {"fp": 200, "game": 120, "side": 120}


def render(setfile, clips, frames, views, out):
    os.makedirs(out, exist_ok=True)
    subprocess.run([BL, "-b", setfile, "--python", REN, "--", out] + clips + ["--f", ",".join("%.3f" % f for f in frames), "--views", ",".join(views)],
                   capture_output=True)


def row(d, clip, view, n, w, label, times):
    ims = []
    for k in range(n):
        p = os.path.join(d, "%s_%s_%d.png" % (clip, view, k))
        im = Image.open(p).convert("RGB")
        im = im.resize((w, int(im.height * w / im.width)))
        ImageDraw.Draw(im).text((3, 3), "%.2fs" % times[k], fill=(255, 255, 0))
        ims.append(im)
    r = Image.new("RGB", (200 + w * n, ims[0].height), (25, 25, 25)); x = 200
    for i in ims: r.paste(i, (x, 0)); x += w
    ImageDraw.Draw(r).multiline_text((6, 6), label, fill=(255, 255, 255))
    return r


def stack(rows, out, title):
    W = max(r.width for r in rows); H = sum(r.height for r in rows) + 24
    o = Image.new("RGB", (W, H), (10, 12, 10)); ImageDraw.Draw(o).text((6, 6), title, fill=(236, 232, 218)); y = 24
    for r in rows: o.paste(r, (0, y)); y += r.height + 0
    o.save(out); print(out)


def do(g):
    bset, bclip, blen, vset, vclips, L, win = GUNS[g]
    n = int(round(L * 10)) + 1
    times = [k / 10 for k in range(n)]
    d = os.path.join(RD, g); shutil.rmtree(d, ignore_errors=True)
    views = ["fp", "game", "side"]
    render(WS + bset + ".blend", [bclip], [t * blen / L * 60 for t in times], views, d)
    render(VS + vset + ".blend", vclips, [t * 60 for t in times], views, d)
    for v in views:
        rows = [row(d, bclip, v, n, COLW[v], "%s (base %.2fs)\nplayed at %.2fs\n(AdjustSpeed %.3f)" % (bclip, blen, L, blen / L), times)]
        rows += [row(d, c, v, n, COLW[v], "%s\n%.2fs" % (c, L), times) for c in vclips]
        stack(rows, os.path.join(CAP, "%s_%s_1x.png" % (g, v)), "%s: %s view, 1x, 10 fps of game time; every row is %.2f s long" % (g, v, L))
    # 0.25x: every frame over the window where the variants differ
    f0, f1 = win
    fr = list(range(f0, f1 + 1))
    d2 = d + "_slow"
    render(VS + vset + ".blend", vclips, fr, ["fp"], d2)
    render(WS + bset + ".blend", [bclip], [f * blen / L for f in fr], ["fp"], d2)
    ts = [f / 60 for f in fr]
    rows = [row(d2, bclip, "fp", len(fr), 110, "%s (base,\ntime-scaled)" % bclip, ts)] + [row(d2, c, "fp", len(fr), 110, c, ts) for c in vclips]
    stack(rows, os.path.join(CAP, "%s_fp_025x.png" % g), "%s: first person, 0.25x (every 60 fps frame, f%d-f%d)" % (g, f0, f1))


for g in (sys.argv[1:] or GUNS):
    do(g)

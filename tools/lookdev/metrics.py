"""Per capture: luminance (Rec.709 on 0-255 sRGB) of the surfaces only (sky masked: B > R + 60 and B > 140), mean and the brightest
5% (p95, glare check), share of surface pixels >= 230 (near-white), and on the 40-stud shots the grid-line contrast: column profile
of a flat sunlit crop, divided by its 21-px running median; line_pct = how much darker the lines are (2nd percentile dip, %).
Usage: python tools/lookdev/metrics.py  -> out/arena_lookdev/metrics.json"""
import json, os
import numpy as np
from PIL import Image
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "out", "arena_lookdev")
# flat, sunlit crops (x0, x1, y0, y1) in the 1452 x 793 capture: bays = back wall above the pieces (53.5 studs away),
# RIVALS = the north end slab's face (40 studs away) seen through the centre gap
CROPS = {"bay": (400, 680, 268, 305), "R": (612, 838, 185, 440), "pillar": (697, 755, 318, 447)}


def lum(a):
    return 0.2126 * a[..., 0] + 0.7152 * a[..., 1] + 0.0722 * a[..., 2]


def line_pct(L, axis):
    P = L.mean(axis=axis)
    pad = np.pad(P, 10, mode="edge")
    T = np.array([np.median(pad[i:i + 21]) for i in range(len(P))])
    R = P / T - 1
    return float(-100 * np.percentile(R, 2))


res = {}
for f in sorted(os.listdir(OUT)):
    if not f.endswith(".png") or "_" not in f or f.startswith(("gt_", "crop")):
        continue
    key = f[:-4]
    a = np.asarray(Image.open(os.path.join(OUT, f)).convert("RGB")).astype(float)
    sky = (a[..., 2] > a[..., 0] + 60) & (a[..., 2] > 140)
    L = lum(a)[~sky]
    m = {"mean": float(L.mean()), "p95": float(np.percentile(L, 95)), "white_share": float((L >= 230).mean() * 100),
         "sky_share": float(sky.mean() * 100), "frame_mean": float(lum(a).mean())}
    surf = a[~sky]
    m["rgb_mean"] = [round(float(v)) for v in surf.mean(axis=0)]
    if key.endswith("_c40"):
        x0, x1, y0, y1 = CROPS["R" if key.startswith("R") else "bay"]
        c = lum(a[y0:y1, x0:x1])
        m["line_pct"] = line_pct(c, 0)   # vertical lines (column profile)
        m["line_pct_h"] = line_pct(c, 1) # horizontal lines (row profile)
        if not key.startswith("R"):  # the pillar's sunlit face at exactly 40 studs (same distance as the RIVALS slab)
            px0, px1, py0, py1 = CROPS["pillar"]; pc = lum(a[py0:py1, px0:px1])
            m["line_pct_40"] = max(line_pct(pc, 0), line_pct(pc, 1))
            m["pillar_rgb"] = [round(float(v)) for v in a[py0:py1, px0:px1].reshape(-1, 3).mean(axis=0)]
        else:
            m["line_pct_40"] = max(m["line_pct"], m["line_pct_h"])
        m["crop_rgb"] = [round(float(v)) for v in a[y0:y1, x0:x1].reshape(-1, 3).mean(axis=0)]
        Image.fromarray(a[y0:y1, x0:x1].astype(np.uint8)).resize(((x1 - x0) * 2, (y1 - y0) * 2), Image.NEAREST).save(os.path.join(OUT, f"crop_{key}.png"))
    res[key] = m
json.dump(res, open(os.path.join(OUT, "metrics.json"), "w"), indent=1)
for k, m in res.items():
    print(f"{k:10s} mean {m['mean']:6.1f}  p95 {m['p95']:6.1f}  >=230 {m['white_share']:5.1f}%  rgb {m['rgb_mean']}"
          + (f"  lines@53 v {m['line_pct']:.1f}% h {m['line_pct_h']:.1f}%  lines@40 {m['line_pct_40']:.1f}%  wall {m['crop_rgb']} pillar {m.get('pillar_rgb')}" if "line_pct" in m else ""))

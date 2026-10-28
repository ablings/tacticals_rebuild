"""Warehouse 2 light numbers per capture: luminance (PIL 'L', 0-255) p5 / p50 / p95 over the frame (top 6 % bar skipped),
the near-black share (pixels with luminance <= 12, i.e. under 5 % of full scale) and the median of a centre box (the cover
face a spawn camera looks at). Usage: python tools/wh2_lum.py <dir> [--json out.json] [--glob 'new_*.png']"""
import glob, json, os, sys
from PIL import Image

NEAR_BLACK = 12


def lum(path):
    im = Image.open(path).convert("L")
    w, h = im.size
    im = im.crop((0, int(h * 0.06), w, h))
    px = sorted(im.tobytes())
    n = len(px)
    dark = sum(1 for v in px if v <= NEAR_BLACK) / n
    c = sorted(im.crop((int(w * 0.4), int(h * 0.35), int(w * 0.6), int(h * 0.6))).tobytes())
    return {"p5": px[int(n * 0.05)], "p50": px[n // 2], "p95": px[int(n * 0.95)], "dark": round(dark * 100, 1), "centre": c[len(c) // 2]}


if __name__ == "__main__":
    d = sys.argv[1]
    pat = sys.argv[sys.argv.index("--glob") + 1] if "--glob" in sys.argv else "new_*.png"
    res = {}
    for f in sorted(glob.glob(os.path.join(d, pat))):
        k = os.path.basename(f)[:-4]
        res[k] = lum(f)
        r = res[k]
        print(f"{k:40s} p5 {r['p5']:3d}  p50 {r['p50']:3d}  p95 {r['p95']:3d}  near-black {r['dark']:5.1f} %  centre {r['centre']:3d}")
    if "--json" in sys.argv:
        json.dump(res, open(sys.argv[sys.argv.index("--json") + 1], "w"), indent=1)

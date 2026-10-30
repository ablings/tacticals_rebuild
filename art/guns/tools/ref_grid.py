"""Overlay a stud grid on a magenta-background side-view reference so profile points can be read off it.
Usage: python ref_grid.py <ref.png> <length_studs> <out.png> [--step 0.1] [--crop f0 f1]
Coordinates: f = studs from the rear end of the silhouette (rightwards = toward the muzzle), z = studs from its bottom.
Prints the silhouette bbox in px and the scale."""
import sys
from PIL import Image, ImageDraw, ImageFont
import numpy as np

a = sys.argv[1:]
src, L, out = a[0], float(a[1]), a[2]
step = float(a[a.index("--step") + 1]) if "--step" in a else 0.1
im = Image.open(src).convert("RGB")
px = np.asarray(im).astype(int)
r, g, b = px[..., 0], px[..., 1], px[..., 2]
mag = (r > 180) & (b > 180) & (g < 110)
mask = ~mag
ys, xs = np.nonzero(mask)
x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
s = (x1 - x0) / L  # px per stud
H = (y1 - y0) / s
print(f"bbox px x {x0}-{x1} y {y0}-{y1}; {s:.1f} px/stud; height {H:.3f} studs")
f0, f1 = 0, L
if "--crop" in a:
    i = a.index("--crop"); f0, f1 = float(a[i + 1]), float(a[i + 2])
cx0, cx1 = int(x0 + f0 * s) - 20, int(x0 + f1 * s) + 20
crop = im.crop((max(0, cx0), max(0, y0 - 30), min(im.width, cx1), min(im.height, y1 + 30)))
up = max(1, int(1400 / crop.width))
crop = crop.resize((crop.width * up, crop.height * up), Image.NEAREST)
d = ImageDraw.Draw(crop)
ox, oy = max(0, cx0), max(0, y0 - 30)
def X(f): return (x0 + f * s - ox) * up
def Y(z): return (y1 - z * s - oy) * up
try:
    font = ImageFont.truetype("arial.ttf", 13)
except Exception:
    font = None
n = 0
f = 0.0
while f <= L + 1e-6:
    if f0 - 1e-6 <= f <= f1 + 1e-6:
        major = round(f / step) % 2 == 0
        d.line([(X(f), 0), (X(f), crop.height)], fill=(0, 255, 255) if major else (0, 140, 140), width=1)
        if major:
            d.text((X(f) + 2, 2), f"{f:.2f}".rstrip("0").rstrip("."), fill=(255, 255, 255), font=font)
    f += step
z = 0.0
while z <= H + 1e-6:
    major = round(z / step) % 2 == 0
    d.line([(0, Y(z)), (crop.width, Y(z))], fill=(255, 255, 0) if major else (140, 140, 0), width=1)
    if major:
        d.text((2, Y(z) - 14), f"{z:.2f}".rstrip("0").rstrip("."), fill=(255, 255, 255), font=font)
    z += step
crop.save(out)
print(out, crop.size)

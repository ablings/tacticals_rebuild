"""hero_sheet.py <out.png> <capture> [<capture> ...]: stacks strip captures (cropped to the figures' band) with labels."""
import sys, os
from PIL import Image, ImageDraw
CAPS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "..", "captures", "anim", "weapons")
out, names = sys.argv[1], sys.argv[2:]
rows = []
for n in names:
    p = os.path.join(CAPS, n)
    if not os.path.exists(p):
        continue
    im = Image.open(p).convert("RGB")
    h = im.height
    im = im.crop((0, int(h * 0.30), im.width, int(h * 0.72)))
    ImageDraw.Draw(im).text((10, 8), n.rsplit("_", 2)[0], fill=(255, 235, 120))
    rows.append(im)
W = max(r.width for r in rows)
o = Image.new("RGB", (W, sum(r.height for r in rows)), (30, 30, 30))
y = 0
for r in rows:
    o.paste(r, (0, y)); y += r.height
if o.width > 1600:
    o = o.resize((1600, int(o.height * 1600 / o.width)))
o.save(out)
print(out)

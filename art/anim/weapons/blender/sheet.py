"""sheet.py <render_dir> <Clip> <out.png>: rows = views (side, game, front), columns = frames, labelled"""
import sys, glob, os
from PIL import Image, ImageDraw
d, clip, out = sys.argv[1:4]
rows = []
for v in ("side", "game", "front"):
    fs = sorted(glob.glob(os.path.join(d, "%s_%s_*.png" % (clip, v))), key=lambda p: int(p.rsplit("_", 1)[1][:-4]))
    if not fs: continue
    ims = [Image.open(f).convert("RGB") for f in fs]
    r = Image.new("RGB", (sum(i.width for i in ims), ims[0].height)); x = 0
    for i in ims: r.paste(i, (x, 0)); x += i.width
    rows.append(r)
o = Image.new("RGB", (max(r.width for r in rows), sum(r.height for r in rows))); y = 0
for r in rows: o.paste(r, (0, y)); y += r.height
ImageDraw.Draw(o).text((6, 6), clip, fill=(255, 255, 0))
o.save(out)

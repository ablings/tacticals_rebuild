"""sheet.py <render_dir> <out.png> <frames csv> <Clip> [<Clip> ...] [--views close,game]: rows = clip x view, labelled"""
import sys, os
from PIL import Image, ImageDraw
a = sys.argv[1:]
views = ["close", "game"]
if "--views" in a:
    i = a.index("--views"); views = a[i + 1].split(","); a = a[:i] + a[i + 2:]
d, out, frames, clips = a[0], a[1], a[2].split(","), a[3:]
rows = []
for c in clips:
    for v in views:
        ims = []
        for k, f in enumerate(frames):
            p = os.path.join(d, "%s_%s_%d.png" % (c, v, k))
            if not os.path.exists(p): continue
            im = Image.open(p).convert("RGB").resize((240, 320))
            ImageDraw.Draw(im).text((4, 4), "f%s" % f, fill=(255, 255, 0))
            ims.append(im)
        if not ims: continue
        r = Image.new("RGB", (sum(i.width for i in ims), ims[0].height + 16), (20, 20, 20)); x = 0
        for i in ims: r.paste(i, (x, 16)); x += i.width
        ImageDraw.Draw(r).text((4, 2), "%s  (%s)" % (c, v), fill=(255, 255, 255))
        rows.append(r)
o = Image.new("RGB", (max(r.width for r in rows), sum(r.height for r in rows))); y = 0
for r in rows: o.paste(r, (0, y)); y += r.height
o.save(out); print(out)

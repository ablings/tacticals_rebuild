"""Grid of captures: python tools/wh2_grid.py <out.png> <img> [<img> ...] (2 columns, 800 x 450 tiles, file name on each)"""
import os, sys
from PIL import Image, ImageDraw
fs = sys.argv[2:]
cols = 2 if len(fs) > 1 else 1
rows = (len(fs) + cols - 1) // cols
s = Image.new("RGB", (800 * cols, 450 * rows))
d = ImageDraw.Draw(s)
for i, f in enumerate(fs):
    x, y = (i % cols) * 800, (i // cols) * 450
    s.paste(Image.open(f).convert("RGB").resize((800, 450)), (x, y))
    d.rectangle((x, y, x + 330, y + 18), fill=(0, 0, 0))
    d.text((x + 4, y + 3), os.path.basename(f)[:-4].replace("new_", ""), fill=(255, 220, 120))
s.save(sys.argv[1])

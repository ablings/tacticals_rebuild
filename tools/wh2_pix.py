"""Sample mean colours of pixel boxes in a capture: python tools/wh2_pix.py <png> name:x0,y0,x1,y1 ..."""
import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert("RGB")
for spec in sys.argv[2:]:
    name, box = spec.split(":")
    x0, y0, x1, y1 = map(int, box.split(","))
    px = list(im.crop((x0, y0, x1, y1)).getdata())
    m = [round(sum(p[i] for p in px) / len(px)) for i in range(3)]
    print(f"{name:12s} {tuple(m)}")

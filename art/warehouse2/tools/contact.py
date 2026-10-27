"""python contact.py <dir> <prefix> <out.png> [cols]: tile PNGs for review."""
import glob, os, sys
from PIL import Image
d, pre, out = sys.argv[1:4]; cols = int(sys.argv[4]) if len(sys.argv) > 4 else 6
fs = sorted(glob.glob(os.path.join(d, pre + "*.png")))
ims = [Image.open(f).convert("RGB") for f in fs]
w, h = ims[0].size
rows = (len(ims) + cols - 1) // cols
sheet = Image.new("RGB", (w * cols, h * rows), (30, 30, 30))
for i, im in enumerate(ims):
    sheet.paste(im, ((i % cols) * w, (i // cols) * h))
sheet.save(out); print(out, len(ims))

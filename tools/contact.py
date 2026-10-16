"""Contact sheet: python tools/contact.py <dir> <prefix> <out.jpg> name1 name2 ..."""
import sys, os
from PIL import Image
d, pre, out = sys.argv[1:4]; names = sys.argv[4:]
ims = [Image.open(os.path.join(d, f"{pre}_{n}.png")).convert("RGB").resize((800, 495)) for n in names]
rows = (len(ims) + 1) // 2
s = Image.new("RGB", (1600, 495 * rows))
for i, im in enumerate(ims): s.paste(im, ((i % 2) * 800, (i // 2) * 495))
s.save(os.path.join(d, out), quality=85)

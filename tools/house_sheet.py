"""Contact sheets of the House review captures: python tools/house_sheet.py <capdir> <out.jpg> [prefix-filter] [cols]"""
import os, sys
from PIL import Image, ImageDraw
d, out = sys.argv[1], sys.argv[2]
flt = sys.argv[3] if len(sys.argv) > 3 else ""
cols = int(sys.argv[4]) if len(sys.argv) > 4 else 4
fs = sorted(f for f in os.listdir(d) if f.endswith(".png") and f.startswith(flt) and not f.startswith("_"))
ims = [Image.open(os.path.join(d, f)).convert("RGB") for f in fs]
W = 480; H = int(ims[0].size[1] * W / ims[0].size[0])
rows = (len(ims) + cols - 1) // cols
sheet = Image.new("RGB", (W * cols, (H + 18) * rows), (20, 20, 20))
dr = ImageDraw.Draw(sheet)
for i, (f, im) in enumerate(zip(fs, ims)):
    x, y = (i % cols) * W, (i // cols) * (H + 18)
    sheet.paste(im.resize((W, H)), (x, y + 18))
    dr.text((x + 4, y + 3), f[:-4], fill=(240, 240, 240))
sheet.save(out, quality=88)
print(out, sheet.size)

import sys, glob, os
from PIL import Image, ImageDraw, ImageFont
src, out = sys.argv[1], sys.argv[2]
filt = sys.argv[3].split(',') if len(sys.argv) > 3 else None
cols = int(sys.argv[4]) if len(sys.argv) > 4 else 6
fs = sorted(f for f in glob.glob(os.path.join(src, '*.png')) if not os.path.basename(f).startswith('_'))
if filt: fs = [f for f in fs if any(k in os.path.basename(f) for k in filt)]
W = 400
ims = []
for f in fs:
    im = Image.open(f).convert('RGB'); im = im.crop((0, int(im.height*0.06), im.width, im.height))
    h = int(im.height * W / im.width); ims.append((os.path.basename(f)[:-4], im.resize((W, h))))
H = ims[0][1].height
rows = (len(ims) + cols - 1) // cols
sheet = Image.new('RGB', (cols * W, rows * (H + 18)), (20, 20, 20))
d = ImageDraw.Draw(sheet)
try: font = ImageFont.truetype('arial.ttf', 14)
except Exception: font = None
for i, (n, im) in enumerate(ims):
    x, y = (i % cols) * W, (i // cols) * (H + 18)
    sheet.paste(im, (x, y + 18)); d.text((x + 4, y + 2), n, fill=(240, 240, 240), font=font)
sheet.save(out, quality=85); print(out, len(ims))

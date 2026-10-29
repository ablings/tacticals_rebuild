# sheet.py <out.png> <title> <cols> <img:label> ...
import sys
from PIL import Image, ImageDraw, ImageFont
out, title, cols = sys.argv[1], sys.argv[2], int(sys.argv[3])
items = [a.split("::") for a in sys.argv[4:]]
W, H = 420, 310
try: f = ImageFont.truetype("arialbd.ttf", 18); ft = ImageFont.truetype("arialbd.ttf", 26)
except Exception: f = ft = ImageFont.load_default()
rows = (len(items) + cols - 1) // cols
sheet = Image.new("RGB", (cols * W, rows * (H + 28) + 50), (10, 12, 10))
d = ImageDraw.Draw(sheet)
d.text((12, 10), title, fill=(236, 232, 218), font=ft)
for i, (p, lab) in enumerate(items):
    im = Image.open(p).convert("RGB"); im.thumbnail((W - 6, H - 6))
    x, y = (i % cols) * W, 50 + (i // cols) * (H + 28)
    sheet.paste(im, (x + 3, y + 28))
    d.text((x + 6, y + 4), lab, fill=(167, 173, 152), font=f)
sheet.save(out); print(out)

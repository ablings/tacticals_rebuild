"""Tile renders/tiles_<manifest>.json into a labelled sheet.
  python art/house/tools/compose_sheet.py house_furniture notes/house_props_sheet.jpg "House furniture (Part A)" """
import json, os, sys
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))
REPO = os.path.abspath(os.path.join(ROOT, "..", ".."))
tiles = json.load(open(os.path.join(ROOT, "renders", f"tiles_{sys.argv[1]}.json")))
OUT = os.path.join(REPO, sys.argv[2]); TITLE = sys.argv[3]


def font(px, bold=True):
    for f in (("segoeuib.ttf" if bold else "segoeui.ttf"), "arialbd.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(f, px)
        except OSError:
            pass
    return ImageFont.load_default()


TW, TH, BAR, COLS = 480, 320, 62, 6
rows = (len(tiles) + COLS - 1) // COLS
HEAD = 84
EXTRA = sys.argv[4:]          # optional big views (house renders) on top: 3 per row, 960 x 540 each... scaled to 2 tiles wide
EW, EH = TW * 2, int(TW * 2 * 9 / 16)
erows = (len(EXTRA) + 2) // 3
EXH = erows * (EH + 40)
sheet = Image.new("RGB", (TW * COLS, HEAD + EXH + rows * (TH + BAR)), (20, 20, 20))
d = ImageDraw.Draw(sheet)
d.text((20, 12), TITLE, font=font(32), fill=(236, 232, 218))
d.text((20, 52), "5-stud human for scale. Sizes in studs, Studio X x Y(up) x Z. Cover: LOW = 3.4 tall, TALL = 8.0. Own models, baked textures.",
       font=font(19, False), fill=(200, 196, 186))
for i, e in enumerate(EXTRA):
    path, _, label = e.partition("=")
    x, y = (i % 3) * EW, HEAD + (i // 3) * (EH + 40)
    sheet.paste(Image.open(path).convert("RGB").resize((EW, EH), Image.LANCZOS), (x, y))
    d.rectangle([x, y + EH, x + EW - 1, y + EH + 39], fill=(34, 34, 34))
    d.text((x + 10, y + EH + 7), label, font=font(21), fill=(236, 232, 218))
for i, t in enumerate(tiles):
    x, y = (i % COLS) * TW, HEAD + EXH + (i // COLS) * (TH + BAR)
    im = Image.open(t["png"]).convert("RGB").resize((TW, TH), Image.LANCZOS)
    sheet.paste(im, (x, y))
    d.rectangle([x, y + TH, x + TW - 1, y + TH + BAR - 1], fill=(34, 34, 34))
    s = t["size"]
    d.text((x + 8, y + TH + 4), t["name"].replace("H_", ""), font=font(19), fill=(236, 232, 218))
    d.text((x + TW - 8, y + TH + 6), f"{s[0]:g} x {s[1]:g} x {s[2]:g}  {t['tris']} tris", font=font(15), fill=(236, 232, 218), anchor="ra")
    cov = t.get("cover", "")
    col = (167, 173, 152) if cov.startswith(("LOW", "TALL")) else (150, 150, 146)
    d.text((x + 8, y + TH + 34), (cov + " | " if cov else "") + t.get("role", ""), font=font(14, False), fill=col)
    d.line([x, y, x, y + TH + BAR], fill=(20, 20, 20), width=3)
os.makedirs(os.path.dirname(OUT), exist_ok=True)
sheet.save(OUT, quality=88)
print(OUT, sheet.size)

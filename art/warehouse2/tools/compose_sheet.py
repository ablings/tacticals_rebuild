"""Tile art/warehouse2/renders/*.png (from render_sheet.py) into notes/warehouse2_props_sheet.jpg with labels.
  python art/warehouse2/tools/compose_sheet.py"""
import json, os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))
REPO = os.path.abspath(os.path.join(ROOT, "..", ".."))
tiles = json.load(open(os.path.join(ROOT, "renders", "tiles.json")))


def font(px, bold=True):
    for f in (("segoeuib.ttf" if bold else "segoeui.ttf"), "arialbd.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(f, px)
        except OSError:
            pass
    return ImageFont.load_default()


TW, TH, BAR, COLS = 600, 400, 74, 3
rows = (len(tiles) + COLS - 1) // COLS
HEAD = 90
sheet = Image.new("RGB", (TW * COLS, HEAD + rows * (TH + BAR)), (20, 20, 20))
d = ImageDraw.Draw(sheet)
d.text((20, 14), "Warehouse 2 props: old piece (left, stand-in at the old size) | 5-stud human | new model (right)", font=font(30), fill=(236, 232, 218))
d.text((20, 54), "Sizes in studs, Studio axes X x Y(up) x Z. Cover heights unchanged: low 3.4, tall 7. Own models and baked textures.",
       font=font(20, False), fill=(200, 196, 186))
for i, t in enumerate(tiles):
    x, y = (i % COLS) * TW, HEAD + (i // COLS) * (TH + BAR)
    im = Image.open(t["png"]).convert("RGB").resize((TW, TH), Image.LANCZOS)
    sheet.paste(im, (x, y))
    d.rectangle([x, y + TH, x + TW - 1, y + TH + BAR - 1], fill=(34, 34, 34))
    s = t["size"]
    d.text((x + 10, y + TH + 6), t["name"].replace("W2_", ""), font=font(22), fill=(236, 232, 218))
    d.text((x + TW - 10, y + TH + 8), f"{s[0]:g} x {s[1]:g} x {s[2]:g}   {t['tris']} tris", font=font(18), fill=(236, 232, 218), anchor="ra")
    d.text((x + 10, y + TH + 40), "old: " + t["old"], font=font(17, False), fill=(200, 196, 186))
    d.line([x, y, x, y + TH + BAR], fill=(20, 20, 20), width=3)
out = os.path.join(REPO, "notes", "warehouse2_props_sheet.jpg")
sheet.save(out, quality=88)
print(out, sheet.size)

"""Shop round-3 sheet: ROUND 2 | ROUND 3 per view, round-3 detail views, and the RIVALS UGC refs.
Usage (from tacticals_rebuild): python tools/polish_shop3_sheet.py   -> out/polish/shop/sheet3.jpg
Inputs: r2_<view>.png / r3_<view>.png (polish_shop_capture.py r2|r3), r3d_<name>.png (detail cams), ref_*.png (RIVALS, read-only)."""
import os
from PIL import Image, ImageDraw, ImageFont
D = os.path.join("out", "polish", "shop")
VIEWS = ["entry", "counter", "west", "east", "se_corner"]
DETAILS = [("stage", "featured stage (Spin, key spot, rope line)"), ("wallW", "outfit wall W (camo mannequins)"),
           ("wallE", "outfit wall E"), ("cases", "glass case + headgear wall"), ("headgear", "headgear wall"),
           ("screens", "OUTFITTERS sign, NEW DROPS / FEATURED screens, tag")]
REFS = [("ref_ugc_stage", "RIVALS UGC shop stage"), ("ref_market_hall", "RIVALS market hall"), ("ref_market", "RIVALS market")]
TW, TH, PAD, HDR = 640, 396, 8, 34
try:
    F = ImageFont.truetype("arialbd.ttf", 22); FS = ImageFont.truetype("arial.ttf", 18)
except Exception:
    F = FS = ImageFont.load_default()
rows = len(VIEWS) + 1 + 1
W = PAD + 3 * (TW + PAD); H = 60 + rows * (TH + HDR + PAD)
sheet = Image.new("RGB", (W, H), (18, 20, 22)); d = ImageDraw.Draw(sheet)
d.text((PAD, 14), "Tacticals Shop round 3 (UGC / cosmetic shop): ROUND 2 | ROUND 3 (edit-time Future)  +  details  +  RIVALS refs (read-only)",
       fill=(236, 232, 218), font=F)


def put(img, col, row, label):
    x = PAD + col * (TW + PAD); y = 60 + row * (TH + HDR + PAD)
    d.text((x, y + 6), label, fill=(167, 173, 152), font=FS)
    if img and os.path.exists(img):
        sheet.paste(Image.open(img).convert("RGB").resize((TW, TH)), (x, y + HDR))


for r, v in enumerate(VIEWS):
    put(os.path.join(D, f"r2_{v}.png"), 0, r, f"ROUND 2  {v}")
    put(os.path.join(D, f"r3_{v}.png"), 1, r, f"ROUND 3  {v}")
# third column of the view rows: the first details; the rest in two extra rows
cells = [(2, r) for r in range(len(VIEWS))] + [(c, len(VIEWS) + k) for k in range(1) for c in range(3)]
for (c, r), (n, lab) in zip(cells, DETAILS):
    put(os.path.join(D, f"r3d_{n}.png"), c, r, "ROUND 3  " + lab)
for c, (n, lab) in enumerate(REFS):
    put(os.path.join(D, n + ".png"), c, rows - 1, lab)
out = os.path.join(D, "sheet3.jpg")
sheet.save(out, quality=86); print("saved", out, sheet.size)

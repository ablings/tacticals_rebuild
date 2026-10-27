"""Before (v1) / after (v2) sheet of the Arena from the fixed cameras (captures/cams-arena_v2.json) -> out/arena_v2/sheet.jpg
    python tools/arena_v2_sheet.py"""
import json, os
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "out", "arena_v2")
cams = list(json.load(open(os.path.join(ROOT, "captures", "cams-arena_v2.json")))["cams"].keys())
W, H = 480, 399  # each frame scaled from 812 x 675
LBL = 26
try:
    font = ImageFont.truetype("arial.ttf", 17)
    big = ImageFont.truetype("arialbd.ttf", 22)
except OSError:
    font = big = ImageFont.load_default()
pairs_per_row = 2
rows = (len(cams) + pairs_per_row - 1) // pairs_per_row
head = 70
sheet = Image.new("RGB", (pairs_per_row * 2 * W + (pairs_per_row - 1) * 16, head + rows * (H + LBL)), (24, 24, 26))
d = ImageDraw.Draw(sheet)
d.text((12, 10), "Tacticals Arena: v1 (before, left of each pair) vs v2 (after, right). Same cameras, Arena match lighting, "
       "Studio quality 21, FOV 70, eye 5.1 above the floor/deck", fill=(235, 235, 235), font=big)
d.text((12, 40), "v2: approved layout (3 lanes, twin windows, 5-high perch + ledge), look E surfaces (warm greys, cover 13% darker, "
       "soft world-aligned grid)", fill=(200, 200, 200), font=font)
for i, c in enumerate(cams):
    r, k = divmod(i, pairs_per_row)
    x0 = k * (2 * W + 16)
    y0 = head + r * (H + LBL)
    for j, tag in enumerate(("v1", "v2")):
        p = os.path.join(OUT, f"{tag}_{c}.png")
        if os.path.exists(p):
            sheet.paste(Image.open(p).convert("RGB").resize((W, H), Image.LANCZOS), (x0 + j * W, y0 + LBL))
        d.text((x0 + j * W + 6, y0 + 4), f"{tag.upper()}  {c}", fill=(255, 220, 120) if tag == "v2" else (170, 200, 255), font=font)
sheet.save(os.path.join(OUT, "sheet.jpg"), quality=86)
print("wrote", os.path.join(OUT, "sheet.jpg"), sheet.size)

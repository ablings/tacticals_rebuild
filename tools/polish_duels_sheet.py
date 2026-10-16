"""Duels polish sheet: BEFORE / AFTER rows (door, pads, back, high) + close-ups + RIVALS reference row.
Usage: python tools/polish_duels_sheet.py -> out/polish/duels/sheet.jpg"""
import os
from PIL import Image, ImageDraw, ImageFont
D = os.path.join("out", "polish", "duels")
W, H = 480, 297
try: F = ImageFont.truetype("arialbd.ttf", 22)
except Exception: F = ImageFont.load_default()
rows = [
  ("BEFORE", ["before_door", "before_pad1v1", "before_pad2v2", "before_back", "before_high"]),
  ("AFTER", ["after_door", "after_pad1v1", "after_pad2v2", "after_back", "after_high"]),
  ("AFTER close", ["after_entry", "after_close", "after_pad3v3", "after_energy", "after_stairs"]),
  ("RIVALS ref", ["ref_hall", "ref_pad", "ref_pad2", "ref_up"]),
]
LW = 150
sheet = Image.new("RGB", (LW + W * 5, H * len(rows)), (16, 18, 16))
d = ImageDraw.Draw(sheet)
for r, (label, names) in enumerate(rows):
    d.text((12, r * H + H // 2 - 12), label, fill=(236, 232, 218), font=F)
    for c, n in enumerate(names):
        p = os.path.join(D, n + ".png")
        if os.path.exists(p):
            sheet.paste(Image.open(p).convert("RGB").resize((W, H)), (LW + c * W, r * H))
sheet.save(os.path.join(D, "sheet.jpg"), quality=86)
print("sheet", sheet.size)

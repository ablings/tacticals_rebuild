"""Exfil polish sheet: BEFORE / AFTER rows + more AFTER views, the TimesSquare-hidden preview (Edward's open question) and RIVALS' outdoor edge.
Usage: python tools/polish_exfil_sheet.py -> out/polish/exfil/sheet.jpg"""
import os
from PIL import Image, ImageDraw, ImageFont
D = os.path.join("out", "polish", "exfil")
W, H = 480, 297
try: F = ImageFont.truetype("arialbd.ttf", 22)
except Exception: F = ImageFont.load_default()
rows = [
  ("BEFORE", ["before_tunnel", "before_mouth", "before_pad", "before_edge", "before_high"]),
  ("AFTER", ["after_tunnel", "after_mouth", "after_pad", "after_edge", "after_high"]),
  ("AFTER more", ["after_hangar", "after_padS", "after_cutcam"]),
  ("no TimesSq.", ["noTS_edge", "noTS_pad"]),
  ("RIVALS ref", ["ref_outdoor1", "ref_outdoor2"]),
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

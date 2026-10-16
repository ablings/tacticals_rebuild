"""Sky backdrop sheet: BEFORE (TimesSquare) / AFTER (sky base blockout) at the player views, the ExfilFX cutscene frames,
platform details and the Blender kit preview.  Usage: python tools/backdrop_sheet.py -> out/polish/backdrop/sheet.jpg"""
import os
from PIL import Image, ImageDraw, ImageFont
D = os.path.join("out", "polish", "backdrop")
W, H = 480, 270
try: F = ImageFont.truetype("arialbd.ttf", 20); FS = ImageFont.truetype("arial.ttf", 15)
except Exception: F = FS = ImageFont.load_default()
views = ["pad", "edge", "padSE", "hangar", "hubeast"]
cuts = ["cut0", "cut1", "cut2"]
rows = [
  ("BEFORE", [f"before_{v}" for v in views]),
  ("AFTER", [f"after_{v}" for v in views]),
  ("BEFORE cut", [f"before_{v}" for v in cuts] + ["before_wide"]),
  ("AFTER cut", [f"after_{v}" for v in cuts] + ["after_wide"]),
  ("AFTER detail", ["after_dHangar", "after_dComms", "after_dPad", "after_dDepot"]),
  ("Blender kit", ["bl_preview"]),
]
LW = 160
sheet = Image.new("RGB", (LW + W * 5, H * len(rows)), (16, 18, 16))
d = ImageDraw.Draw(sheet)
for r, (label, names) in enumerate(rows):
    d.text((12, r * H + H // 2 - 12), label, fill=(236, 232, 218), font=F)
    for c, n in enumerate(names):
        p = os.path.join(D, n + ".png")
        if not os.path.exists(p): continue
        im = Image.open(p).convert("RGB")
        if n == "bl_preview":
            im = im.resize((W * 2, H)); sheet.paste(im, (LW, r * H))
            d.text((LW + 8, r * H + 6), "kit/backdrop.blend (queued for import): HangarDeck, LandingPad, CommsIsland, FuelDepot", fill=(20, 20, 20), font=FS)
            continue
        sheet.paste(im.resize((W, H)), (LW + c * W, r * H))
        d.text((LW + c * W + 6, r * H + 4), n.split("_", 1)[1], fill=(255, 230, 120), font=FS)
sheet.save(os.path.join(D, "sheet.jpg"), quality=86)
print("sheet", sheet.size)

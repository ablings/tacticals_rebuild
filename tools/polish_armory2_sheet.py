"""Armory round 2 sheet: ROUND 1 | ROUND 2 per view, a close-up column, and a RIVALS reference row.
Usage: python tools/polish_armory2_sheet.py -> out/polish/armory/sheet2.jpg"""
import os
from PIL import Image, ImageDraw, ImageFont
D = os.path.join("out", "polish", "armory")
VIEWS = ["entry", "west", "east", "gunwall", "dais", "sw_corner"]
CLOSE = [("r2_niche", "eye-level niche: 2 slots on pegs"), ("r2_bench", "bench slot + niches behind"),
         ("r2_featured", "featured slot (FeaturedScissors, Spin 25)"), ("r2_supply", "SUPPLY CLERK tag in studs, under the sign"),
         ("r2_gate", "approach from the hub gate"), ("r2_se_corner", "SE corner")]
REFS = ["ref_weapons", "ref_weapons2", "ref_loose"]
TW, TH, PAD, HDR = 640, 396, 8, 34
try: F = ImageFont.truetype("arialbd.ttf", 22); FS = ImageFont.truetype("arial.ttf", 18)
except Exception: F = FS = ImageFont.load_default()
rows = len(VIEWS) + 1
W = PAD + 3 * (TW + PAD); H = 92 + rows * (TH + HDR + PAD)
sheet = Image.new("RGB", (W, H), (18, 20, 22)); d = ImageDraw.Draw(sheet)
d.text((PAD, 12), "Tacticals Armory round 2: ROUND 1 | ROUND 2 | close-ups  +  RIVALS weapons room (read-only ref). Edit-time Future, Studio MCP.", fill=(236, 232, 218), font=F)
d.text((PAD, 44), "20 swap-ready WeaponSlot_* (one placeholder rifle, config ServerStorage.ArmoryWeaponSlots). Envelope blue-minus-red: floor +33 -> +5, walls +42 -> +5..+9, ceiling trim +39 -> 0, beams +29 -> +7.", fill=(167, 173, 152), font=FS)
def put(img, col, row, label):
    x = PAD + col * (TW + PAD); y = 92 + row * (TH + HDR + PAD)
    d.text((x, y + 6), label, fill=(167, 173, 152), font=FS)
    if img and os.path.exists(img): sheet.paste(Image.open(img).convert("RGB").resize((TW, TH)), (x, y + HDR))
for r, v in enumerate(VIEWS):
    put(os.path.join(D, f"rev_{v}.png"), 0, r, f"ROUND 1  {v}")
    put(os.path.join(D, f"r2_{v}.png"), 1, r, f"ROUND 2  {v}")
    n, lab = CLOSE[r]
    put(os.path.join(D, n + ".png"), 2, r, "ROUND 2  " + lab)
for c, n in enumerate(REFS):
    put(os.path.join(D, n + ".png"), c, len(VIEWS), "RIVALS  " + n.replace("ref_", ""))
sheet.save(os.path.join(D, "sheet2.jpg"), quality=86); print("saved", os.path.join(D, "sheet2.jpg"), sheet.size)

"""Armory polish sheet: BEFORE | AFTER per view, plus a RIVALS reference row. Usage: python tools/polish_armory_sheet.py"""
import os
from PIL import Image, ImageDraw, ImageFont
D = os.path.join("out", "polish", "armory")
VIEWS = ["entry", "gate", "west", "east", "dais", "gunwall", "sw_corner"]
REFS = ["ref_weapons", "ref_weapons2", "ref_loose"]
TW, TH, PAD, HDR = 640, 396, 8, 34
try: F = ImageFont.truetype("arialbd.ttf", 22); FS = ImageFont.truetype("arial.ttf", 18)
except Exception: F = FS = ImageFont.load_default()
rows = len(VIEWS) + 1
W = PAD + 3 * (TW + PAD); H = 60 + rows * (TH + HDR + PAD)
sheet = Image.new("RGB", (W, H), (18, 20, 22)); d = ImageDraw.Draw(sheet)
d.text((PAD, 14), "Tacticals Armory polish: BEFORE | AFTER (edit-time Future, Studio MCP)  +  RIVALS weapons room (read-only ref)", fill=(236, 232, 218), font=F)
def put(img, col, row, label):
    x = PAD + col * (TW + PAD); y = 60 + row * (TH + HDR + PAD)
    d.text((x, y + 6), label, fill=(167, 173, 152), font=FS)
    if img: sheet.paste(Image.open(img).convert("RGB").resize((TW, TH)), (x, y + HDR))
for r, v in enumerate(VIEWS):
    put(os.path.join(D, f"before_{v}.png"), 0, r, f"BEFORE  {v}")
    put(os.path.join(D, f"after_{v}.png"), 1, r, f"AFTER  {v}")
extra = {0: "pool_on_1", 1: "bayclose_1"}
for r, n in extra.items():
    p = os.path.join("out", n + ".png")
    if os.path.exists(p): put(p, 2, r, "AFTER  " + ("featured hard spot" if r == 0 else "weapon bay close-up"))
for c, n in enumerate(REFS):
    put(os.path.join(D, n + ".png"), c, len(VIEWS), "RIVALS  " + n.replace("ref_", ""))
sheet.save(os.path.join(D, "sheet.jpg"), quality=86); print("saved", os.path.join(D, "sheet.jpg"), sheet.size)

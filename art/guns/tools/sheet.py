"""notes/guns_sheet.jpg: per gun one row: Codex reference | our model (side) | exploded (moving parts pulled out)"""
import json, os
from PIL import Image, ImageDraw, ImageFont
import numpy as np
import sys
G = sys.argv[1].split(",") if len(sys.argv) > 1 else "Pistol SilencedPistol DualPistols Revolver MiniUzi AutoRifle SemiAuto Sniper PumpShotgun".split()
OUT = sys.argv[2] if len(sys.argv) > 2 else "guns_sheet"
R = os.path.dirname(os.path.abspath(__file__)) + "/.."
W, H = 700, 300
def fit(im):
    a = np.asarray(im.convert("RGB")).astype(int)
    mag = (a[..., 0] > 170) & (a[..., 2] > 170) & (a[..., 1] < 120)
    if mag[2, 2]:
        a[mag] = (235, 235, 232)
        im = Image.fromarray(a.astype("uint8"))
        mask = ~mag
    else:
        bg = a[2, 2]
        mask = (np.abs(a - bg).sum(2) > 40)
    ys, xs = np.nonzero(mask)
    im = im.crop((xs.min() - 8, ys.min() - 8, xs.max() + 8, ys.max() + 8)).convert("RGB")
    im.thumbnail((W - 20, H - 40))
    c = Image.new("RGB", (W, H), (235, 235, 232)); c.paste(im, ((W - im.width) // 2, 30 + (H - 40 - im.height) // 2)); return c
font = ImageFont.truetype("arial.ttf", 20)
sheet = Image.new("RGB", (W * 3, H * len(G) + 50), (255, 255, 255))
d = ImageDraw.Draw(sheet)
for i, t in enumerate(["Codex reference", "Our model (flat low-poly)", "Exploded: every moving part"]):
    d.text((i * W + 10, 12), t, fill=(0, 0, 0), font=font)
for r, g in enumerate(G):
    chk = json.load(open(f"{R}/renders/{g}/check.json"))
    man = json.load(open(f"{R}/manifest/{g}.json"))
    movers = sum(1 for p in man["parts"] if p["motion"] != "static")
    for c, path in enumerate([f"{R}/ref/{g}_side.png", (f"{R}/renders/{g}/sheet.png" if os.path.exists(f"{R}/renders/{g}/sheet.png") else f"{R}/renders/{g}/side.png"), f"{R}/renders/{g}/exploded.png"]):
        im = fit(Image.open(path))
        sheet.paste(im, (c * W, 50 + r * H))
    d.text((10, 50 + r * H + 4), f"{g}: {man['total_tris']} tris, {len(man['parts'])} meshes, {movers} moving, {chk['summary'].split(': ')[1]}", fill=(0, 0, 0), font=font)
os.makedirs(f"{R}/../../notes", exist_ok=True)
sheet.save(f"{R}/../../notes/{OUT}.jpg", quality=85)
sheet.resize((sheet.width // 2, sheet.height // 2)).save(f"{R}/../../captures/{OUT}_small.png")
print("ok", sheet.size)

"""Hub (command deck) sheet: BEFORE | AFTER per view, Play frames from the spawn disc toward each gate, close-ups, RIVALS refs.
Usage (from tacticals_rebuild): python tools/polish_hub_sheet.py -> out/polish/hub/sheet.jpg"""
import os
from PIL import Image, ImageDraw
D = os.path.join("out", "polish", "hub")
W, H = 640, 396
views = ["toN", "toS", "toE", "toW", "wideNE", "wideSW", "disc", "reward", "board", "tunnel"]
extra = [("play_toN.jpg", "Play: disc -> OUTFITTERS (N)"), ("play_toS.jpg", "Play: disc -> ARMORY (S)"),
         ("play_toE.jpg", "Play: disc -> EXFIL (E)"), ("play_toW.jpg", "Play: disc -> DUELS (W)"),
         ("c_banner.png", "insignia banners (upper N wall)"), ("c_shaft.png", "warm sun shafts from the skylight onto the disc"),
         ("c_signN.png", "gate sign + destination-colour bar"), ("c_exfilsign.png", "EXFIL sign, amber bar"),
         ("ref_hubA.png", "RIVALS (read-only): centre disc -> MARKET"), ("ref_hubB.png", "RIVALS: centre -> DUELS sign")]
rows = len(views) + len(extra) // 2
s = Image.new("RGB", (W * 2, 40 + rows * (H + 22)), (18, 19, 18))
d = ImageDraw.Draw(s)
d.text((10, 12), "HUB (command deck): BEFORE | AFTER  - fix/polish_olive.lua + fix/polish_hub.lua", fill=(236, 232, 218))
y = 40
def put(path, x, y, label):
    if os.path.exists(path):
        s.paste(Image.open(path).convert("RGB").resize((W, H)), (x, y + 18))
    d.text((x + 6, y + 3), label, fill=(200, 196, 186))
for v in views:
    put(os.path.join(D, f"before_{v}.png"), 0, y, f"before {v}")
    put(os.path.join(D, f"after_{v}.png"), W, y, f"after {v}")
    y += H + 22
for i in range(0, len(extra), 2):
    for j in range(2):
        f, lab = extra[i + j]
        put(os.path.join(D, f), j * W, y, lab)
    y += H + 22
s.save(os.path.join(D, "sheet.jpg"), quality=80)
print("ok", s.size)

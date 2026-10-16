"""Gate corridors sheet: BEFORE | AFTER per view, a Play frame, the RIVALS doorway refs.
Usage (from tacticals_rebuild): python tools/polish_gates_sheet.py -> out/polish/gates/sheet.jpg"""
import os
from PIL import Image, ImageDraw
D = os.path.join("out", "polish", "gates")
W, H = 640, 396
views = ["Nhub", "Nmid", "Nwall", "Nback", "Smid", "Swall", "Sback", "Nsign"]
rows = len(views) + 2
s = Image.new("RGB", (W * 2, 40 + rows * (H + 22)), (18, 19, 18))
d = ImageDraw.Draw(s)
d.text((10, 12), "GATE CORRIDORS (airlock bulkheads): BEFORE | AFTER  - fix/polish_gates.lua", fill=(236, 232, 218))
y = 40
def put(path, x, y, label):
    if os.path.exists(path):
        s.paste(Image.open(path).convert("RGB").resize((W, H)), (x, y + 18))
    d.text((x + 6, y + 3), label, fill=(200, 196, 186))
for v in views:
    put(os.path.join(D, f"before_{v}.png"), 0, y, f"before {v}")
    put(os.path.join(D, f"after_{v}.png"), W, y, f"after {v}")
    y += H + 22
put(os.path.join(D, "play_S.jpg"), 0, y, "Play: S corridor toward the Armory")
put(os.path.join(D, "ref_padhall.png"), W, y, "RIVALS (read-only): pad hallway mouth")
y += H + 22
put(os.path.join(D, "ref_archway.png"), 0, y, "RIVALS: DUELS archway / door reveal")
put(os.path.join(D, "ref_market.png"), W, y, "RIVALS: market doorway, wall band + capsule lamp")
s.save(os.path.join(D, "sheet.jpg"), quality=82)
print("ok", s.size)

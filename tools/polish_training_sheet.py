"""Training touch-up sheet: BEFORE | AFTER (edit, Training lights forced on), Play frames, close-ups, RIVALS range.
Usage (from tacticals_rebuild): python tools/polish_training_sheet.py -> out/polish/training/sheet.jpg"""
import os
from PIL import Image, ImageDraw
D = os.path.join("out", "polish", "training")
W, H = 640, 396
views = [("arrive", "arrival plaza -> north"), ("qA", "plaza -> A (NW maze, olive)"), ("qB", "plaza -> B (NE towers, cream)"),
         ("qC", "plaza -> C (SE field, sage)"), ("qD", "plaza -> D (SW cover, warm grey)"), ("overview", "overview from SW"),
         ("gallery", "gallery firing line (near-black range band)"), ("bin", "plaza swap bin")]
extra = [("play_before_qC.jpg", "PLAY before: plaza -> SE"), ("play_after_qC.jpg", "PLAY after: plaza -> C (darker grid lines)"),
         ("play_after_qA.jpg", "PLAY after: A"), ("play_after_qB.jpg", "PLAY after: B"),
         ("play_after_qD.jpg", "PLAY after: D"), ("after_exitN.png", "walking out north: A | B floor plates"),
         ("after_stencil.png", "WEAPON SWAP bin frame + stencil"), ("after_towers.png", "B towers: cream bands, near-black edges"),
         ("ref_rivals_eye.png", "RIVALS range (read-only): eye height"), ("ref_rivals_over.png", "RIVALS range: overview")]
rows = len(views) + (len(extra) + 1) // 2
s = Image.new("RGB", (W * 2, 40 + rows * (H + 22)), (18, 19, 18))
d = ImageDraw.Draw(s)
d.text((10, 12), "TRAINING touch-up: BEFORE | AFTER  - fix/polish_training.lua (quadrant A-D codes, grid read, bin marks)", fill=(236, 232, 218))
y = 40
def put(path, x, y, label):
    if os.path.exists(path):
        s.paste(Image.open(path).convert("RGB").resize((W, H)), (x, y + 18))
    d.text((x + 6, y + 3), label, fill=(200, 196, 186))
for v, lab in views:
    put(os.path.join(D, f"before_{v}.png"), 0, y, f"before: {lab}")
    put(os.path.join(D, f"after_{v}.png"), W, y, f"after: {lab}")
    y += H + 22
for i in range(0, len(extra), 2):
    for j in range(2):
        if i + j < len(extra):
            f, lab = extra[i + j]
            put(os.path.join(D, f), j * W, y, lab)
    y += H + 22
s.save(os.path.join(D, "sheet.jpg"), quality=80)
print("ok", s.size)

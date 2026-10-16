"""Showroom round 2 sheet (armory nook): before (round 1 photo studio, current UI blur) vs after (nook, recommended UI values),
from the UI camera, with 3 items (Pistol, AutoRifle locked, Fists = the largest item). No RIVALS reference (its Studio was not open).
Usage (from tacticals_rebuild): python tools/polish_showroom2_sheet.py -> out/polish/showroom/sheet2.jpg"""
import os
from PIL import Image, ImageDraw
D = os.path.join("out", "polish", "showroom")
W, H = 640, 396
rows = [
    ("r2_before_cam.png", "BEFORE edit: CameraPoint view, FOV 40 (round 1 cyclorama)",
     "r2_after_cam.png", "AFTER edit: CameraPoint view, FOV 40 (armory nook)"),
    ("r2_play_before_Pistol.jpg", "BEFORE Play: Kit menu, Pistol (blur 16 + UI blur 9.8 + wash 0.7)",
     "r2_play_after_Pistol.jpg", "AFTER Play: Pistol (recommended: UI blur 4.9, wash 0.35, DOF)"),
    ("r2_play_before_AutoRifle.jpg", "BEFORE Play: AutoRifle (locked, tape)",
     "r2_play_after_AutoRifle.jpg", "AFTER Play: AutoRifle (locked, tape)"),
    ("r2_play_before_Fists.jpg", "BEFORE Play: Fists (largest item, 7.65 diag)",
     "r2_play_after_Fists.jpg", "AFTER Play: Fists"),
    ("r2_play_after_curblur_Pistol.jpg", "AFTER set, CURRENT UI values (blur 16 + 9.8, wash 0.7)",
     "r2_after_wide.png", "AFTER wide: the nook from behind CameraPoint (FOV 70)"),
]
s = Image.new("RGB", (W * 2, 40 + len(rows) * (H + 22)), (18, 19, 18))
d = ImageDraw.Draw(s)
d.text((10, 12), "SHOWROOM round 2: sky-base armory nook   BEFORE | AFTER   - fix/polish_showroom2.lua", fill=(236, 232, 218))
y = 40
for a, la, b, lb in rows:
    for x, f, lab in ((0, a, la), (W, b, lb)):
        p = os.path.join(D, f)
        if os.path.exists(p):
            s.paste(Image.open(p).convert("RGB").resize((W, H)), (x, y + 18))
        else:
            d.text((x + 6, y + 40), "missing " + f, fill=(220, 80, 60))
        d.text((x + 6, y + 3), lab, fill=(200, 196, 186))
    y += H + 22
s.save(os.path.join(D, "sheet2.jpg"), quality=82)
print("ok", s.size)

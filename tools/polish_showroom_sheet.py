"""Showroom (photo studio) sheet: CameraPoint view at FOV 40 sharp + blurred like the Kit menu, the real Kit menu in Play, wide.
Usage (from tacticals_rebuild): python tools/polish_showroom_sheet.py -> out/polish/showroom/sheet.jpg"""
import os
from PIL import Image, ImageDraw
D = os.path.join("out", "polish", "showroom")
W, H = 640, 396
rows = [("before_cam.png", "before: CameraPoint view (FOV 40)", "after_cam.png", "after: cream cyclorama, plinth"),
        ("before_cam_blur.png", "before: blurred as in the Kit menu", "after_cam_blur.png", "after: blurred as in the Kit menu"),
        ("play_kit_menu_before.jpg", "PLAY before: Kit menu", "play_kit_menu_after.jpg", "PLAY after: Kit menu (item over the studio)"),
        ("before_wide.png", "before: wide (behind CameraPoint, FOV 70)", "after_wide.png", "after: wide - cyc, cove, background light")]
s = Image.new("RGB", (W * 2, 40 + len(rows) * (H + 22)), (18, 19, 18))
d = ImageDraw.Draw(s)
d.text((10, 12), "SHOWROOM as a photo studio: BEFORE | AFTER  - fix/polish_showroom.lua", fill=(236, 232, 218))
y = 40
for a, la, b, lb in rows:
    for x, f, lab in ((0, a, la), (W, b, lb)):
        p = os.path.join(D, f)
        if os.path.exists(p):
            s.paste(Image.open(p).convert("RGB").resize((W, H)), (x, y + 18))
        d.text((x + 6, y + 3), lab, fill=(200, 196, 186))
    y += H + 22
s.save(os.path.join(D, "sheet.jpg"), quality=80)
print("ok", s.size)

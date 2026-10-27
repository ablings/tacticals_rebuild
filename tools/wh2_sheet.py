"""Warehouse 2 comparison sheet: old Warehouse (left) vs Warehouse 2 (right) from the same fixed cameras
(notes/warehouse_study/cams.json), plus a strip of the new yard / door cameras.

    python tools/wh2_sheet.py   -> notes/warehouse2_sheet.jpg
Inputs: captures/warehouse2/old/old_<cam>.png (the Warehouse under its own lighting) and captures/warehouse2/final/new_<cam>.png
(Warehouse 2 under its MapInfo lighting), both made by tools/wh2_capture.py."""
import json, os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CAP = os.path.join(ROOT, "captures", "warehouse2")
W, H = 640, 376
F = ImageFont.truetype("C:/Windows/Fonts/bahnschrift.ttf", 22)
FB = ImageFont.truetype("C:/Windows/Fonts/bahnschrift.ttf", 34)


def tile(path, label):
    im = Image.open(path).convert("RGB").resize((W, H))
    d = ImageDraw.Draw(im)
    tw = d.textlength(label, font=F)
    d.rectangle((0, 0, tw + 16, 32), fill=(12, 12, 12))
    d.text((8, 4), label, font=F, fill=(236, 232, 218))
    return im


cams = [c["name"] for c in json.load(open(os.path.join(ROOT, "notes", "warehouse_study", "cams.json")))]
extra = ["wh12_long_axis_to_north_door", "wh13_south_door_inside", "ys01_south_yard_from_door", "yn02_north_yard_corner_look_in"]
rows = len(cams) // 2 + (len(cams) % 2) + 1
head = 60
sheet = Image.new("RGB", (4 * W, head + rows * H), (24, 24, 22))
d = ImageDraw.Draw(sheet)
d.text((16, 10), "Warehouse (old, left of each pair)  vs  Warehouse 2 (new, right): same cameras, same plan positions", font=FB, fill=(236, 232, 218))
for i, c in enumerate(cams):
    r, k = divmod(i, 2)
    x, y = k * 2 * W, head + r * H
    sheet.paste(tile(os.path.join(CAP, "old", f"old_{c}.png"), f"OLD  {c}"), (x, y))
    sheet.paste(tile(os.path.join(CAP, "final", f"new_{c}.png"), f"NEW  {c}"), (x + W, y))
y = head + (rows - 1) * H
for k, c in enumerate(extra):
    sheet.paste(tile(os.path.join(CAP, "final", f"new_{c}.png"), f"NEW  {c}"), (k * W, y))
out = os.path.join(ROOT, "notes", "warehouse2_sheet.jpg")
sheet.save(out, quality=84)
print(out, sheet.size)

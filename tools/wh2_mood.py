"""Warehouse 2 mood numbers (grader 8): median luminance of the roof band, the side wall and the floor along the aisle in
wh12 (long axis), and the roof in wh16 (ceiling side). Usage: python tools/wh2_mood.py <dir> [<dir> ...]"""
import os, sys
from PIL import Image


def med(im, box):
    w, h = im.size
    c = im.crop((int(box[0] * w), int(box[1] * h), int(box[2] * w), int(box[3] * h)))
    px = sorted(c.tobytes())
    return px[len(px) // 2]


for d in sys.argv[1:]:
    a = Image.open(os.path.join(d, "new_wh12_long_axis_to_north_door.png")).convert("L")
    b = Image.open(os.path.join(d, "new_wh16_ceiling_side.png")).convert("L") if os.path.exists(os.path.join(d, "new_wh16_ceiling_side.png")) else None
    roof12 = med(a, (0.25, 0.08, 0.75, 0.25))
    wall12 = med(a, (0.83, 0.30, 0.95, 0.50))
    floor12 = med(a, (0.40, 0.62, 0.60, 0.80))
    roof16 = med(b, (0.2, 0.1, 0.8, 0.45)) if b else -1
    print(f"{os.path.basename(d):14s} wh12 roof {roof12:3d}  wall {wall12:3d}  aisle floor {floor12:3d} | wh16 roof {roof16:3d}")

"""Exfil heli contact sheet: own UH-60-class reference line drawings (from the published dimensions in notes/heli_reference.md,
no photos) beside the Blender previews of kit/heli.blend, plus the old model.  Usage: python tools/heli_sheet.py
-> out/heli/heli_sheet.jpg and out/heli/ref_side.png / ref_top.png / ref_front.png"""
import os
from PIL import Image, ImageDraw, ImageFont
D = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "out", "heli")
try:
    F = ImageFont.truetype("arialbd.ttf", 22); FS = ImageFont.truetype("arial.ttf", 16)
except Exception:
    F = FS = ImageFont.load_default()
INK, BG, DIM = (30, 34, 30), (236, 232, 218), (120, 110, 90)

# ---- real geometry in metres (x from the nose, y up from the ground; plan: z to starboard). Approximate layout values.
L, W = 15.26, 2.36
MAST_X, HUB_Y, R_MAIN = 4.9, 3.76, 8.18
TR_X, TR_Y, R_TAIL = 14.6, 3.45, 1.675
side_top = [(0, 1.05), (0.25, 1.45), (0.9, 1.75), (1.6, 2.35), (2.4, 2.55), (5.9, 2.6), (8.2, 2.5), (12.6, 2.35), (13.3, 2.4),
            (14.6, 4.55), (15.26, 4.7)]
side_bot = [(0, 1.05), (0.3, 0.7), (1.2, 0.5), (6.6, 0.5), (8.0, 0.9), (10.5, 1.45), (13.0, 1.6), (14.3, 1.25), (15.26, 1.4)]
plan_half = [(0, 0.25), (0.4, 0.8), (1.2, 1.12), (2.0, 1.18), (6.8, 1.18), (8.2, 1.0), (10.5, 0.55), (13.5, 0.35), (15.26, 0.25)]

def to_px(pts, s, ox, oy):
    return [(ox + x * s, oy - y * s) for x, y in pts]

def draw_side(path, size=(1400, 900)):
    im = Image.new("RGB", size, BG); d = ImageDraw.Draw(im)
    s = 1100 / (L + 2.0); ox, oy = 150, 720
    d.line([(60, oy), (1360, oy)], fill=DIM, width=2)
    poly = to_px(side_top, s, ox, oy) + to_px(side_bot[::-1], s, ox, oy)
    d.polygon(poly, outline=INK, width=4)
    # cockpit glazing, gunner window, cabin door (open), doghouse, engines, mast, rotor, tail rotor, stabilator, gear
    for r in ((1.0, 1.75, 2.15, 2.4), (2.6, 1.9, 3.5, 2.3), (4.0, 0.62, 5.75, 2.02)):
        d.rectangle([ox + r[0] * s, oy - r[3] * s, ox + r[2] * s, oy - r[1] * s], outline=INK, width=3)
    d.polygon(to_px([(3.2, 2.55), (3.9, 2.95), (7.6, 2.95), (8.4, 2.5)], s, ox, oy), outline=INK, width=3)
    d.line(to_px([(MAST_X, 2.95), (MAST_X, HUB_Y)], s, ox, oy), fill=INK, width=5)
    d.line(to_px([(MAST_X - R_MAIN, HUB_Y), (MAST_X + R_MAIN, HUB_Y)], s, ox, oy), fill=INK, width=4)
    d.ellipse([ox + (TR_X - R_TAIL) * s, oy - (TR_Y + R_TAIL) * s, ox + (TR_X + R_TAIL) * s, oy - (TR_Y - R_TAIL) * s], outline=DIM, width=3)
    d.line(to_px([(13.9, 1.55), (15.3, 1.55)], s, ox, oy), fill=INK, width=5)
    for gx, gy, gr in ((3.3, 0.35, 0.35), (12.1, 0.22, 0.22)):
        d.ellipse([ox + (gx - gr) * s, oy - (gy + gr) * s, ox + (gx + gr) * s, oy - (gy - gr) * s], outline=INK, width=3)
    d.line(to_px([(12.1, 0.22), (12.4, 1.5)], s, ox, oy), fill=INK, width=3)
    d.line(to_px([(3.3, 0.35), (3.3, 0.8)], s, ox, oy), fill=INK, width=3)
    # dimensions
    d.text((ox, oy + 30), "fuselage 15.26 m   rotor 16.36 m   hub 3.76 m   tail rotor 3.35 m, top 5.13 m", fill=INK, font=FS)
    d.text((40, 30), "REFERENCE (own line drawing): UH-60 class, port side", fill=INK, font=F)
    im.save(path)

def draw_top(path, size=(1400, 900)):
    im = Image.new("RGB", size, BG); d = ImageDraw.Draw(im)
    s = 1100 / (L + 2.0); ox, oy = 150, 450
    up = [(ox + x * s, oy - z * s) for x, z in plan_half]
    dn = [(ox + x * s, oy + z * s) for x, z in plan_half[::-1]]
    d.polygon(up + dn, outline=INK, width=4)
    cx, cy = ox + MAST_X * s, oy
    d.ellipse([cx - R_MAIN * s, cy - R_MAIN * s, cx + R_MAIN * s, cy + R_MAIN * s], outline=DIM, width=2)
    for a in (45, 135):
        import math
        dx, dy = math.cos(math.radians(a)) * R_MAIN * s, math.sin(math.radians(a)) * R_MAIN * s
        d.line([(cx - dx, cy - dy), (cx + dx, cy + dy)], fill=INK, width=5)
    d.rectangle([ox + 13.9 * s, oy - 2.2 * s, ox + 14.9 * s, oy + 2.2 * s], outline=INK, width=3)   # stabilator 4.4 m
    d.line([(ox + (TR_X - R_TAIL) * s, oy - 0.5 * s), (ox + (TR_X + R_TAIL) * s, oy - 0.5 * s)], fill=INK, width=4)  # tail rotor, starboard
    for gz in (-1.35, 1.35):
        d.rectangle([ox + 3.1 * s, oy + gz * s - 6, ox + 3.5 * s, oy + gz * s + 6], outline=INK, width=3)
    d.text((40, 30), "REFERENCE (own line drawing): plan, nose left, starboard up", fill=INK, font=F)
    d.text((ox, 860), "width 2.36 m   track 2.7 m   stabilator ~4.4 m   tail rotor on the starboard side, canted 20 deg", fill=INK, font=FS)
    im.save(path)

draw_side(os.path.join(D, "ref_side.png")); draw_top(os.path.join(D, "ref_top.png"))

TW, TH = 700, 450
rows = [("side", ["ref_side", "bl_side"]), ("plan", ["ref_top", "bl_top"]), ("3/4", ["bl_34front", "bl_34rear"]),
        ("cutscene / old", ["bl_cutscene", "old_34"]),
        ("glazing\nold vs new", ["old_cockpit", "ev_cockpit_match"]),
        ("glazing\n(Eevee)", ["ev_cockpit", "ev_cabin_stbd"]), ("door / 3/4\n(Eevee)", ["ev_door_port", "ev_34front"]),
        ("front", ["bl_front"])]
LW = 170
sheet = Image.new("RGB", (LW + TW * 2, TH * len(rows) + 60), (16, 18, 16))
d = ImageDraw.Draw(sheet)
d.text((12, 16), "Tacticals exfil helicopter kit (kit/heli.blend) vs UH-60-class reference. Previews: Blender workbench, backface culling on; "
                 "white blocks = R15-size figures at CabinPoint and HatchPoint (not exported).", fill=(236, 232, 218), font=FS)
for r, (label, names) in enumerate(rows):
    y = 60 + r * TH
    d.multiline_text((12, y + TH // 2 - 24), label, fill=(236, 232, 218), font=F)
    for c, n in enumerate(names):
        p = os.path.join(D, n + (".jpg" if n.startswith("old_") else ".png"))
        if not os.path.exists(p):
            continue
        im = Image.open(p).convert("RGB")
        im.thumbnail((TW, TH))
        sheet.paste(im, (LW + c * TW + (TW - im.width) // 2, y + (TH - im.height) // 2))
        tag = {"old_34": "OLD model in Studio (before)", "bl_cutscene": "ExfilFX start camera (120,9,-18)",
               "old_cockpit": "OLD glazing in Studio, camera (123,7,-21)", "ev_cockpit_match": "NEW glazing, same camera (Eevee)"}.get(n, n)
        d.text((LW + c * TW + 8, y + 6), tag, fill=(255, 200, 80), font=FS)
sheet.save(os.path.join(D, "heli_sheet.jpg"), quality=86)
print("sheet", sheet.size)

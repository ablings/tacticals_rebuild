"""Comparison sheet: rows = bays (+ RIVALS), columns = cameras, with labels and per-image numbers if metrics.json exists.
Usage: python tools/lookdev/sheet.py [out name, default sheet.jpg] [rows e.g. ABCDR]"""
import json, os, sys
from PIL import Image, ImageDraw, ImageFont
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "out", "arena_lookdev")
name = sys.argv[1] if len(sys.argv) > 1 else "sheet.jpg"
rows = sys.argv[2] if len(sys.argv) > 2 else "ABCDR"
CAMS = [("c10", "player height, 10 studs"), ("c40", "player height, 40 studs"), ("sun", "into the sun"), ("aerial", "aerial"), ("seam", "seam: sill + post on the floor (close)")]
LABEL = json.load(open(os.path.join(OUT, "labels.json"))) if os.path.exists(os.path.join(OUT, "labels.json")) else {}
MET = json.load(open(os.path.join(OUT, "metrics.json"))) if os.path.exists(os.path.join(OUT, "metrics.json")) else {}
TW, TH, LW, HH = 520, 284, 250, 34
try:
    font = ImageFont.truetype("arial.ttf", 17); small = ImageFont.truetype("arial.ttf", 14); big = ImageFont.truetype("arialbd.ttf", 22)
except OSError:
    font = small = big = ImageFont.load_default()
sheet = Image.new("RGB", (LW + TW * len(CAMS), HH + TH * len(rows)), (24, 24, 24))
d = ImageDraw.Draw(sheet)
for j, (c, title) in enumerate(CAMS):
    d.text((LW + j * TW + 10, 8), title, fill=(235, 235, 235), font=font)
for i, b in enumerate(rows):
    y = HH + i * TH
    lab = LABEL.get(b, {"title": b, "lines": []})
    d.text((10, y + 10), lab["title"], fill=(255, 255, 255), font=big)
    for k, line in enumerate(lab["lines"]):
        d.text((10, y + 44 + k * 19), line, fill=(205, 205, 205), font=small)
    for j, (c, _) in enumerate(CAMS):
        p = os.path.join(OUT, f"{b}_{c}.png")
        if not os.path.exists(p):
            continue
        im = Image.open(p).convert("RGB"); im = im.resize((TW - 4, int(im.height * (TW - 4) / im.width)))
        im = im.crop((0, 0, TW - 4, TH - 4))
        sheet.paste(im, (LW + j * TW + 2, y + 2))
        m = MET.get(f"{b}_{c}")
        if m:
            txt = f"mean {m['mean']:.0f}  top5% {m['p95']:.0f}" + (f"  lines {m['line_pct_40']:.1f}% @40 / {m['line_pct']:.1f}% @53" if m.get("line_pct") is not None and b not in ("R", "A") else (f"  lines {m['line_pct']:.1f}% @53" if m.get("line_pct") is not None and b == "A" else (f"  lines {m['line_pct_40']:.1f}% @40" if m.get("line_pct") is not None else "")))
            tw = d.textlength(txt, font=small)
            d.rectangle((LW + j * TW + 6, y + TH - 26, LW + j * TW + 14 + tw, y + TH - 8), fill=(0, 0, 0))
            d.text((LW + j * TW + 10, y + TH - 25), txt, fill=(255, 255, 160), font=small)
sheet.save(os.path.join(OUT, name), quality=88)
print("wrote", os.path.join(OUT, name), sheet.size)

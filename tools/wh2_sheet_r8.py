"""Warehouse 2 round 8 before / after sheet: per camera, three tiles
  1. round 6c as it was graded (captures/warehouse2/r6: Studio EditQualityLevel 01, the lowest, by mistake; Part stand-ins)
  2. the same lights with the meshes in, at EditQualityLevel 21 (the PC default)   captures/warehouse2/r8/before_q21
  3. round 8: re-tuned lights at EditQualityLevel 21                                 captures/warehouse2/r8/after_q21
Each tile carries its frame median (p50) and near-black share (luminance <= 12). Usage: python tools/wh2_sheet_r8.py <out.jpg> cam ..."""
import os, sys
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from wh2_lum import lum  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
COLS = [("Round 6c as graded: Studio quality 1 (lowest)", "captures/warehouse2/r6"),
        ("Same lights + meshes at quality 21 (PC)", "captures/warehouse2/r8/before_q21"),
        ("Round 8: lights re-tuned at quality 21 (PC)", "captures/warehouse2/r8/after_q21")]
TW, TH, HEAD = 620, 349, 34


def font(n):
    for f in ("C:/Windows/Fonts/segoeuib.ttf", "C:/Windows/Fonts/arialbd.ttf"):
        if os.path.exists(f):
            return ImageFont.truetype(f, n)
    return ImageFont.load_default()


def main():
    out, cams = sys.argv[1], sys.argv[2:]
    W, H = TW * 3 + 40, HEAD + 30 + len(cams) * (TH + 30)
    s = Image.new("RGB", (W, H), (18, 20, 22))
    d = ImageDraw.Draw(s)
    f1, f2 = font(17), font(14)
    for i, (t, _) in enumerate(COLS):
        d.text((10 + i * (TW + 10), 8), t, fill=(240, 228, 196), font=f1)
    for r, cam in enumerate(cams):
        y = HEAD + 30 + r * (TH + 30)
        d.text((10, y - 22), cam, fill=(200, 200, 200), font=f2)
        for i, (_, folder) in enumerate(COLS):
            p = os.path.join(ROOT, folder, f"new_{cam}.png")
            x = 10 + i * (TW + 10)
            if not os.path.exists(p):
                d.rectangle((x, y, x + TW, y + TH), outline=(90, 90, 90))
                d.text((x + 10, y + 10), "no frame", fill=(160, 160, 160), font=f2)
                continue
            s.paste(Image.open(p).convert("RGB").resize((TW, TH)), (x, y))
            m = lum(p)
            tag = f"p50 {m['p50']}   near-black {m['dark']:.0f} %"
            bad = m["dark"] > 25 and not ("upshot" in cam)
            d.rectangle((x, y + TH - 24, x + 250, y + TH), fill=(0, 0, 0))
            d.text((x + 6, y + TH - 21), tag, fill=(255, 120, 110) if bad else (170, 230, 170), font=f2)
    s.save(out, quality=88)
    print(out)


if __name__ == "__main__":
    main()

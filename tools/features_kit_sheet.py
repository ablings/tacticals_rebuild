"""Before/after sheet for the feature-kit placement: out/features_kit/before_*.png vs after_*.png -> before_after.jpg.
Usage: python tools/features_kit_sheet.py [after-prefix=after] [out=before_after.jpg] [names...]"""
import glob, os, sys
from PIL import Image, ImageDraw, ImageFont
D = "out/features_kit"
aft = sys.argv[1] if len(sys.argv) > 1 else "after"
out = sys.argv[2] if len(sys.argv) > 2 else "before_after.jpg"
names = sys.argv[3:] or sorted(os.path.basename(f)[7:-4] for f in glob.glob(f"{D}/before_*.png"))
names = [n for n in names if os.path.exists(f"{D}/{aft}_{n}.png")]
W, H, PAD, TOP = 560, 349, 6, 24
try: font = ImageFont.truetype("arial.ttf", 16)
except Exception: font = ImageFont.load_default()
sheet = Image.new("RGB", (2 * W + 3 * PAD, len(names) * (H + TOP + PAD) + PAD), (18, 20, 18))
d = ImageDraw.Draw(sheet)
for i, n in enumerate(names):
    y = PAD + i * (H + TOP + PAD)
    for j, pre in enumerate(("before", aft)):
        x = PAD + j * (W + PAD)
        sheet.paste(Image.open(f"{D}/{pre}_{n}.png").convert("RGB").resize((W, H)), (x, y + TOP))
        d.text((x + 4, y + 3), f"{n}  ({'BEFORE' if j == 0 else 'AFTER: features kit'})", fill=(236, 232, 218), font=font)
sheet.save(f"{D}/{out}", quality=82)
print("written", f"{D}/{out}", len(names), "rows")

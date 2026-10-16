"""Contact sheet of out/features/bl_F_*.png -> out/features/bl_contact.jpg (7 columns, labelled)."""
import glob, os
from PIL import Image, ImageDraw, ImageFont
D = r"C:/Users/aroki/Documents/tacticals_rebuild/out/features/"
fs = sorted(glob.glob(D + "bl_F_*.png"))
W, H, C = 400, 300, 7
R = (len(fs) + C - 1) // C
sheet = Image.new("RGB", (W * C, H * R + 34), (24, 25, 23))
try:
    font = ImageFont.truetype("arial.ttf", 18); big = ImageFont.truetype("arial.ttf", 22)
except Exception:
    font = big = ImageFont.load_default()
d = ImageDraw.Draw(sheet)
d.text((10, 6), "Tacticals features kit (kit/features.fbx): Blender Eevee previews, own geometry, palette olive/cream", fill=(236, 232, 218), font=big)
for i, f in enumerate(fs):
    im = Image.open(f).convert("RGB").resize((W, H))
    x, y = (i % C) * W, (i // C) * H + 34
    sheet.paste(im, (x, y))
    name = os.path.basename(f)[3:-4]
    d.rectangle((x, y, x + 9 * len(name) + 14, y + 24), fill=(10, 12, 10))
    d.text((x + 6, y + 3), name, fill=(236, 232, 218), font=font)
sheet.save(D + "bl_contact.jpg", quality=88)
print(sheet.size)

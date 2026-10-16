"""polish_final before/after sheet (Play captures): python tools/final_fixes_sheet.py -> out/polish/final/sheet_fixes.jpg"""
from PIL import Image, ImageDraw, ImageFont
D = "out/polish/final"
pairs = [("before_hub_toN.jpg", "BEFORE: rings sweep the gate view, olive Neon lime"), ("after_hub_toN.jpg", "AFTER: rings 10 / 7.4, T 0.78; Neon 88,88,66"),
         ("before_duels.jpg", "BEFORE: Duels sign/pit Neon reads lime"), ("room_duels.jpg", "AFTER: olive like the band"),
         ("before_duelsdoor.jpg", "BEFORE: streaked Duels doorway reveal"), ("after_duelsdoor.jpg", "AFTER: side Textures hidden")]
W, H = 800, 495
try:
    font = ImageFont.truetype("arialbd.ttf", 22)
except OSError:
    font = ImageFont.load_default()
s = Image.new("RGB", (W * 2, H * 3))
for i, (f, t) in enumerate(pairs):
    im = Image.open(f"{D}/{f}").convert("RGB").resize((W, H))
    d = ImageDraw.Draw(im); tw = d.textlength(t, font=font)
    d.rectangle([0, 0, tw + 20, 34], fill=(10, 12, 10)); d.text((10, 5), t, fill=(236, 232, 218), font=font)
    s.paste(im, ((i % 2) * W, (i // 2) * H))
s.save(f"{D}/sheet_fixes.jpg", quality=85); print(f"{D}/sheet_fixes.jpg")

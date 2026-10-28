import sys, os
from PIL import Image, ImageDraw
root = sys.argv[1]; out = sys.argv[2]; per = int(sys.argv[3]) if len(sys.argv) > 3 else 6
asms = sorted(d for d in os.listdir(root) if os.path.isdir(os.path.join(root, d)))
views = ["front", "back", "left", "right", "below"]
W, H = 320, 240
for k in range(0, len(asms), per):
    chunk = asms[k:k+per]
    sheet = Image.new("RGB", (W*5, (H+18)*len(chunk)), (30, 30, 30))
    d = ImageDraw.Draw(sheet)
    for r, a in enumerate(chunk):
        for c, v in enumerate(views):
            p = os.path.join(root, a, f"check_{v}.png")
            if os.path.exists(p):
                im = Image.open(p).convert("RGB").resize((W, H))
                sheet.paste(im, (c*W, r*(H+18)+18))
        d.text((4, r*(H+18)+3), a, fill=(255, 255, 255))
    sheet.save(f"{out}_{k//per+1}.png")
    print(f"{out}_{k//per+1}.png", chunk)

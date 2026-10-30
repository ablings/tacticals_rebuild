# prev_sheet.py <clip> [frames csv] -> out/anim_body/preview/<clip>_sheet.png (rows: front / side / q34)
import sys, os
from PIL import Image, ImageDraw
clip = sys.argv[1]; D = os.path.join("out/anim_body/preview", clip)
fr = [int(x) for x in sys.argv[2].split(",")] if len(sys.argv) > 2 else None
views = ["front", "side", "game"]
files = sorted(f for f in os.listdir(D) if f.startswith("front_"))
idx = fr if fr is not None else list(range(len(files)))
S = 200
im = Image.new("RGB", (S * len(idx), int(S*4/3) * 3 + 20), (20, 20, 20)); d = ImageDraw.Draw(im)
for r, v in enumerate(views):
    for c, i in enumerate(idx):
        p = os.path.join(D, "%s_%02d.png" % (v, i))
        if os.path.exists(p):
            t = Image.open(p).convert("RGB").resize((S, int(S*4/3))); im.paste(t, (c * S, 20 + r * int(S*4/3)))
for c, i in enumerate(idx): d.text((c * S + 4, 4), "t=%.1f" % (i / 10), fill=(230, 230, 200))
out = os.path.join("out/anim_body/preview", clip + "_sheet.png"); im.save(out); print(out)

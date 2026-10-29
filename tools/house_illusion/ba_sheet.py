"""Before / after window sheet for the House illusion pass: one row per window view, columns = before (q21), after (q21), after (q1).
python out/house_illusion/ba_sheet.py <after_dir_q21> <after_dir_q01> <out.jpg>"""
import os, sys
from PIL import Image, ImageDraw, ImageFont
BEFORE = "captures/house/illusion/before_q21"
A21, A01, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
VIEWS = ["Win_LR_S1_st", "Win_LR_W_swL", "Win_DR_S2_st", "Win_KT_N1_st", "Win_BH_N_st", "Win_MB_S_st", "Win_BR2_N_st",
         "Win_BR3_W_st", "Win_BR3_N1_up", "Win_FY_S_up", "SpawnA_3v3_S", "SpawnB_3v3_N"]
W, H = 520, 300
try:
    F = ImageFont.truetype("arial.ttf", 18); FS = ImageFont.truetype("arial.ttf", 15)
except Exception:
    F = FS = None
cols = [("BEFORE (quality 21)", BEFORE), ("AFTER (quality 21, PC default)", A21), ("AFTER (quality 1, lowest)", A01)]
sheet = Image.new("RGB", (len(cols) * W + 10, 40 + len(VIEWS) * (H + 22)), (18, 18, 18))
d = ImageDraw.Draw(sheet)
for c, (title, _) in enumerate(cols):
    d.text((c * W + 8, 10), title, fill=(255, 235, 170), font=F)
for r, v in enumerate(VIEWS):
    y = 40 + r * (H + 22)
    d.text((8, y), v.replace("Win_", "window ").replace("_", " "), fill=(230, 230, 230), font=FS)
    for c, (_, folder) in enumerate(cols):
        p = os.path.join(folder, v + ".png")
        if not os.path.exists(p):
            continue
        im = Image.open(p).convert("RGB")
        im = im.crop((0, int(im.height * 0.06), im.width, im.height))
        s = max(W / im.width, H / im.height)
        im = im.resize((int(im.width * s) + 1, int(im.height * s) + 1))
        l, t = (im.width - W) // 2, (im.height - H) // 2
        sheet.paste(im.crop((l, t, l + W - 6, t + H)), (c * W + 4, y + 20))
sheet.save(OUT, quality=82)
print(OUT, sheet.size)

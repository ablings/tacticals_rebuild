"""stack a gun's renders (and its reference) into one review image: python review.py <Gun>"""
import sys
from PIL import Image
g = sys.argv[1]
names = [f"ref/{g}_side.png"] + [f"renders/{g}/{n}.png" for n in ("side", "exploded", "persp", "left")]
W = 900
rows = []
for n in names:
    try:
        im = Image.open(n).convert("RGB")
    except Exception:
        continue
    im.thumbnail((W, 600)); rows.append(im)
h = sum(i.height for i in rows); s = Image.new("RGB", (W, h), "white"); y = 0
for i in rows:
    s.paste(i, ((W - i.width) // 2, y)); y += i.height
s.save(f"renders/{g}/_review.jpg", quality=85)
print(f"renders/{g}/_review.jpg")

import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert("RGB")
for spec in sys.argv[2:]:
    name, box = spec.split(":")
    x0, y0, x1, y1 = map(int, box.split(","))
    px = list(im.crop((x0, y0, x1, y1)).getdata())
    m = [round(sum(p[i] for p in px) / len(px)) for i in range(3)]
    lum = sorted(0.299*p[0]+0.587*p[1]+0.114*p[2] for p in px)
    print(f"{name:14s} box({x0},{y0},{x1},{y1}) mean {tuple(m)} lum mean {sum(lum)/len(lum):.0f} p10 {lum[len(lum)//10]:.0f} p50 {lum[len(lum)//2]:.0f}")

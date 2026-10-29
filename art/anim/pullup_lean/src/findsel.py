# prints screen y of the highlighted Explorer row (blue) in my Studio window, or nothing
from PIL import Image
im = Image.open("out/_scr.png").convert("RGB")
ys = [y for y in range(240, 400) if (lambda p: p[2] > 200 and p[0] < 90 and 90 < p[1] < 150)(im.getpixel((1100, y)))]
print((min(ys) + max(ys)) // 2 if ys else "")

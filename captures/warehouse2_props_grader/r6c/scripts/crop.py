import sys
from PIL import Image
src, out, box, scale = sys.argv[1], sys.argv[2], [int(x) for x in sys.argv[3].split(",")], float(sys.argv[4])
im = Image.open(src).convert("RGB").crop(box)
im = im.resize((int(im.width*scale), int(im.height*scale)), Image.LANCZOS)
im.save(out); print(out, im.size)

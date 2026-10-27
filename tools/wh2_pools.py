"""Warehouse 2: floor luminance straight down under / between the light bars (median of the centre 80 x 80 px of each
pool frame from tools/wh2_fastcap.py with out/warehouse2/cams_pools.json). Usage: python tools/wh2_pools.py <dir>"""
import glob, os, sys
from PIL import Image
for f in sorted(glob.glob(os.path.join(sys.argv[1], "new_pool_*.png"))):
    im = Image.open(f).convert("L")
    w, h = im.size
    px = sorted(im.crop((w // 2 - 40, h // 2 - 40, w // 2 + 40, h // 2 + 40)).getdata())
    print(os.path.basename(f)[9:-4], px[len(px) // 2])

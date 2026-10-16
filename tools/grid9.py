"""Contact grid of captures for a quick look. Usage: python tools/grid9.py out.jpg cols w a.png b.png ..."""
import sys
from PIL import Image
out, cols, w = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]); fs = sys.argv[4:]
h = int(w * 9 / 16); rows = (len(fs) + cols - 1) // cols
s = Image.new("RGB", (w * cols, h * rows))
for i, f in enumerate(fs):
    s.paste(Image.open(f).convert("RGB").resize((w, h)), ((i % cols) * w, (i // cols) * h))
s.save(out, quality=80)

from pathlib import Path
import json
import numpy as np
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parent
manifest = json.loads((root / 'generation.json').read_text())
sheet = Image.new('RGB', (1024, 576), '#303030')
draw = ImageDraw.Draw(sheet)
for i, item in enumerate(manifest):
    im = Image.open(item['source']).convert('RGBA')
    a = im.getchannel('A')
    if a.getextrema()[0] == 255:
        rgb = np.array(im).astype(float)
        # White over chroma green: red/blue measure foreground coverage.
        alpha = np.minimum(rgb[:,:,0], rgb[:,:,2])
        a = Image.fromarray(np.uint8(np.clip(alpha, 0, 255)))
    bbox = a.point(lambda p: 255 if p > 8 else 0).getbbox()
    a = a.crop(bbox)
    scale = 410 / max(a.size)
    a = a.resize(tuple(round(v * scale) for v in a.size), Image.Resampling.LANCZOS)
    canvas = Image.new('RGBA', (512, 512), (255,255,255,0))
    layer = Image.new('RGBA', a.size, 'white')
    layer.putalpha(a)
    canvas.paste(layer, ((512-a.width)//2, (512-a.height)//2))
    output = root / ('glyph_' + item['name'] + '.png')
    canvas.save(output)
    arr = np.array(canvas)
    assert canvas.size == (512,512)
    assert (arr[:,:,:3][arr[:,:,3]>0] == 255).all()
    assert arr[:,:,3].min() == 0 and arr[:,:,3].max() == 255
    x, y = (i%4)*256, (i//4)*288
    thumb = canvas.resize((224,224), Image.Resampling.LANCZOS)
    sheet.paste(thumb, (x+16,y+8), thumb)
    draw.text((x+16,y+246), output.name, fill='white')
    print(output.name, 'RGBA 512x512; white RGB; real alpha', canvas.getbbox())
sheet.save(root / 'contact.png')

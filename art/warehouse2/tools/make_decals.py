"""Warehouse 2 props: stencil masks and labels (own art, drawn with PIL, no image generation).
Writes art/warehouse2/tex/decals/*.png. Masks are white with the ink in alpha (the Blender material colours them);
labels (lbl_*, hz_*) are full colour. These are bake inputs only: they end up inside the props' baked atlases.
  python art/warehouse2/tools/make_decals.py
"""
import math, os, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "tex", "decals")
FONT = "C:/Windows/Fonts/bahnschrift.ttf"
RNG = np.random.default_rng(27)

# stencil bridges: x position (fraction of the glyph width) where the closed counters are cut, like a real stencil
BRIDGE = {"O": .5, "Q": .5, "0": .5, "8": .5, "6": .5, "9": .5, "D": .3, "B": .3, "P": .3, "R": .3, "A": .5, "4": .64,
          "&": .5, "@": .5}


def font(px, var="Bold Condensed"):
    f = ImageFont.truetype(FONT, px)
    f.set_variation_by_name(var)
    return f


def lowfreq(w, h, cells, lo=0.0, hi=1.0):
    n = RNG.random((max(2, h // cells), max(2, w // cells))).astype(np.float32)
    im = Image.fromarray((n * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC).filter(ImageFilter.GaussianBlur(cells / 3))
    a = np.asarray(im).astype(np.float32) / 255
    a = (a - a.min()) / max(1e-6, a.max() - a.min())
    return lo + a * (hi - lo)


def weather(alpha, strength=1.0, speck=0.08):
    """alpha: float array 0..1. Sprayed edge, patchy fade, speckle loss."""
    h, w = alpha.shape
    img = Image.fromarray((alpha * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.1))
    a = np.asarray(img).astype(np.float32) / 255
    fade = lowfreq(w, h, 48, 0.45, 1.0) ** (0.6 * strength)
    fine = lowfreq(w, h, 6, 0, 1)
    holes = (fine < speck * strength).astype(np.float32)
    a = a * fade * (1 - holes * 0.9)
    return np.clip(a, 0, 1)


def stencil_line(text, px, spacing=0.06):
    f = font(px)
    asc, desc = f.getmetrics()
    h = asc + desc
    glyphs, width = [], 0
    for ch in text:
        if ch == " ":
            adv = int(px * 0.32)
            glyphs.append((None, adv)); width += adv; continue
        bb = f.getbbox(ch)
        gw = max(1, bb[2])
        g = Image.new("L", (gw + 4, h), 0)
        ImageDraw.Draw(g).text((2, 0), ch, font=f, fill=255)
        if ch in BRIDGE:
            arr = np.asarray(g).copy()
            cols = np.where(arr.max(axis=0) > 128)[0]
            if len(cols):
                x0, x1 = cols.min(), cols.max()
                cx = int(x0 + (x1 - x0) * BRIDGE[ch])
                bw = max(2, int(px * 0.055))
                arr[:, cx - bw // 2: cx - bw // 2 + bw] = 0
            g = Image.fromarray(arr)
        adv = gw + int(px * spacing)
        glyphs.append((g, adv)); width += adv
    line = Image.new("L", (width + 8, h), 0)
    x = 4
    for g, adv in glyphs:
        if g is not None:
            line.paste(g, (x - 2, 0), g)
        x += adv
    bb = line.getbbox() or (0, 0, 1, 1)
    return line.crop((bb[0], 0, bb[2], h)), bb


def text_mask(lines, W, H, sizes=None, gap=0.18, strength=1.0):
    sizes = sizes or [1.0] * len(lines)
    total = sum(sizes) + gap * (len(lines) - 1)
    unit = H * 0.86 / total
    rendered = []
    for t, s in zip(lines, sizes):
        img, _ = stencil_line(t, int(unit * s * 1.25))
        bb = img.getbbox() or (0, 0, 1, 1)
        img = img.crop((0, bb[1], img.width, bb[3]))
        # fit width
        if img.width > W * 0.94:
            k = W * 0.94 / img.width
            img = img.resize((int(img.width * k), max(1, int(img.height * k))), Image.LANCZOS)
        rendered.append(img)
    canvas = Image.new("L", (W, H), 0)
    th = sum(r.height for r in rendered) + unit * gap * (len(lines) - 1)
    y = (H - th) / 2
    for r in rendered:
        canvas.paste(r, (int((W - r.width) / 2), int(y)))
        y += r.height + unit * gap
    a = weather(np.asarray(canvas).astype(np.float32) / 255, strength)
    return a


def save_mask(name, a):
    h, w = a.shape
    rgba = np.zeros((h, w, 4), np.uint8)
    rgba[..., :3] = 255
    rgba[..., 3] = (a * 255).astype(np.uint8)
    Image.fromarray(rgba, "RGBA").save(os.path.join(OUT, name + ".png"))
    print("decal", name, w, h)


def save_rgba(name, img):
    img.save(os.path.join(OUT, name + ".png"))
    print("label", name, img.size)


def arrows_mask(W=512, H=512):
    im = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(im)
    for cx in (W * 0.3, W * 0.7):
        sw, top, bot = W * 0.09, H * 0.08, H * 0.62
        d.rectangle([cx - sw / 2, top + H * 0.16, cx + sw / 2, bot], fill=255)
        d.polygon([(cx - W * 0.16, top + H * 0.2), (cx, top), (cx + W * 0.16, top + H * 0.2)], fill=255)
    line, _ = stencil_line("THIS SIDE UP", int(H * 0.16))
    k = min(1.0, W * 0.9 / line.width)
    line = line.resize((int(line.width * k), int(line.height * k)), Image.LANCZOS)
    im.paste(line, (int((W - line.width) / 2), int(H * 0.7)), line)
    return weather(np.asarray(im).astype(np.float32) / 255)


def emblem_mask(W=512):
    im = Image.new("L", (W, W), 0)
    d = ImageDraw.Draw(im)
    c, r = W / 2, W * 0.44
    d.ellipse([c - r, c - r, c + r, c + r], outline=255, width=int(W * 0.05))
    d.ellipse([c - r * 0.62, c - r * 0.62, c + r * 0.62, c + r * 0.62], outline=255, width=int(W * 0.035))
    t = int(W * 0.035)
    for a in range(4):  # crosshair ticks through the rings, broken at the centre (stencil)
        ang = a * math.pi / 2
        x0, y0 = c + math.cos(ang) * r * 0.3, c + math.sin(ang) * r * 0.3
        x1, y1 = c + math.cos(ang) * r * 1.08, c + math.sin(ang) * r * 1.08
        d.line([(x0, y0), (x1, y1)], fill=255, width=t)
    line, _ = stencil_line("TAC", int(W * 0.2))
    im.paste(line, (int(c - line.width / 2), int(c - line.height * 0.55)), line)
    # stencil gaps in the rings
    a = np.asarray(im).astype(np.float32) / 255
    for ang in (math.pi / 4, 3 * math.pi / 4, 5 * math.pi / 4, 7 * math.pi / 4):
        x, y = int(c + math.cos(ang) * r * 0.82), int(c + math.sin(ang) * r * 0.82)
        g = int(W * 0.022)
        yy, xx = np.ogrid[:W, :W]
        n = np.array([math.cos(ang + math.pi / 2), math.sin(ang + math.pi / 2)])
        dist = np.abs((xx - c) * n[0] + (yy - c) * n[1])
        along = (xx - c) * math.cos(ang) + (yy - c) * math.sin(ang)
        a[(dist < g) & (along > r * 0.45)] = 0
    return weather(a)


def flammable_label(W=512):
    """Own drawing of a class-3 style hazard diamond: red diamond, white keyline, black flame, '3', words. Worn."""
    S = W * 2
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    c = S / 2
    def dia(r):
        return [(c, c - r), (c + r, c), (c, c + r), (c - r, c)]
    d.polygon(dia(S * 0.49), fill=(236, 232, 218, 255))
    d.polygon(dia(S * 0.455), fill=(176, 30, 24, 255))
    d.line(dia(S * 0.425) + [dia(S * 0.425)[0]], fill=(236, 232, 218, 255), width=int(S * 0.012))
    # flame: three tongues from bezier-ish polygons
    def flame(cx, base, w, h, lean):
        """a tongue of flame: round belly at the base, curling to a sharp tip that leans sideways"""
        left, right = [], []
        for i in range(31):
            s = i / 30
            hw = w / 2 * ((1 - s) ** 0.6) * (1 - 0.25 * s) * (0.8 + 0.2 * math.sin(math.pi * min(1.0, s * 2.2)))
            off = lean * w * 0.5 * s ** 2
            y = base - h * s
            left.append((cx + off - hw, y)); right.append((cx + off + hw, y))
        belly = [(cx + w / 2 * math.cos(a), base + w * 0.18 * math.sin(a)) for a in [k * math.pi / 12 for k in range(13)]]
        return left + right[::-1] + belly
    base = c + S * 0.02
    d.polygon(flame(c, base - S * 0.01, S * 0.24, S * 0.34, 0.45), fill=(16, 14, 12, 255))
    d.polygon(flame(c - S * 0.1, base, S * 0.14, S * 0.2, -0.8), fill=(16, 14, 12, 255))
    d.polygon(flame(c + S * 0.1, base, S * 0.13, S * 0.18, 0.9), fill=(16, 14, 12, 255))
    d.rectangle([c - S * 0.17, base, c + S * 0.17, base + S * 0.03], fill=(16, 14, 12, 255))
    f = font(int(S * 0.07))
    txt = "FLAMMABLE"
    tw = d.textlength(txt, font=f)
    d.text((c - tw / 2, c + S * 0.09), txt, font=f, fill=(236, 232, 218, 255))
    f3 = font(int(S * 0.11))
    tw = d.textlength("3", font=f3)
    d.text((c - tw / 2, c + S * 0.2), "3", font=f3, fill=(16, 14, 12, 255))
    im = im.resize((W, W), Image.LANCZOS)
    arr = np.asarray(im).astype(np.float32)
    # wear: faded patches toward pink, scratches, a torn corner, grime
    fade = lowfreq(W, W, 40, 0, 1)
    arr[..., :3] = arr[..., :3] * (1 - 0.25 * fade[..., None]) + 190 * 0.25 * fade[..., None]
    grime = lowfreq(W, W, 12, 0, 1)
    arr[..., :3] *= (0.78 + 0.22 * grime)[..., None]
    sc = Image.new("L", (W, W), 0)
    sd = ImageDraw.Draw(sc)
    rnd = random.Random(4)
    for _ in range(40):
        x, y = rnd.uniform(0, W), rnd.uniform(0, W)
        a = rnd.uniform(-0.5, 0.5) + 0.3
        L = rnd.uniform(10, 60)
        sd.line([(x, y), (x + math.cos(a) * L, y + math.sin(a) * L)], fill=255, width=rnd.choice((1, 1, 2)))
    sc = np.asarray(sc).astype(np.float32) / 255
    arr[..., 3] *= 1 - 0.85 * sc
    yy, xx = np.mgrid[:W, :W]
    torn = (xx + yy * 0.8 > W * 1.55) & (lowfreq(W, W, 5, 0, 1) > 0.35)
    arr[..., 3][torn] = 0
    holes = lowfreq(W, W, 4, 0, 1) < 0.05
    arr[..., 3][holes] *= 0.2
    return Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA")


def hazard_stripes(W=512, H=128, period=64):
    yy, xx = np.mgrid[:H, :W].astype(np.float32)
    band = ((xx + yy) // (period / 2)) % 2
    col = np.where(band[..., None] == 0, np.array([222, 216, 198], np.float32), np.array([22, 22, 20], np.float32))
    fade = lowfreq(W, H, 20, 0, 1)[..., None]
    col = col * (0.72 + 0.28 * fade) + 40 * (1 - fade) * 0.3
    alpha = weather(np.ones((H, W), np.float32), 0.8, 0.12)
    out = np.dstack([np.clip(col, 0, 255), alpha * 255]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def drip_mask(W=256, H=512):
    """fuel weeping from the bung down the drum side: a wet patch at the top, runs of different length below"""
    im = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(im)
    rnd = random.Random(9)
    d.ellipse([W * 0.12, -H * 0.06, W * 0.88, H * 0.16], fill=200)
    for _ in range(9):
        x = rnd.uniform(W * 0.18, W * 0.82)
        L = rnd.uniform(H * 0.25, H * 0.95)
        w = rnd.uniform(5, 13)
        steps = 30
        pts = []
        for k in range(steps + 1):
            t = k / steps
            pts.append((x + math.sin(t * 5 + x) * 3, H * 0.08 + L * t, w * (1 - 0.55 * t)))
        for (x0, y0, w0), (x1, y1, w1) in zip(pts, pts[1:]):
            d.line([(x0, y0), (x1, y1)], fill=235, width=max(2, int(w0)))
        xe, ye, we = pts[-1]
        d.ellipse([xe - we * 0.9, ye - we * 0.9, xe + we * 0.9, ye + we * 1.2], fill=245)
    a = np.asarray(im.filter(ImageFilter.GaussianBlur(2.2))).astype(np.float32) / 255
    return np.clip(a * lowfreq(W, H, 30, 0.7, 1.0), 0, 1)


def main():
    os.makedirs(OUT, exist_ok=True)
    M = [
        ("st_rifle", ["RIFLE  5.56MM", "QTY 6    LOT 26-1027"], 1024, 256, [1.0, 0.62]),
        ("st_tacsupply", ["TAC SUPPLY CORPS"], 1024, 160, None),
        ("st_handle", ["HANDLE WITH CARE"], 1024, 128, None),
        ("st_ammo762", ["AMMUNITION", "7.62MM   1200 CTG"], 1024, 320, [1.0, 0.7]),
        ("st_weight", ["GROSS WT 210 LB", "CUBE 14.2 FT3"], 768, 256, None),
        ("st_engine", ["ENGINE ASSY", "M-35   TAC MOTOR POOL"], 1024, 320, [1.0, 0.55]),
        ("st_rations", ["FIELD RATIONS", "KEEP DRY"], 1024, 256, [1.0, 0.7]),
        ("st_id017", ["W2-017"], 512, 128, None),
        ("st_id044", ["W2-044"], 512, 128, None),
        ("st_id103", ["W2-103"], 512, 128, None),
        ("st_fuel", ["JP-8 FUEL", "UN 1863"], 768, 320, [1.0, 0.6]),
        ("st_bay02", ["BAY 02"], 1024, 256, None),
        ("st_keepclear", ["KEEP CLEAR"], 1024, 192, None),
        ("st_ammocan", ["7.62MM LINKED", "M80 BALL  200"], 768, 256, [1.0, 0.75]),
        ("st_motorpool", ["TAC MOTOR POOL", "FL-02"], 1024, 256, [1.0, 0.7]),
        ("st_capacity", ["CAP 2500 KG"], 512, 128, None),
        ("st_sandbag", ["TAC"], 256, 128, None),
    ]
    for name, lines, w, h, sizes in M:
        save_mask(name, text_mask(lines, w, h, sizes))
    save_mask("st_upright", arrows_mask())
    save_mask("st_emblem", emblem_mask())
    save_rgba("lbl_flammable", flammable_label())
    hz = hazard_stripes()
    save_rgba("hz_stripes", hz)
    save_rgba("hz_stripes_v", hazard_stripes(128, 512, 64))
    save_mask("fx_drip", drip_mask())


if __name__ == "__main__":
    main()

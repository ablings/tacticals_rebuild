"""1965 test-site House: seamless tiling textures (own work, procedural numpy + PIL; no reference texture traced).
  python art/house/v2/tools/make_tiles_1965.py
Writes art/house/v2/tex/tile/T_<name>.png and tiles.json (name -> studs per tile, for the UVs).
Wall textures are mapped with v measured from the storey's floor (build_house.py FLOOR_REL), so a texture can carry a
grime band at its bottom and a frieze at a fixed height. Image row 0 = the TOP of the tile (v = 1)."""
import json, math, os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "tex", "tile")
os.makedirs(OUT, exist_ok=True)
R = np.random.default_rng(1965)
GRIME = (170, 150, 115)


def pnoise(n, scale, seed=None, m=None):
    rng = np.random.default_rng(seed) if seed is not None else R
    m = m or n
    w = rng.standard_normal((m, n))
    fy = np.fft.fftfreq(m)[:, None]; fx = np.fft.fftfreq(n)[None, :]
    k = np.sqrt(fx ** 2 + fy ** 2)
    out = np.real(np.fft.ifft2(np.fft.fft2(w) * np.exp(-(k * scale) ** 2 * 2)))
    out -= out.min(); out /= max(out.max(), 1e-9)
    return out


def fbm(n, scales, weights, seed=0, m=None):
    acc = sum(w * pnoise(n, s, seed + i, m) for i, (s, w) in enumerate(zip(scales, weights)))
    acc -= acc.min(); return acc / acc.max()


def col(c):
    return np.array(c, np.float32)[None, None, :] / 255.0


def blend(base, other, m):
    m = np.clip(m, 0, 1)
    return base * (1 - m[..., None]) + other * m[..., None]


T = {}
def save(name, img, studs):
    im = np.clip(img * 255, 0, 255).astype(np.uint8)
    Image.fromarray(im).save(os.path.join(OUT, f"T_{name}.png"))
    T[name] = studs


def periodic_draw(n, draw_fn, bg, m=None):
    """draw on a 3x canvas with every motif repeated in the 8 neighbours, crop the centre: seamless"""
    m = m or n
    im = Image.new("RGB", (3 * n, 3 * m), bg)
    d = ImageDraw.Draw(im)
    for oy in (0, m, 2 * m):
        for ox in (0, n, 2 * n):
            draw_fn(d, ox, oy)
    return np.asarray(im.crop((n, m, 2 * n, 2 * m))).astype(np.float32) / 255.0


def paper_age(img, seed, yellow=0.06, n=None):
    """old paper: fibre noise, a faint yellowing, soft blotchy fading (stays periodic)"""
    h, w = img.shape[:2]
    fib = fbm(w, [0.8, 3], [0.6, 0.4], seed=seed, m=h)
    blot = fbm(w, [40, 120], [0.5, 0.5], seed=seed + 7, m=h)
    img = img * (0.95 + 0.07 * fib[..., None])
    img = blend(img, col((214, 196, 150)), yellow + 0.08 * blot)
    img = blend(img, col((236, 230, 210)), 0.06 * (1 - blot))     # sun-faded patches
    return img


def grime_band(img, studs, top=2.0, strength=0.22, seed=0):
    """tan grime from the floor (bottom rows) up to `top` studs, patchy"""
    h, w = img.shape[:2]
    z = (h - 1 - np.arange(h))[:, None] / h * studs           # height above the floor of each row
    g = np.clip(1 - z / top, 0, 1) ** 1.6
    nz = fbm(w, [6, 30], [0.5, 0.5], seed=seed + 99, m=h)
    g = g * (0.55 + 0.7 * nz) * strength
    bottom = np.clip(1 - z / 0.35, 0, 1) * 0.25                  # scuffed dark line just above the baseboard
    img = blend(img, col(GRIME), g)
    return blend(img, col((70, 58, 44)), bottom * (0.4 + 0.6 * nz))


def leaf(d, cx, cy, ang, L, W, fill, vein=None):
    pts = []
    for i in range(13):
        t = i / 12
        x = (t - 0.5) * L
        y = W / 2 * math.sin(math.pi * t) * (1 if i <= 6 else 1)
        pts.append((x, y))
    pts += [((0.5 - i / 12) * L, -W / 2 * math.sin(math.pi * (1 - i / 12))) for i in range(13)]
    c, s = math.cos(ang), math.sin(ang)
    P = [(cx + x * c - y * s, cy + x * s + y * c) for x, y in pts]
    d.polygon(P, fill=fill)
    if vein:
        d.line([P[0], P[13]], fill=vein, width=1)


# ------------------------------------------------------------------------------------------------ wallpapers (4 studs)
def sprig_paper(name, ground, print_, accent, seed):
    n = 512
    rng = np.random.default_rng(seed)
    pr = tuple(print_); ac = tuple(accent)
    spots = []
    for gy in range(4):                       # half-drop grid: 4 x 4 sprigs per tile (one per stud)
        for gx in range(4):
            spots.append(((gx + 0.5 + (0.5 if gy % 2 else 0)) * n / 4, (gy + 0.5) * n / 4, rng.uniform(-0.6, 0.6), rng.random()))
    def draw(d, ox, oy):
        for (x, y, a, r) in spots:
            x += ox; y += oy
            c, s = math.cos(a), math.sin(a)
            stem = [(x + (t - 0.5) * 70 * s + 6 * math.sin(t * 3) * c, y - (t - 0.5) * 70 * c + 6 * math.sin(t * 3) * s) for t in np.linspace(0, 1, 8)]
            d.line(stem, fill=pr, width=3)
            for k, t in enumerate(np.linspace(0.15, 0.95, 6)):
                px, py = stem[min(7, int(t * 7))]
                side = 1 if k % 2 else -1
                leaf(d, px + side * 9 * c, py + side * 9 * s, a + side * 0.9 - math.pi / 2, 24, 9, pr)
            d.ellipse((stem[-1][0] - 6, stem[-1][1] - 6, stem[-1][0] + 6, stem[-1][1] + 6), fill=ac)
            if r > 0.5:
                d.ellipse((stem[0][0] - 4, stem[0][1] - 4, stem[0][0] + 4, stem[0][1] + 4), fill=ac)
        # tiny dots between sprigs
        for (x, y, a, r) in spots:
            d.ellipse((x + ox + 60 - 2, y + oy + 30 - 2, x + ox + 60 + 2, y + oy + 30 + 2), fill=pr)
    img = periodic_draw(n, draw, tuple(ground))
    img = np.asarray(Image.fromarray((img * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.7))).astype(np.float32) / 255
    return paper_age(img, seed)


def vine_paper(name, ground, vine, leafc, seed):
    n = 512
    rng = np.random.default_rng(seed)
    def draw(d, ox, oy):
        for k in range(2):                      # two trailing vines per tile (every 2 studs), phase-shifted
            x0 = (k + 0.5) * n / 2
            ph = k * math.pi
            pts = [(ox + x0 + 38 * math.sin(2 * math.pi * t * 2 + ph), oy + t * n) for t in np.linspace(-0.05, 1.05, 60)]
            d.line(pts, fill=tuple(vine), width=4)
            for j in range(10):
                t = j / 10
                y = t * n
                x = x0 + 38 * math.sin(2 * math.pi * t * 2 + ph)
                side = 1 if j % 2 else -1
                dx = math.cos(2 * math.pi * t * 2 + ph)
                leaf(d, ox + x + side * 20, oy + y, side * 0.5 + dx * 0.3, 36, 14, tuple(leafc), tuple(vine))
                if j % 3 == 0:
                    tx = ox + x - side * 18
                    d.arc((tx - 10, oy + y - 10, tx + 10, oy + y + 10), 0, 270, fill=tuple(vine), width=2)
    img = periodic_draw(n, draw, tuple(ground))
    img = np.asarray(Image.fromarray((img * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.7))).astype(np.float32) / 255
    return paper_age(img, seed)


def diamond_paper(seed):
    """our kitchen geometric: stepped diamonds (cream fill, tan outline) on mint-sage, 2 per stud row"""
    n = 512
    g, cr, tan = (192, 202, 158), (228, 222, 186), (172, 142, 94)
    s = n / 4
    def draw(d, ox, oy):
        for gy in range(4):
            for gx in range(4):
                cx = ox + (gx + 0.5 + (0.5 if gy % 2 else 0)) * s; cy = oy + (gy + 0.5) * s
                for r, fill in ((52, tan), (46, cr), (30, tan), (25, g), (12, tan)):
                    st = 4   # stepped edge: a diamond made of steps
                    pts = []
                    for i in range(st + 1):
                        pts += [(cx + r * i / st, cy - r + r * i / st), (cx + r * (i + 1) / st if i < st else cx + r, cy - r + r * i / st)]
                    q = []
                    for (x, y) in pts:
                        q.append((x, y))
                    full = q + [(2 * cx - x, y) for (x, y) in reversed(q)]
                    full = full + [(x, 2 * cy - y) for (x, y) in reversed(full)]
                    d.polygon(full, fill=fill)
    img = periodic_draw(n, draw, g)
    return paper_age(img, seed, yellow=0.08)


# ------------------------------------------------------------------------------------------------ wood
def boards(n, m, nboards, base, seed, vertical=True, knots=0, gap=3, tone_var=0.12):
    rng = np.random.default_rng(seed)
    img = np.zeros((m, n, 3), np.float32)
    bw = n // nboards
    for b in range(nboards):
        g = pnoise(bw * 4, 2.0, seed + b, m)[:, :bw] if vertical else None
        streaks = fbm(bw, [0.6, 2.5], [0.5, 0.5], seed=seed + 10 + b, m=m)
        # grain runs along the board (vertical): stretch noise along y
        long = np.repeat(pnoise(bw, 1.5, seed + 30 + b, 64), m // 64 + 1, axis=0)[:m]
        gr = 0.72 + 0.22 * long + 0.1 * streaks
        tone = rng.uniform(1 - tone_var, 1 + tone_var)
        img[:, b * bw:(b + 1) * bw] = col(base) * tone * gr[..., None]
        for _ in range(knots):
            kx, ky = rng.uniform(bw * 0.25, bw * 0.75), rng.uniform(0, m)
            yy, xx = np.mgrid[0:m, 0:bw]
            dd = np.sqrt(((xx - kx) / 1.0) ** 2 + ((yy - ky) / 1.8) ** 2)
            for wrap in (-m, 0, m):
                dd2 = np.sqrt(((xx - kx)) ** 2 + ((yy - ky - wrap) / 1.8) ** 2)
                k = np.clip(1 - dd2 / rng.uniform(7, 14), 0, 1)
                ring = 0.5 + 0.5 * np.sin(dd2 * 0.9)
                img[:, b * bw:(b + 1) * bw] = blend(img[:, b * bw:(b + 1) * bw], col((86, 54, 24)), k * (0.6 + 0.4 * ring))
        img[:, b * bw:b * bw + gap] *= 0.45
    if not vertical:
        img = np.transpose(img, (1, 0, 2))
    return img


# ------------------------------------------------------------------------------------------------ tiles
def square_tiles(n, m, count_x, count_y, colour, grout, seed, var=0.05, crackle=0.0):
    rng = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:m, 0:n]
    cw, ch = n / count_x, m / count_y
    ix, iy = (xx // cw).astype(int), (yy // ch).astype(int)
    tone = rng.uniform(1 - var, 1 + var, (count_y + 1, count_x + 1))
    img = col(colour) * tone[iy, ix][..., None]
    nz = fbm(n, [2, 12], [0.5, 0.5], seed=seed, m=m)
    img = img * (0.96 + 0.06 * nz[..., None])
    gx = np.minimum(xx % cw, cw - xx % cw); gy = np.minimum(yy % ch, ch - yy % ch)
    gm = (np.minimum(gx, gy) < 2.5).astype(np.float32)
    # glaze highlight inside each tile edge
    hl = ((np.minimum(gx, gy) >= 2.5) & (np.minimum(gx, gy) < 6)).astype(np.float32) * 0.06
    img = img * (1 + hl[..., None])
    img = blend(img, col(grout), gm)
    if crackle:
        cr = fbm(n, [0.5], [1.0], seed=seed + 3, m=m)
        img = blend(img, col((120, 110, 90)), (np.abs(cr - 0.5) < 0.008).astype(np.float32) * crackle)
    return img


def tile_wall(name, colour, line, seed, studs=4.5, per=6):
    """square wall tiles from the floor to the band top, a black bullnose line at the top, grime at the bottom"""
    n = 512
    img = square_tiles(n, n, per, per, colour, (150, 146, 132), seed, crackle=0.5)
    rows = n
    z = (rows - 1 - np.arange(rows))[:, None] / rows * studs
    top = ((z > studs - 0.32) & (z <= studs - 0.08)).astype(np.float32)
    img = blend(img, col(line), np.repeat(top, n, axis=1))
    edge = ((z > studs - 0.08)).astype(np.float32)
    img = blend(img, col(colour) * 0.9, np.repeat(edge, n, axis=1))
    img = grime_band(img, studs, top=1.5, strength=0.18, seed=seed)
    save(name, img, studs)


def main():
    n = 512
    # wallpapers (absolute v from the floor; 4 studs per tile)
    sp = sprig_paper("PaperSprig", (224, 214, 168), (128, 136, 98), (176, 120, 104), 11)
    save("PaperSprig", sp, 3.5)
    rose = sprig_paper("PaperSprigRose", (230, 218, 188), (176, 120, 104), (128, 136, 98), 12)
    save("PaperSprigRose", rose, 3.5)
    vine = vine_paper("PaperVine", (200, 202, 168), (78, 92, 66), (110, 124, 86), 13)
    save("PaperVine", vine, 3.5)
    vy = vine_paper("PaperVineYellow", (228, 214, 152), (110, 110, 70), (150, 150, 92), 14)
    save("PaperVineYellow", vy, 3.5)
    save("PaperDiamond", diamond_paper(15), 3.5)
    # the same papers as a lower band with grime (bedrooms: no wainscot)
    save("PaperSprigRoseLow", grime_band(rose.copy(), 4.0, seed=21), 3.5)
    # bedroom 3 frieze: rockets and stars painted at 2.6..3.4 over the yellow vine, grime below
    fr = Image.fromarray((vy * 255).astype(np.uint8))
    d = ImageDraw.Draw(fr)
    z2y = lambda z: int(n - z / 4.0 * n)
    y0, y1 = z2y(3.4), z2y(2.6)
    d.rectangle((0, y0, n, y1), fill=(222, 206, 150))
    d.rectangle((0, y0, n, y0 + 4), fill=(107, 122, 58)); d.rectangle((0, y1 - 4, n, y1), fill=(107, 122, 58))
    for k in range(2):
        cx = k * n / 2 + n / 4; cy = (y0 + y1) / 2
        d.polygon([(cx - 40, cy + 12), (cx + 30, cy + 12), (cx + 52, cy), (cx + 30, cy - 12), (cx - 40, cy - 12)], fill=(236, 232, 218), outline=(60, 50, 40))
        d.polygon([(cx - 40, cy - 12), (cx - 56, cy - 26), (cx - 30, cy - 12)], fill=(138, 156, 74))
        d.polygon([(cx - 40, cy + 12), (cx - 56, cy + 26), (cx - 30, cy + 12)], fill=(138, 156, 74))
        d.ellipse((cx + 2, cy - 6, cx + 14, cy + 6), fill=(90, 110, 120))
        d.polygon([(cx - 40, cy - 7), (cx - 66, cy), (cx - 40, cy + 7)], fill=(206, 160, 52))
        for sx in (-90, 90, 120):
            sx_ = cx + sx
            d.polygon([(sx_, cy - 10), (sx_ + 3, cy - 3), (sx_ + 10, cy), (sx_ + 3, cy + 3), (sx_, cy + 10), (sx_ - 3, cy + 3), (sx_ - 10, cy), (sx_ - 3, cy - 3)], fill=(206, 160, 52))
    fri = np.asarray(fr.filter(ImageFilter.GaussianBlur(0.6))).astype(np.float32) / 255
    fri = paper_age(fri, 31, yellow=0.04)
    save("PaperVineYellowLow", grime_band(fri, 4.0, seed=22), 3.5)
    # walnut wainscot: vertical boards 0.63 (5 per 3.15 tile), grime band, a darker cap shadow under the rail
    wn = boards(n, n, 5, (82, 54, 30), 41, knots=0)
    wn = paper_age(wn, 42, yellow=0.0) * 1.0
    save("Wainscot", grime_band(wn, 3.15, top=2.0, strength=0.26, seed=43), 3.15)
    # painted walls (coffee brown, mustard) as low (grime) and high bands
    for nm, c in (("PaintCoffee", (98, 74, 46)), ("PaintMustard", (198, 160, 58))):
        nz = fbm(n, [1.5, 8, 60], [0.3, 0.3, 0.4], seed=len(nm))
        img = col(c) * (0.93 + 0.1 * nz[..., None])
        img = blend(img, col((214, 196, 150)), 0.05 + 0.08 * fbm(n, [80], [1], seed=5))
        save(nm, img, 3.5)
        save(nm + "Low", grime_band(img.copy(), 4.0, seed=len(nm) + 3), 3.5)
    # pegboard (mudroom, above the coffee band): hardboard with a 0.5-stud hole grid
    nz = fbm(n, [1.2, 10], [0.6, 0.4], seed=51)
    img = col((176, 150, 110)) * (0.9 + 0.14 * nz[..., None])
    yy, xx = np.mgrid[0:n, 0:n]
    p = n / 8
    dd = np.sqrt((xx % p - p / 2) ** 2 + (yy % p - p / 2) ** 2)
    img = blend(img, col((40, 30, 20)), (dd < 6).astype(np.float32))
    img = blend(img, col((120, 96, 66)), ((dd >= 6) & (dd < 8)).astype(np.float32) * 0.6)
    save("Pegboard", img, 4.0)
    # knotty pine panelling, vertical boards 0.6 (8 per 4.8)
    pine = boards(n, n, 8, (168, 114, 58), 61, knots=1, tone_var=0.14)
    save("Pine", grime_band(pine, 4.8, top=1.5, strength=0.15, seed=62), 4.8)
    # fieldstone: stacked rough stones 1-2 studs, deep mortar (6-stud tile)
    rng = np.random.default_rng(71)
    m = n
    pts = np.array([(rng.uniform(0, n), rng.uniform(0, m)) for _ in range(22)])
    yy, xx = np.mgrid[0:m, 0:n].astype(np.float32)
    d1 = np.full((m, n), 1e9); d2 = np.full((m, n), 1e9); idx = np.zeros((m, n), int)
    for i, (px, py) in enumerate(pts):
        for ox in (-n, 0, n):
            for oy in (-m, 0, m):
                dd = np.sqrt(((xx - px - ox) * 1.0) ** 2 + ((yy - py - oy) * 1.45) ** 2)   # flatter stones: stacked look
                closer = dd < d1
                d2 = np.where(closer, d1, np.minimum(d2, dd)); idx = np.where(closer, i, idx); d1 = np.where(closer, dd, d1)
    edge = d2 - d1
    stones = [(118, 108, 92), (86, 78, 66), (142, 132, 112), (104, 96, 82), (128, 114, 94)]
    sc = np.array(stones, np.float32)[np.arange(len(pts)) % len(stones)] / 255
    img = sc[idx] * (0.85 + 0.25 * fbm(n, [1, 4, 14], [0.4, 0.3, 0.3], seed=72)[..., None])
    shade = np.clip(edge / 26, 0, 1) ** 0.6           # stone faces bulge: darker toward the mortar
    img = img * (0.6 + 0.4 * shade[..., None])
    img = blend(img, col((70, 64, 54)), (edge < 7).astype(np.float32))
    img = blend(img, col((44, 40, 34)), (edge < 3.5).astype(np.float32) * 0.7)
    save("Fieldstone", img, 6.0)
    # bathroom tiles to 4.5: mint (ground), butter (upper), pink (ensuite), cream (kitchen low band)
    tile_wall("TileMint", (176, 204, 182), (24, 24, 22), 81)
    tile_wall("TileButter", (232, 214, 140), (24, 24, 22), 82)
    tile_wall("TilePink", (222, 176, 170), (40, 34, 30), 83)
    tile_wall("TileCream", (230, 222, 194), (138, 156, 74), 84)
    # ceiling: yellowed white, roller marks
    nz = fbm(n, [2, 10, 90], [0.3, 0.3, 0.4], seed=91)
    img = col((222, 214, 190)) * (0.94 + 0.08 * nz[..., None])
    save("Ceiling65", img, 8.0)
    # reveals / jambs: yellowed cream paint
    nz = fbm(n, [2, 30], [0.5, 0.5], seed=92)
    save("PaintCream", col((214, 206, 182)) * (0.94 + 0.08 * nz[..., None]), 8.0)
    # trim walnut (darker), along the strip
    tw = boards(n, n, 1, (58, 40, 24), 93, gap=0, tone_var=0.0)
    tw = np.transpose(tw, (1, 0, 2))
    save("TrimWalnut", tw, 4.0)

    # ---------------------------------------------------------------------------------------- floors
    # herringbone parquet: 0.4 x 1.6 blocks (4-stud tile), worn and dull
    n = 1024
    img = np.zeros((n, n, 3), np.float32)
    yy, xx = np.mgrid[0:n, 0:n].astype(np.float32)
    s = n / 4.0                       # px per stud
    bw, bl = 0.4 * s, 1.6 * s
    # herringbone: rotate 45 and use a two-direction zig-zag on a 2*bw period
    u = (xx + yy) / math.sqrt(2); v = (yy - xx) / math.sqrt(2)
    per = n * math.sqrt(2) / 8         # period along u that tiles the square
    col_i = np.floor(u / (per / 2)).astype(int)
    dirn = col_i % 2
    along = np.where(dirn == 0, v + col_i * 7.0, -v + col_i * 7.0)
    blk = np.floor(along / (per / 2 * 2)).astype(int)
    fr = (along / (per)) % 1.0
    rng = np.random.default_rng(101)
    tone = rng.uniform(0.82, 1.15, 4096)
    ti = (col_i * 131 + blk * 17) % 4096
    grain = fbm(n, [1.0, 4], [0.6, 0.4], seed=102)
    img = col((118, 82, 48)) * tone[ti][..., None] * (0.8 + 0.3 * grain[..., None])
    jm = (np.minimum(fr, 1 - fr) * per < 2.0) | ((u % (per / 2)) < 2.0)
    img = blend(img, col((44, 30, 18)), jm.astype(np.float32) * 0.8)
    wear = fbm(n, [40, 160], [0.5, 0.5], seed=103)
    img = blend(img, col((160, 128, 92)), 0.25 * wear)
    save("Parquet", img, 4.0)
    n = 512
    # checker lino A (cream / rust-tan) and B (off-black / bone), 1-stud squares, scuffs and a few cracks
    for nm, a, b, sd in (("LinoA", (236, 224, 182), (196, 142, 98), 111), ("LinoB", (36, 34, 30), (222, 216, 198), 112)):
        yy, xx = np.mgrid[0:n, 0:n]
        c = ((xx // (n // 4)) + (yy // (n // 4))) % 2
        img = np.where(c[..., None] == 0, col(a), col(b)) + np.zeros((n, n, 3), np.float32)
        nz = fbm(n, [1.5, 12, 80], [0.3, 0.3, 0.4], seed=sd)
        img = img * (0.92 + 0.12 * nz[..., None])
        scuff = fbm(n, [3, 20], [0.6, 0.4], seed=sd + 1)
        img = blend(img, col((96, 84, 66)), np.clip((scuff - 0.62) * 2.5, 0, 1) * 0.35)
        cr = fbm(n, [0.6, 3], [0.7, 0.3], seed=sd + 2)
        img = blend(img, col((70, 60, 48)), (np.abs(cr - 0.5) < 0.006).astype(np.float32) * 0.6)
        gl = ((xx % (n // 4) < 2) | (yy % (n // 4) < 2)).astype(np.float32)
        img = blend(img, col((90, 80, 64)), gl * 0.5)
        save(nm, img, 4.0)
    # carpets: gold, greige (flecked loop pile), carpet tiles mustard / olive (2-stud squares)
    for nm, c, fl, sd in (("CarpetGold", (186, 150, 70), (140, 130, 104), 121), ("CarpetGreige", (140, 130, 104), (110, 100, 80), 122)):
        nz = fbm(n, [0.5, 1.5, 30], [0.4, 0.3, 0.3], seed=sd)
        img = col(c) * (0.82 + 0.3 * nz[..., None])
        fleck = (pnoise(n, 0.6, sd + 5) > 0.72).astype(np.float32)
        img = blend(img, col(fl), fleck * 0.6)
        tracks = fbm(n, [50, 150], [0.5, 0.5], seed=sd + 7)
        img = blend(img, col((120, 104, 80)), np.clip(tracks - 0.5, 0, 1) * 0.5)
        save(nm, img, 6.0)
    yy, xx = np.mgrid[0:n, 0:n]
    c = ((xx // (n // 2)) + (yy // (n // 2))) % 2
    nz = fbm(n, [0.5, 1.5, 20], [0.4, 0.3, 0.3], seed=131)
    img = np.where(c[..., None] == 0, col((200, 165, 60)), col((107, 122, 58))) * (0.84 + 0.26 * nz[..., None])
    img = blend(img, col((60, 50, 36)), (((xx % (n // 2)) < 2) | ((yy % (n // 2)) < 2)).astype(np.float32) * 0.6)
    save("CarpetTiles", img, 4.0)
    # small hex tiles, white with a black flower every few (3-stud tile)
    im = Image.new("RGB", (n, n), (150, 146, 136))
    d = ImageDraw.Draw(im)
    rr = n / 12.0
    hw = rr * math.sqrt(3)
    rng = np.random.default_rng(141)
    for j in range(-1, int(n / (1.5 * rr)) + 2):
        for i in range(-1, int(n / hw) + 2):
            cx = i * hw + (hw / 2 if j % 2 else 0); cy = j * 1.5 * rr
            black = (i % 4 == 0 and j % 4 == 0) or (i % 4 == 2 and j % 4 == 2)
            k_ = rng.uniform(0.95, 1.03)
            f = (28, 28, 28) if black else tuple(int(v * k_) for v in (228, 224, 214))
            for ox in (-n, 0, n):
                for oy in (-n, 0, n):
                    d.polygon([(cx + ox + (rr - 2) * math.cos(math.pi / 6 + k * math.pi / 3), cy + oy + (rr - 2) * math.sin(math.pi / 6 + k * math.pi / 3)) for k in range(6)], fill=f)
    img = np.asarray(im).astype(np.float32) / 255
    img = blend(img, col((150, 136, 110)), 0.12 * fbm(n, [20, 80], [0.5, 0.5], seed=142))
    save("HexTile", img, 3.0)

    # ---------------------------------------------------------------------------------------- exterior
    # desert floor: tan sand, pebbles, wind ripples, dry cracks
    nz = fbm(n, [0.6, 3, 30, 120], [0.25, 0.25, 0.25, 0.25], seed=151)
    img = col((196, 170, 128)) * (0.82 + 0.3 * nz[..., None])
    yy, xx = np.mgrid[0:n, 0:n]
    rip = 0.5 + 0.5 * np.sin((yy + 18 * pnoise(n, 30, 152)) * 2 * math.pi / (n / 16))
    img = img * (0.96 + 0.05 * rip[..., None])
    peb = (pnoise(n, 0.7, 153) > 0.78).astype(np.float32)
    img = blend(img, col((120, 104, 82)), peb * 0.6)
    save("Desert", img, 16.0)
    # dry patchy lawn
    nz = fbm(n, [0.5, 2, 30, 100], [0.3, 0.3, 0.2, 0.2], seed=161)
    sand = col((190, 166, 124)) * (0.85 + 0.25 * nz[..., None])
    grass = col((138, 138, 84)) * (0.7 + 0.4 * fbm(n, [0.4, 1.2], [0.6, 0.4], seed=162)[..., None])
    img = blend(sand, grass, np.clip((fbm(n, [25, 80], [0.5, 0.5], seed=163) - 0.35) * 2.2, 0, 1))
    save("DryGrass", img, 12.0)
    # worn asphalt with cracks and sand
    nz = fbm(n, [0.6, 4, 60], [0.5, 0.3, 0.2], seed=171)
    img = col((78, 76, 72)) * (0.82 + 0.3 * nz[..., None])
    cr = fbm(n, [1.5, 6], [0.7, 0.3], seed=172)
    img = blend(img, col((34, 32, 30)), (np.abs(cr - 0.5) < 0.008).astype(np.float32))
    img = blend(img, col((176, 154, 118)), np.clip(fbm(n, [30, 90], [0.5, 0.5], seed=173) - 0.6, 0, 1) * 1.4)
    save("Asphalt65", img, 12.0)
    # concrete (curbs, driveway, steps), stained
    nz = fbm(n, [1.5, 10, 80], [0.3, 0.4, 0.3], seed=181)
    img = col((168, 162, 150)) * (0.88 + 0.15 * nz[..., None])
    gm = ((xx % (n // 2) < 3) | (yy % (n // 2) < 3)).astype(np.float32)
    img = blend(img, col((100, 96, 88)), gm)
    img = blend(img, col((120, 104, 80)), np.clip(fbm(n, [40], [1], seed=182) - 0.55, 0, 1) * 1.2)
    save("Concrete65", img, 10.0)
    # lap siding 0.6 boards (10 per 6-stud tile), weathered paint: white (our house), mint, butter, salmon (houses across)
    for nm, c, sd in (("SidingWhite", (226, 222, 206), 191), ("SidingMint", (170, 206, 182), 192), ("SidingButter", (232, 214, 140), 193),
                      ("SidingSalmon", (226, 170, 150), 194)):
        nz = fbm(n, [1.5, 20], [0.5, 0.5], seed=sd)
        bh = n // 10
        sh = (yy % bh) / bh
        img = col(c) * (0.8 + 0.2 * sh[..., None]) * (0.94 + 0.08 * nz[..., None])
        img = blend(img, col((60, 54, 46)), ((yy % bh) < 3).astype(np.float32) * 0.7)
        peel = np.clip((fbm(n, [2, 8], [0.6, 0.4], seed=sd + 1) - 0.7) * 6, 0, 1)
        img = blend(img, col((150, 132, 104)), peel * 0.85)           # bare grey-brown wood where the paint peeled
        dust = np.clip(1 - (n - 1 - yy) / (n * 0.4), 0, 1)              # sand-blasted toward the bottom of each tile row? keep light
        img = blend(img, col((196, 170, 128)), 0.08 + 0.1 * fbm(n, [60], [1], seed=sd + 2))
        save(nm, img, 6.0)
    # asphalt shingles, faded (6-stud tile, 0.6 courses, staggered tabs)
    nz = fbm(n, [0.6, 10], [0.6, 0.4], seed=201)
    rowh = n // 10
    r = yy // rowh
    tabw = n // 6
    tx = (xx + (r % 2) * (tabw // 2)) % tabw
    rng = np.random.default_rng(202)
    tone = rng.uniform(0.85, 1.15, (11, 7))
    t = tone[np.clip(r, 0, 10), np.clip(((xx + (r % 2) * (tabw // 2)) // tabw) % 7, 0, 6)]
    img = col((104, 96, 86)) * t[..., None] * (0.85 + 0.25 * nz[..., None])
    img = blend(img, col((40, 36, 32)), ((yy % rowh) < 4).astype(np.float32) * 0.8)
    img = blend(img, col((40, 36, 32)), (tx < 3).astype(np.float32) * 0.6 * ((yy % rowh) > rowh * 0.4))
    save("Shingle", img, 6.0)
    # weathered grey fence / picket boards (horizontal tile, boards run vertically)
    fw = boards(n, n, 8, (150, 140, 120), 211, tone_var=0.15)
    save("FenceWood", fw, 6.0)
    # tar-and-gravel flat roof
    nz = fbm(n, [0.8, 3], [0.6, 0.4], seed=221)
    save("Gravel65", col((122, 114, 100)) * (0.78 + 0.35 * nz[..., None]), 6.0)
    # weathered white trim paint (window frames, fascia, porch posts of the far houses)
    nz = fbm(n, [1.5, 12], [0.5, 0.5], seed=231)
    img = col((226, 222, 206)) * (0.9 + 0.1 * nz[..., None])
    peel = np.clip((fbm(n, [2, 6], [0.6, 0.4], seed=232) - 0.68) * 6, 0, 1)
    img = blend(img, col((140, 126, 100)), peel * 0.8)
    save("TrimWhite", img, 4.0)
    # mesa rock: horizontal sandstone strata (v = height), weathered streaks
    yy, xx = np.mgrid[0:n, 0:n]
    band = pnoise(n, 3, 241).mean(axis=1, keepdims=True)
    strata = 0.5 + 0.5 * np.sin(yy * 2 * math.pi / (n / 9) + 6 * band)
    base = blend(col((176, 120, 82)) + np.zeros((n, n, 3), np.float32), col((206, 170, 128)), strata)
    streak = np.repeat(pnoise(n, 2, 242, 64).mean(axis=0, keepdims=True), n, axis=0)
    img = base * (0.8 + 0.25 * fbm(n, [1, 6], [0.5, 0.5], seed=243)[..., None]) * (0.9 + 0.15 * streak[..., None])
    save("MesaRock", img, 40.0)
    # packed dirt road with two worn wheel ruts along u and gravel
    nz = fbm(n, [0.6, 4, 40], [0.4, 0.3, 0.3], seed=251)
    img = col((170, 146, 110)) * (0.82 + 0.28 * nz[..., None])
    rut = np.exp(-((yy % (n // 2) - n // 4) / (n * 0.05)) ** 2)
    img = blend(img, col((128, 108, 82)), rut * 0.5)
    img = blend(img, col((110, 98, 80)), (pnoise(n, 0.6, 252) > 0.8).astype(np.float32) * 0.6)
    save("DirtRoad", img, 12.0)
    json.dump(T, open(os.path.join(OUT, "tiles.json"), "w"), indent=1)
    print("tiles:", len(T), T)


main()

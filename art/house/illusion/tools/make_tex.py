"""House illusion pass: own procedural textures (numpy + PIL, no reference art). One run writes every atlas:
    python art/house/illusion/tools/make_tex.py
tex/X_Ground.png    desert ground ring: U = 12 repeats round the ring (seamless in U), V = sqrt radial 850 -> 4,000
                    (inner rows match the v2 T_Desert tile, outer rows = haze (214,196,166)); dunes, tracks, scrub dots
tex/X_Mesa.png      three full-width bands (tier 1 bottom, tier 2 middle, tier 3 top), each seamless in U; V = absolute
                    height in the tier: strata, desert varnish streaks, talus; tier colours fade toward the haze
tex/X_Town.png      4 colourway bands (butter, salmon, mint, white) with the same layout: siding, fieldstone, shingle,
                    trim, 2-over-2 glass, door, concrete, dark
tex/X_Site.png      test-site atlas: steel, water-tank wrap with our own 'T-7' stencil, concrete, blast door, burlap bags,
                    corrugated iron, quonset end wall with our own 'B-4', hangar doors, timber, pole wood, wire, insulator
tex/X_ChainLink.png RGBA: diamond wire mesh (alpha) in the top 7/8, opaque galvanised post band in the bottom 1/8
tex/X_Near.png      driveway slab (cracked concrete, joints, oil, tyre marks, sand) + doormat, milk crate, iron
Writes tex/regions.json (pixel rects, y down from the top) for the Blender builder."""
import os, json, math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, ".."))
TEX = os.path.join(ROOT, "tex")
V2T = os.path.abspath(os.path.join(ROOT, "..", "v2", "tex", "tile"))
os.makedirs(TEX, exist_ok=True)
HAZE = np.array([214, 196, 166], np.float32)
REG = {}


def pnoise(h, w, beta=2.0, ax=1.0, ay=1.0, seed=0):
    """periodic 1/f^beta noise, std 1. ax / ay > 1 suppress that axis' frequencies (features stretch along it)"""
    rng = np.random.default_rng(seed)
    F = np.fft.fft2(rng.standard_normal((h, w)))
    fy = np.fft.fftfreq(h)[:, None] * ay
    fx = np.fft.fftfreq(w)[None, :] * ax
    f = np.sqrt(fx ** 2 + fy ** 2)
    f[0, 0] = 1.0
    amp = 1.0 / f ** beta
    amp[0, 0] = 0.0
    n = np.real(np.fft.ifft2(F * amp))
    return (n - n.mean()) / (n.std() + 1e-9)


def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def fill_unused(out, rects, offset_rows=()):
    """edge-extend every used rect into the unused pixels so mip / bilinear bleed never pulls in black"""
    from scipy.ndimage import distance_transform_edt
    used = np.zeros(out.shape[:2], bool)
    for oy in (offset_rows or (0,)):
        for (x0, y0, x1, y1) in rects:
            used[oy + y0:oy + y1, x0:x1] = True
    _, (iy, ix) = distance_transform_edt(~used, return_indices=True)
    return out[iy, ix]


def save(name, arr, alpha=None):
    a = np.clip(arr, 0, 255).astype(np.uint8)
    if alpha is not None:
        a = np.concatenate([a, np.clip(alpha, 0, 255).astype(np.uint8)[..., None]], axis=2)
        Image.fromarray(a, "RGBA").save(os.path.join(TEX, name + ".png"))
    else:
        Image.fromarray(a, "RGB").save(os.path.join(TEX, name + ".png"))
    print("wrote", name, a.shape)


def tile_mean(name):
    return np.asarray(Image.open(os.path.join(V2T, f"T_{name}.png")).convert("RGB"), np.float32).reshape(-1, 3).mean(0)


# ------------------------------------------------------------------------------------------------------- ground
def ground():
    N = 1024
    v = 1.0 - (np.arange(N)[:, None] + 0.5) / N          # 0 = inner edge (bottom row), 1 = outer edge (top row)
    v = np.repeat(v, N, axis=1)
    near = tile_mean("Desert")                          # the v2 ground tile, so the join at r 850-1,270 matches
    mid = np.array([200, 178, 136], np.float32)
    base = near + (mid - near) * smooth(0.0, 0.45, v)[..., None]
    patches = pnoise(N, N, 2.3, seed=11)
    dunes = pnoise(N, N, 1.8, ax=7.0, ay=1.0, seed=12)       # long low dunes, stretched along the ring
    grain = pnoise(N, N, 0.6, seed=13)
    col = base + patches[..., None] * np.array([7, 6, 4]) + dunes[..., None] * np.array([6, 5, 4]) + grain[..., None] * 2.0
    col += (np.clip(patches, 0.8, 3) - 0.8)[..., None] * np.array([-10, -12, -6])     # a few grey-olive scrub flats
    # dirt tracks: one radial track per repeat (meandering, lighter, fading out by v 0.5) + a ring road at v ~0.09
    img = Image.new("L", (N, N), 0)
    d = ImageDraw.Draw(img)
    rows = np.arange(N)
    for k, (x0, A, ph, w) in enumerate(((300, 40, 0.0, 4), (760, 25, 2.0, 3))):
        xs = x0 + A * np.sin(2 * math.pi * rows / N * 2 + ph) + 14 * np.sin(2 * math.pi * rows / N * 7 + ph * 3)
        pts = [(float(xs[r] % N), float(r)) for r in rows]
        for i in range(len(pts) - 1):
            if abs(pts[i][0] - pts[i + 1][0]) < N / 2:
                d.line([pts[i], pts[i + 1]], fill=255, width=w)
    ring_r = N - int(0.09 * N)
    ys = ring_r + 6 * np.sin(2 * math.pi * np.arange(N) / N * 1 + 0.7)
    for x in range(N - 1):
        d.line([(x, ys[x]), (x + 1, ys[x + 1])], fill=255, width=5)
    tr = np.asarray(img.filter(ImageFilter.GaussianBlur(1.2)), np.float32) / 255.0
    tr *= 1.0 - smooth(0.25, 0.6, v)
    col = col + (np.array([210, 190, 152]) - col) * (tr * 0.6)[..., None]
    # scrub dots (dry creosote / saltbush): dense near the inner edge, gone by v 0.45
    rng = np.random.default_rng(14)
    dots = Image.new("L", (N, N), 0)
    dd = ImageDraw.Draw(dots)
    for _ in range(9000):
        x, y = rng.uniform(0, N), rng.uniform(0, N)
        vv = 1 - y / N
        if rng.random() > (1 - smooth(0.0, 0.45, vv)) ** 1.5:
            continue
        r = rng.uniform(0.8, 2.2) * (1.2 - vv)
        for ox in (-N, 0, N):
            dd.ellipse([x + ox - r, y - r * 0.8, x + ox + r, y + r * 0.8], fill=int(rng.uniform(150, 255)))
    dm = np.asarray(dots.filter(ImageFilter.GaussianBlur(0.6)), np.float32) / 255.0
    col = col + (np.array([112, 104, 70]) - col) * (dm * 0.75)[..., None]
    # atmospheric fade to the haze colour toward the outer edge (pure haze for the last 6 %)
    t = smooth(0.18, 0.94, v) ** 1.1
    col = col + (HAZE - col) * t[..., None]
    save("X_Ground", col)
    REG["X_Ground"] = dict(size=[N, N], u_repeats=12, v_map="v = sqrt((r - 850) / 3150)")


# ------------------------------------------------------------------------------------------------------- mesas
TIERS = {1: dict(col=(176, 132, 96), con=1.0, rows=(684, 1020)),
         2: dict(col=(196, 170, 140), con=0.6, rows=(344, 680)),
         3: dict(col=(210, 194, 168), con=0.32, rows=(4, 340))}


def mesas():
    N = 1024
    out = np.zeros((N, N, 3), np.float32)
    for tier, T in TIERS.items():
        r0, r1 = T["rows"]
        h = r1 - r0
        y = 1.0 - (np.arange(h)[:, None] + 0.5) / h      # 0 = band bottom (sunk base), 1 = band top (tier max height)
        y = np.repeat(y, N, axis=1)
        base = np.array(T["col"], np.float32)
        warp = pnoise(h, N, 2.2, ax=1.0, ay=3.0, seed=20 + tier) * 0.012
        layers = np.sin(2 * math.pi * (y * 9.0 + warp * 9)) * 0.6 + np.sin(2 * math.pi * (y * 23.0 + warp * 14) + 1.3) * 0.4
        cap = smooth(0.08, 0.0, np.abs(y - 0.78)) - smooth(0.05, 0.0, np.abs(y - 0.5)) * 0.6    # a dark caprock + a pale bed
        streak = pnoise(h, N, 1.6, ax=1.0, ay=9.0, seed=30 + tier)          # vertical desert-varnish streaks
        talus = smooth(0.32, 0.12, y)                                       # dusty scree at the foot
        grain = pnoise(h, N, 0.7, seed=40 + tier)
        k = T["con"]
        col = base + layers[..., None] * np.array([13, 10, 8]) * k + cap[..., None] * np.array([-16, -14, -10]) * k
        col += np.clip(streak, 0, 3)[..., None] * np.array([-11, -10, -8]) * k * smooth(0.25, 0.9, y)[..., None]
        col += talus[..., None] * (np.array([206, 182, 148]) * 0.5 + base * 0.5 - col) * 0.55
        col += grain[..., None] * 3.0 * k
        col += pnoise(h, N, 2.4, seed=50 + tier)[..., None] * np.array([6, 5, 4]) * k
        col += pnoise(h, N, 2.8, ax=1.0, ay=0.5, seed=55 + tier)[..., None] * np.array([9, 6, 3]) * k   # broad rust / pale patches
        out[r0:r1] = col
        # fill the gutters with the nearest band row (no bleed of another tier)
    out[:4] = out[4]; out[340:344] = out[339]; out[680:684] = out[684]; out[1020:] = out[1019]
    save("X_Mesa", out)
    REG["X_Mesa"] = {f"tier{t}": dict(rows=list(T["rows"])) for t, T in TIERS.items()}


# ------------------------------------------------------------------------------------------------------- stencil font
GLYPH = {   # our own stencil letters on a 5 x 7 grid: rectangles (x0, y0, x1, y1) in cells; gaps are the stencil bridges
    "T": [(0, 0, 2.3, 1), (2.7, 0, 5, 1), (1.9, 1.4, 3.1, 7)],
    "-": [(0.6, 3.2, 4.4, 4.2)],
    "7": [(0, 0, 3.4, 1), (3.8, 0, 5, 1.6), (3.3, 2.0, 4.5, 3.2), (2.4, 3.6, 3.6, 7)],
    "B": [(0, 0, 1.1, 7), (1.5, 0, 4, 1), (3.9, 1.0, 5, 3.0), (1.5, 3.0, 4, 4.0), (3.9, 4.0, 5, 6.0), (1.5, 6, 4, 7)],
    "4": [(0, 0, 1.1, 3.6), (0, 3.6, 2.7, 4.6), (3.1, 3.6, 5, 4.6), (3.4, 0, 4.5, 3.2), (3.4, 5.0, 4.5, 7)],
    "M": [(0, 0, 1, 7), (4, 0, 5, 7), (1.2, 0.6, 2.2, 3.4), (2.8, 0.6, 3.8, 3.4)],
    "E": [(0, 0, 1.1, 7), (1.5, 0, 5, 1), (1.5, 3, 4, 4), (1.5, 6, 5, 7)],
    "S": [(0, 0, 5, 1), (0, 1.4, 1.1, 3), (0, 3, 5, 4), (3.9, 4.4, 5, 6), (0, 6, 5, 7)],
    "A": [(0, 1, 1.1, 7), (3.9, 1, 5, 7), (0.6, 0, 4.4, 1), (1.5, 3.4, 3.5, 4.4)],
    "D": [(0, 0, 1.1, 7), (1.5, 0, 4, 1), (3.9, 1, 5, 6), (1.5, 6, 4, 7)],
    "I": [(1.9, 0, 3.1, 3.2), (1.9, 3.8, 3.1, 7)],
    "R": [(0, 0, 1.1, 7), (1.5, 0, 4, 1), (3.9, 1, 5, 3), (1.5, 3, 4, 4), (3.4, 4.4, 4.6, 7)],
    "Y": [(0, 0, 1.1, 3), (3.9, 0, 5, 3), (0.6, 3, 4.4, 4), (1.9, 4.4, 3.1, 7)],
    " ": [],
}


def stencil(draw, text, x, y, cell, fill):
    for ch in text:
        for (a, b, c, e) in GLYPH[ch]:
            draw.rectangle([x + a * cell, y + b * cell, x + c * cell, y + e * cell], fill=fill)
        x += 6.2 * cell


def stencil_width(text, cell):
    return len(text) * 6.2 * cell - 1.2 * cell


# ------------------------------------------------------------------------------------------------------- town atlas
TOWN_BANDS = [("Butter", "SidingButter", (112, 92, 72), (100, 66, 36)), ("Salmon", "SidingSalmon", (104, 100, 94), (226, 220, 200)),
              ("Mint", "SidingMint", (86, 94, 86), (198, 160, 58)), ("White", "SidingWhite", (94, 84, 74), (52, 78, 58))]
TOWN_RECTS = {"siding": (0, 0, 640, 200), "stone": (640, 0, 1024, 40), "roof": (640, 44, 1024, 200),
              "trim": (0, 204, 128, 252), "glass": (132, 204, 260, 252), "door": (264, 204, 328, 252),
              "concrete": (332, 204, 460, 252), "dark": (464, 204, 528, 252)}


def fieldstone(w, h, ppst, seed):
    """stacked rough stones 1-2 studs, deep mortar"""
    from scipy.spatial import cKDTree
    rng = np.random.default_rng(seed)
    n = int(w * h / (ppst * ppst * 1.6)) + 8
    pts = np.c_[rng.uniform(0, w, n), rng.uniform(0, h, n)]
    pts_w = np.r_[pts, pts + [w, 0], pts - [w, 0]]
    tree = cKDTree(pts_w * [1.0, 1.4])
    yy, xx = np.mgrid[0:h, 0:w]
    dist, idx = tree.query(np.c_[xx.ravel(), yy.ravel()] * [1.0, 1.4], k=2)
    edge = (dist[:, 1] - dist[:, 0]).reshape(h, w)
    sid = (idx[:, 0] % n).reshape(h, w)
    pal = np.array([(118, 108, 92), (86, 78, 66), (142, 132, 112), (104, 96, 80), (128, 116, 96)], np.float32)
    col = pal[rng.integers(0, len(pal), n)][sid]
    shade = 1.0 - 0.25 * np.clip(1 - edge / (ppst * 0.5), 0, 1)
    col = col * shade[..., None]
    mortar = edge < max(1.2, ppst * 0.12)
    col[mortar] = (70, 64, 54)
    return col


def town():
    N = 1024
    out = np.zeros((N, N, 3), np.float32)
    for b, (nm, tile, roofc, doorc) in enumerate(TOWN_BANDS):
        y0 = b * 256
        band = np.zeros((256, N, 3), np.float32)
        sid = tile_mean(tile) * 1.04
        # siding (8 px / stud): lap boards every 0.75 stud, mottling, grime band at the foot, dust under the eaves
        x0, ya, x1, yb = TOWN_RECTS["siding"]
        h, w = yb - ya, x1 - x0
        z = (h - np.arange(h)[:, None] - 0.5) / 8.0          # studs above the region bottom (z 0 = ground)
        lap = ((z * 8) % 6.0)
        s = sid + pnoise(h, w, 2.0, seed=60 + b)[..., None] * 4 + pnoise(h, w, 1.4, ax=1, ay=6, seed=70 + b)[..., None] * 3
        s = s * np.where(lap < 1.0, 0.78, 1.0 - 0.05 * (lap / 6.0))[..., None]
        s += (np.array([170, 150, 115]) - s) * (0.35 * smooth(4.5, 2.0, z))[..., None]
        band[ya:yb, x0:x1] = s
        x0, ya, x1, yb = TOWN_RECTS["stone"]
        band[ya:yb, x0:x1] = fieldstone(x1 - x0, yb - ya, 8, 80 + b)
        # shingles: courses every stud, staggered tabs, per-tab tone, dust
        x0, ya, x1, yb = TOWN_RECTS["roof"]
        h, w = yb - ya, x1 - x0
        rng = np.random.default_rng(90 + b)
        yy, xx = np.mgrid[0:h, 0:w]
        course = yy // 8
        tab = (xx + (course % 2) * 6) // 12
        tone = rng.uniform(-10, 10, (course.max() + 2, tab.max() + 2))[course, tab]
        r = np.array(roofc, np.float32) + tone[..., None] + pnoise(h, w, 2.0, seed=95 + b)[..., None] * 5
        r *= np.where((yy % 8) < 1, 0.7, 1.0)[..., None]
        r *= np.where(((xx + (course % 2) * 6) % 12) < 1, 0.85, 1.0)[..., None]
        r += (np.array([190, 170, 130]) - r) * 0.12
        band[ya:yb, x0:x1] = r
        x0, ya, x1, yb = TOWN_RECTS["trim"]
        band[ya:yb, x0:x1] = np.array([224, 218, 198]) + pnoise(yb - ya, x1 - x0, 1.5, seed=99)[..., None] * 4
        # glass: dark with a soft sheen, white 2-over-2 muntins and a frame edge (each window quad maps to the full rect)
        x0, ya, x1, yb = TOWN_RECTS["glass"]
        h, w = yb - ya, x1 - x0
        yy, xx = np.mgrid[0:h, 0:w]
        g = np.array([40, 46, 50], np.float32) + (((xx + yy) / (w + h)) * 22)[..., None]
        fr = (xx < 4) | (xx >= w - 4) | (yy < 4) | (yy >= h - 4) | (np.abs(xx - w / 2) < 1.5) | (np.abs(yy - h / 2) < 2)
        g[fr] = (222, 216, 196)
        band[ya:yb, x0:x1] = g
        x0, ya, x1, yb = TOWN_RECTS["door"]
        h, w = yb - ya, x1 - x0
        yy, xx = np.mgrid[0:h, 0:w]
        dcol = np.array(doorc, np.float32) * (1 - 0.18 * (((xx % 32) < 2) | ((yy % 24) < 2)))[..., None]
        dcol[(xx < 3) | (xx >= w - 3) | (yy < 2)] = (222, 216, 196)
        band[ya:yb, x0:x1] = dcol
        x0, ya, x1, yb = TOWN_RECTS["concrete"]
        band[ya:yb, x0:x1] = np.array([156, 150, 138]) + pnoise(yb - ya, x1 - x0, 1.8, seed=101)[..., None] * 6
        x0, ya, x1, yb = TOWN_RECTS["dark"]
        band[ya:yb, x0:x1] = (34, 32, 30)
        out[y0:y0 + 256] = band
    out = fill_unused(out, list(TOWN_RECTS.values()), offset_rows=(0, 256, 512, 768))
    save("X_Town", out)
    REG["X_Town"] = dict(band_h=256, bands=[t[0] for t in TOWN_BANDS], rects=TOWN_RECTS, siding_px_per_stud=8,
                         stone_px_per_stud=8, roof_px_per_stud=8)


# ------------------------------------------------------------------------------------------------------- site atlas
SITE_RECTS = {"steel": (0, 0, 256, 256), "tank": (256, 0, 1024, 256), "roofcone": (0, 256, 256, 384),
              "concrete": (256, 256, 640, 512), "door": (640, 256, 768, 384), "dark": (768, 256, 832, 320),
              "burlap": (832, 256, 1024, 384), "corrugated": (0, 512, 512, 768), "endwall": (512, 512, 768, 768),
              "hangardoor": (768, 384, 1024, 512), "timber": (768, 512, 1024, 768), "polewood": (0, 768, 128, 1024),
              "wire": (128, 768, 192, 832), "insul": (192, 768, 256, 832), "darksteel": (256, 768, 384, 896),
              "olive": (384, 768, 512, 896), "sandbag": (512, 768, 1024, 1024)}


def site():
    N = 1024
    out = np.zeros((N, N, 3), np.float32)
    def R(k):
        x0, y0, x1, y1 = SITE_RECTS[k]
        return slice(y0, y1), slice(x0, x1), y1 - y0, x1 - x0
    def rust_streaks(h, w, seed, k=1.0):
        st = np.clip(pnoise(h, w, 1.5, ax=1, ay=10, seed=seed), 0.6, 4) - 0.6
        return st[..., None] * np.array([-14, -24, -30]) * k
    sy, sx, h, w = R("steel")
    out[sy, sx] = np.array([172, 170, 160]) + pnoise(h, w, 1.8, seed=200)[..., None] * 5 + rust_streaks(h, w, 201)
    # water tank wrap: cream paint, 3 courses of plates, rivet lines, rust tears below each seam, our stencil twice
    sy, sx, h, w = R("tank")
    yy, xx = np.mgrid[0:h, 0:w]
    t = np.array([206, 200, 184], np.float32) + pnoise(h, w, 2.0, seed=210)[..., None] * 4
    seam = (yy % (h // 3)) < 2
    t[seam] *= 0.8
    t += rust_streaks(h, w, 211, 0.8)
    t[(xx % (w // 16)) < 1] *= 0.92
    tank = Image.fromarray(np.clip(t, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(tank)
    for cx in (w * 0.25, w * 0.75):
        cell = 13
        tw = stencil_width("T-7", cell)
        stencil(d, "T-7", cx - tw / 2, h * 0.5 - 3.5 * cell, cell, (58, 62, 44))
    out[sy, sx] = np.asarray(tank, np.float32) + rust_streaks(h, w, 212, 0.35)
    sy, sx, h, w = R("roofcone")
    out[sy, sx] = np.array([150, 148, 140]) + pnoise(h, w, 1.8, seed=220)[..., None] * 6
    # bunker concrete (12 px / stud): board-formed courses every 2 studs, water stains from the top, grime at the foot
    sy, sx, h, w = R("concrete")
    yy, xx = np.mgrid[0:h, 0:w]
    c = np.array([150, 146, 134], np.float32) + pnoise(h, w, 2.0, seed=230)[..., None] * 7 + pnoise(h, w, 0.8, seed=231)[..., None] * 3
    c[(yy % 24) < 1] *= 0.85
    c += np.clip(pnoise(h, w, 1.5, ax=1, ay=8, seed=232), 0.4, 4)[..., None] * np.array([-10, -10, -9])
    c += (np.array([168, 148, 112]) - c) * (0.35 * smooth(h - 40, h, yy))[..., None]
    out[sy, sx] = c
    # blast door: olive steel, rivets, hinge straps, rust at the bottom
    sy, sx, h, w = R("door")
    yy, xx = np.mgrid[0:h, 0:w]
    dcol = np.array([96, 108, 62], np.float32) + pnoise(h, w, 1.8, seed=240)[..., None] * 5 + rust_streaks(h, w, 241, 0.6)
    dcol[((xx % 32) < 3) & ((yy % 12) < 3)] *= 0.7
    dcol[(yy % 40 < 6) & (xx < 40)] = (60, 62, 52)
    dcol[(xx < 4) | (xx >= w - 4) | (yy < 4) | (yy >= h - 4)] = (70, 74, 56)
    out[sy, sx] = dcol
    sy, sx, h, w = R("dark")
    out[sy, sx] = (26, 26, 24)
    # burlap sandbags: rows of rounded bags (bag = 1.6 x 0.6 studs, 32 px / stud in V)
    sy, sx, h, w = R("burlap")
    yy, xx = np.mgrid[0:h, 0:w]
    row = yy // 21
    bx = ((xx + (row % 2) * 24) % 48) / 48.0
    by = (yy % 21) / 21.0
    bulge = np.sin(np.pi * bx) ** 0.5 * np.sin(np.pi * by) ** 0.6
    b = np.array([176, 152, 108], np.float32) * (0.62 + 0.38 * bulge)[..., None]
    b += pnoise(h, w, 0.5, seed=250)[..., None] * 6 + pnoise(h, w, 2.0, seed=251)[..., None] * 6
    out[sy, sx] = b
    # corrugated iron: ribs along U, sheet laps every 64 px, galvanised with rust patches
    sy, sx, h, w = R("corrugated")
    yy, xx = np.mgrid[0:h, 0:w]
    rib = 0.82 + 0.18 * np.cos(2 * math.pi * xx / 6.0)
    g = np.array([164, 162, 154], np.float32) * rib[..., None]
    g[(yy % 64) < 2] *= 0.75
    rp = np.clip(pnoise(h, w, 2.2, seed=260), 1.0, 4) - 1.0
    g += rp[..., None] * np.array([-10, -34, -50])
    g += (np.array([180, 160, 124]) - g) * 0.12
    out[sy, sx] = g
    # quonset end wall: olive drab boards (horizontal), our own stencil 'B-4' up high, dust at the foot
    sy, sx, h, w = R("endwall")
    yy, xx = np.mgrid[0:h, 0:w]
    e = np.array([110, 120, 70], np.float32) + pnoise(h, w, 1.8, seed=270)[..., None] * 5
    e[(yy % 10) < 1] *= 0.85
    e += (np.array([170, 150, 115]) - e) * (0.4 * smooth(h - 30, h, yy))[..., None]
    im = Image.fromarray(np.clip(e, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(im)
    cell = 5
    tw = stencil_width("B-4", cell)
    stencil(d, "B-4", w / 2 - tw / 2, h * (1 - 17.5 / 40.0) - 3.5 * cell, cell, (226, 220, 196))
    out[sy, sx] = np.asarray(im, np.float32)
    # hangar doors: two sliding leaves, vertical panels, a dark gap in the middle
    sy, sx, h, w = R("hangardoor")
    yy, xx = np.mgrid[0:h, 0:w]
    hd = np.array([102, 112, 66], np.float32) + pnoise(h, w, 1.8, seed=280)[..., None] * 5 + rust_streaks(h, w, 281, 0.5)
    hd[(xx % 32) < 2] *= 0.8
    hd[np.abs(xx - w / 2) < 2] = (30, 30, 28)
    hd[(yy % 64) < 2] *= 0.85
    out[sy, sx] = hd
    # timber: weathered grey planks
    sy, sx, h, w = R("timber")
    yy, xx = np.mgrid[0:h, 0:w]
    pl = yy // 16
    rng = np.random.default_rng(290)
    tone = rng.uniform(-12, 12, pl.max() + 1)[pl]
    tm = np.array([140, 128, 108], np.float32) + tone[..., None] + pnoise(h, w, 1.2, ax=8, ay=1, seed=291)[..., None] * 6
    tm[(yy % 16) < 1] *= 0.6
    out[sy, sx] = tm
    sy, sx, h, w = R("polewood")
    out[sy, sx] = np.array([100, 82, 62]) + pnoise(h, w, 1.2, ax=1, ay=8, seed=300)[..., None] * 6
    sy, sx, h, w = R("wire"); out[sy, sx] = (24, 24, 22)
    sy, sx, h, w = R("insul"); out[sy, sx] = (150, 176, 160)
    sy, sx, h, w = R("darksteel")
    out[sy, sx] = np.array([82, 82, 78]) + pnoise(h, w, 1.8, seed=310)[..., None] * 4 + rust_streaks(h, w, 311, 0.4)
    sy, sx, h, w = R("olive")
    out[sy, sx] = np.array([107, 122, 58]) + pnoise(h, w, 1.8, seed=320)[..., None] * 4
    # sandbag wall wrap: 512 px = 8.6 studs along (bag 1.6 studs = 95 px), 256 px = the hump profile (row 0.55 = 26 px)
    sy, sx, h, w = R("sandbag")
    yy, xx = np.mgrid[0:h, 0:w]
    row = yy // 26
    bx = ((xx + (row % 2) * 48) % 95) / 95.0
    by = (yy % 26) / 26.0
    bulge = np.sin(np.pi * bx) ** 0.45 * np.sin(np.pi * by) ** 0.6
    sb = np.array([172, 148, 104], np.float32) * (0.6 + 0.4 * bulge)[..., None]
    sb += pnoise(h, w, 0.5, seed=330)[..., None] * 6 + pnoise(h, w, 2.0, seed=331)[..., None] * 7
    sb += (np.array([196, 172, 128]) - sb) * (0.3 * smooth(h - 50, h, yy))[..., None]
    out[sy, sx] = sb
    out = fill_unused(out, list(SITE_RECTS.values()))
    save("X_Site", out)
    REG["X_Site"] = dict(rects=SITE_RECTS)


# ------------------------------------------------------------------------------------------------------- chain link
def chainlink():
    N = 512
    yy, xx = np.mgrid[0:N, 0:N].astype(np.float32)
    col = np.zeros((N, N, 3), np.float32) + np.array([170, 172, 166])
    a = np.zeros((N, N), np.float32)
    cell = 32.0
    d1 = np.abs(((xx + yy) % cell) - cell / 2) - (cell / 2 - 1.3)
    d2 = np.abs(((xx - yy) % cell) - cell / 2) - (cell / 2 - 1.3)
    wire = np.clip(np.maximum(d1, d2) + 0.5, 0, 1)
    fab = yy < 448
    a[fab] = wire[fab] * 255
    col[fab] += pnoise(N, N, 1.6, seed=400)[fab][..., None] * 6
    # top selvage twist and bottom tension wire lines
    for r in (2, 3, 444, 445):
        a[r] = 255
    post = ~fab
    col[post] = (150, 150, 144)
    col[post] += np.clip(pnoise(N, N, 2.0, seed=401)[post], 0.8, 4)[..., None] * np.array([-8, -20, -30])
    a[post] = 255
    save("X_ChainLink", col, a)
    REG["X_ChainLink"] = dict(size=[N, N], fabric_rows=[0, 448], post_rows=[448, 512], u_tile_studs=4.0)


# ------------------------------------------------------------------------------------------------------- near atlas
NEAR_RECTS = {"drive": (0, 0, 568, 1004), "mat": (572, 0, 1024, 300), "crate": (572, 304, 1024, 604),
              "crate_top": (572, 608, 800, 836), "iron": (804, 608, 932, 736), "drive_edge": (572, 840, 1024, 900)}


def near():
    N = 1024
    out = np.zeros((N, N, 3), np.float32) + 128
    tile = Image.open(os.path.join(V2T, "T_Concrete65.png")).convert("RGB").resize((400, 400), Image.LANCZOS)
    tl = np.asarray(tile, np.float32)
    x0, y0, x1, y1 = NEAR_RECTS["drive"]
    h, w = y1 - y0, x1 - x0
    reps = np.tile(tl, (h // 400 + 1, w // 400 + 1, 1))[:h, :w]
    # flip alternate tiles so the 10-stud repeat doesn't read on a 14 x 25 slab
    c = reps.copy()
    c += pnoise(h, w, 2.2, seed=500)[..., None] * 5
    yy, xx = np.mgrid[0:h, 0:w]
    # expansion joints every ~6.3 studs across and one down the middle (40 px / stud)
    joint = np.zeros((h, w), bool)
    for jy in (250, 502, 754):
        joint |= np.abs(yy - jy) < 1.5
    joint |= np.abs(xx - w / 2) < 1.2
    c[joint] *= 0.62
    im = Image.fromarray(np.clip(c, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(im)
    rng = np.random.default_rng(501)
    # tyre marks: two worn darker lanes along the slab (wheel track 5 studs apart), stronger toward the street end
    lanes = Image.new("L", (w, h), 0)
    ld = ImageDraw.Draw(lanes)
    for lx in (w / 2 - 100, w / 2 + 100):
        for k in range(6):
            off = rng.uniform(-14, 14)
            ld.line([(lx + off, 0), (lx + off + rng.uniform(-10, 10), h)], fill=int(rng.uniform(30, 70)), width=int(rng.uniform(10, 22)))
    lm = np.asarray(lanes.filter(ImageFilter.GaussianBlur(6)), np.float32) / 255.0 * (0.4 + 0.6 * yy / h)
    # oil: a big stain under where the car's engine sits (y -43 -> row ~480) and drips
    oil = Image.new("L", (w, h), 0)
    od = ImageDraw.Draw(oil)
    for _ in range(26):
        cx, cy = w / 2 + rng.normal(0, 40), 470 + rng.normal(0, 50)
        r = rng.uniform(8, 46)
        od.ellipse([cx - r, cy - r * 0.8, cx + r, cy + r * 0.8], fill=int(rng.uniform(60, 160)))
    for _ in range(14):
        cx, cy = rng.uniform(80, w - 80), rng.uniform(80, h - 80)
        r = rng.uniform(3, 12)
        od.ellipse([cx - r, cy - r, cx + r, cy + r], fill=int(rng.uniform(60, 140)))
    om = np.asarray(oil.filter(ImageFilter.GaussianBlur(5)), np.float32) / 255.0
    # cracks: random walks from joints and edges
    for _ in range(18):
        x, y = rng.uniform(0, w), rng.uniform(0, h)
        ang = rng.uniform(0, 2 * math.pi)
        pts = [(x, y)]
        for _ in range(int(rng.uniform(12, 40))):
            ang += rng.normal(0, 0.45)
            x += math.cos(ang) * 7; y += math.sin(ang) * 7
            pts.append((x, y))
        d.line(pts, fill=(78, 74, 66), width=2)
    c = np.asarray(im, np.float32)
    c = c * (1 - 0.32 * lm)[..., None]
    c = c + (np.array([44, 40, 36]) - c) * (om * 0.75)[..., None]
    # windblown sand along the edges and the street end, weeds in the joints
    edge = np.minimum(np.minimum(xx, w - 1 - xx), h - 1 - yy).astype(np.float32)
    sand = smooth(60, 0, edge) * (0.5 + 0.5 * np.clip(pnoise(h, w, 1.8, seed=502), -1, 1))
    c = c + (np.array([196, 172, 128]) - c) * (sand * 0.55)[..., None]
    weeds = joint & (rng.random((h, w)) < 0.05)
    c[weeds] = (112, 112, 70)
    out[y0:y1, x0:x1] = c
    x0, y0, x1, y1 = NEAR_RECTS["drive_edge"]
    out[y0:y1, x0:x1] = np.asarray(Image.fromarray(np.clip(c[:60, :452], 0, 255).astype(np.uint8)), np.float32)[: y1 - y0, : x1 - x0] * 0.9
    # doormat: coir weave, a dark bound border, worn pale in the middle (no lettering)
    x0, y0, x1, y1 = NEAR_RECTS["mat"]
    h, w = y1 - y0, x1 - x0
    yy, xx = np.mgrid[0:h, 0:w]
    m = np.array([150, 112, 66], np.float32) * (0.82 + 0.18 * ((xx // 4 + yy // 4) % 2))[..., None]
    m += pnoise(h, w, 0.6, seed=510)[..., None] * 8
    wear = np.exp(-(((xx - w / 2) / (w * 0.3)) ** 2 + ((yy - h / 2) / (h * 0.3)) ** 2))
    m += (np.array([186, 160, 120]) - m) * (0.35 * wear)[..., None]
    m[(xx < 16) | (xx >= w - 16) | (yy < 16) | (yy >= h - 16)] = (58, 44, 30)
    out[y0:y1, x0:x1] = m
    # milk crate: weathered wooden slats, our own dairy stencil
    x0, y0, x1, y1 = NEAR_RECTS["crate"]
    h, w = y1 - y0, x1 - x0
    yy, xx = np.mgrid[0:h, 0:w]
    cr = np.array([150, 128, 96], np.float32) + pnoise(h, w, 1.2, ax=8, ay=1, seed=520)[..., None] * 8
    cr[(yy % 75) < 4] = (60, 50, 40)
    cr[(xx < 18) | (xx >= w - 18)] *= 0.85
    im = Image.fromarray(np.clip(cr, 0, 255).astype(np.uint8))
    d = ImageDraw.Draw(im)
    cell = 6.5
    for i, word in enumerate(("MESA", "DAIRY 7")):
        tw = stencil_width(word, cell)
        stencil(d, word, w / 2 - tw / 2, 88 + i * 66, cell, (86, 96, 54))
    out[y0:y1, x0:x1] = np.asarray(im, np.float32)
    # crate top: dark inside with a grid of six milk-bottle caps
    x0, y0, x1, y1 = NEAR_RECTS["crate_top"]
    h, w = y1 - y0, x1 - x0
    t = np.zeros((h, w, 3), np.float32) + (46, 40, 34)
    im = Image.fromarray(t.astype(np.uint8)); d = ImageDraw.Draw(im)
    for i in range(3):
        for j in range(2):
            cx, cy = w * (0.2 + 0.3 * i), h * (0.3 + 0.4 * j)
            d.ellipse([cx - 26, cy - 26, cx + 26, cy + 26], fill=(214, 210, 196))
            d.ellipse([cx - 16, cy - 16, cx + 16, cy + 16], fill=(200, 176, 96))
    t = np.asarray(im, np.float32)
    t[:10] = t[-10:] = (150, 128, 96); t[:, :10] = t[:, -10:] = (150, 128, 96)
    out[y0:y1, x0:x1] = t
    x0, y0, x1, y1 = NEAR_RECTS["iron"]
    h, w = y1 - y0, x1 - x0
    out[y0:y1, x0:x1] = np.array([36, 36, 34]) + np.clip(pnoise(h, w, 1.8, seed=530), 0.8, 4)[..., None] * np.array([18, 6, 0])
    out = fill_unused(out, list(NEAR_RECTS.values()))
    save("X_Near", out)
    REG["X_Near"] = dict(rects=NEAR_RECTS, drive_px_per_stud=40.0, drive_plan=dict(x0=15.9, x1=30.1, y_top=-31.0, y_bot=-56.1))


if __name__ == "__main__":
    ground(); mesas(); town(); site(); chainlink(); near()
    json.dump(REG, open(os.path.join(TEX, "regions.json"), "w"), indent=1)
    print("regions.json written")

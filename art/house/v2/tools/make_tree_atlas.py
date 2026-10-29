"""Paint the one 1024 atlas shared by every exterior tree (and the hedge): colour, normal (OpenGL, +Y up), roughness.
Plain Python (numpy + PIL), no Blender:  python art/house/tools/make_tree_atlas.py
Writes art/house/tex/H_Trees_color.png, H_Trees_normal.png, H_Trees_rough.png.

Layout in UV space (u right, v up; 4 x 4 cells of 256 px). CELLS below is also imported by build_trees.py.
  v row 3: broadA light | broadA mid | broadA dark | broadB light
  v row 2: broadB mid   | broadB dark | needle light | needle dark
  v rows 0-1 (256 x 512 columns): bark oak (grey-brown, fissured) | bark smooth (pale grey) | bark pine (red-brown plates) | hedge
No alpha anywhere: leaves are painted over a deep shadow green so a closed leaf clump reads as foliage, not as a cut-out card.
Every cell tiles left-right (bark wraps around a trunk) and the leaf cells tile both ways."""
import os, math
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
TEX = os.path.abspath(os.path.join(HERE, "..", "tex"))
RES = 1024
C = RES // 4

# name -> (u0, v0, u1, v1) in UV space
CELLS = {
    "broadA_light": (0.00, 0.75, 0.25, 1.00), "broadA_mid": (0.25, 0.75, 0.50, 1.00), "broadA_dark": (0.50, 0.75, 0.75, 1.00),
    "broadB_light": (0.75, 0.75, 1.00, 1.00), "broadB_mid": (0.00, 0.50, 0.25, 0.75), "broadB_dark": (0.25, 0.50, 0.50, 0.75),
    "needle_light": (0.50, 0.50, 0.75, 0.75), "needle_dark": (0.75, 0.50, 1.00, 0.75),
    "bark_oak": (0.00, 0.00, 0.25, 0.50), "bark_smooth": (0.25, 0.00, 0.50, 0.50), "bark_pine": (0.50, 0.00, 0.75, 0.50),
    "hedge": (0.75, 0.00, 1.00, 0.50),
}


def fnoise(h, w, rng, fy, fx, power=2.0, xcut=0):
    """periodic (tiling) fractal noise, anisotropic: fy/fx scale the frequency per axis. Returns ~[-1, 1]."""
    ky = np.fft.fftfreq(h)[:, None] * h / fy
    kx = np.fft.fftfreq(w)[None, :] * w / fx
    k = np.sqrt(kx * kx + ky * ky); k[0, 0] = 1.0
    spec = (rng.normal(size=(h, w)) + 1j * rng.normal(size=(h, w))) / k ** power
    spec[0, 0] = 0
    if xcut:   # high-pass across x: no broad dark bands, only fissure-sized features
        spec[:, np.abs(np.fft.fftfreq(w) * w) < xcut] = 0
    n = np.real(np.fft.ifft2(spec))
    return n / (np.abs(n).max() + 1e-9)


def paint_leaves(h, w, rng, n, length, width, pal, back, sprig=False):
    """stamp n pointed leaves with wrap-around. Later leaves sit on top and are lit more (depth). Returns col, height, rough."""
    col = np.empty((h, w, 3), np.float32)
    bn = fnoise(h, w, rng, 3, 3)
    col[:] = np.array(back, np.float32)[None, None, :] * (0.8 + 0.25 * bn[..., None])
    hgt = np.zeros((h, w), np.float32)
    rough = np.full((h, w), 0.95, np.float32)
    pal = np.array(pal, np.float32)
    L = int(length * 1.3) + 4
    yy, xx = np.mgrid[-L:L + 1, -L:L + 1].astype(np.float32)
    for k in range(n):
        depth = k / n
        cy, cx = rng.uniform(0, h), rng.uniform(0, w)
        ang = rng.uniform(0, 2 * math.pi)
        ln = length * rng.uniform(0.75, 1.25); wd = width * rng.uniform(0.8, 1.2)
        ca, sa = math.cos(ang), math.sin(ang)
        s = (xx * ca + yy * sa) / ln + 0.5         # 0..1 along the leaf (stem end at 0)
        t = (-xx * sa + yy * ca)
        prof = np.clip(np.sin(np.clip(s, 0, 1) * math.pi), 0, 1) ** 0.75 * wd * 0.5 * (1.0 - 0.25 * s)
        m = (s > 0) & (s < 1) & (np.abs(t) < prof)
        if not m.any():
            continue
        across = np.where(prof > 0, np.abs(t) / np.maximum(prof, 1e-3), 1)
        base = pal[rng.integers(len(pal))] * rng.uniform(0.85, 1.15)
        tilt = rng.uniform(0.6, 1.15)                       # leaf facing the light or not
        lit = (0.45 + 0.6 * depth) * tilt
        shade = lit * (1.0 - 0.18 * across ** 2) * (0.92 + 0.12 * s)    # darker edge, brighter tip
        c = base[None, :] * shade[m][:, None]
        rib = (np.abs(t[m]) < 0.7) & (s[m] > 0.08) & (s[m] < 0.92)
        c[rib] *= 0.78
        iy = (np.round(cy + yy[m]).astype(int)) % h
        ix = (np.round(cx + xx[m]).astype(int)) % w
        col[iy, ix] = c
        hgt[iy, ix] = depth * 1.4 + (1.0 - across[m] ** 2) * 0.5
        rough[iy, ix] = rng.uniform(0.72, 0.86)
    if sprig:   # thin twigs showing between leaves
        pass
    return col, hgt, rough


def paint_needles(h, w, rng, n, pal, back):
    """spruce twigs: a twig line with short needles both sides, stamped with wrap-around; upper twigs lit more."""
    col = np.empty((h, w, 3), np.float32)
    bn = fnoise(h, w, rng, 3, 3)
    col[:] = np.array(back, np.float32)[None, None, :] * (0.8 + 0.25 * bn[..., None])
    hgt = np.zeros((h, w), np.float32); rough = np.full((h, w), 0.95, np.float32)
    pal = np.array(pal, np.float32)
    for k in range(n):
        depth = k / n
        cy, cx = rng.uniform(0, h), rng.uniform(0, w)
        ang = rng.uniform(-math.pi, math.pi)
        tl = rng.uniform(26, 44)
        base = pal[rng.integers(len(pal))] * rng.uniform(0.85, 1.15) * (0.45 + 0.65 * depth)
        d = np.array([math.cos(ang), math.sin(ang)])
        nrm = np.array([-d[1], d[0]])
        for j in np.linspace(0, tl, int(tl / 2.2)):
            p = np.array([cx, cy]) + d * j
            for side in (-1, 1):
                nd = (nrm * side * 0.8 + d * 0.6); nd /= np.linalg.norm(nd)
                nl = rng.uniform(5, 8) * (1.0 - 0.35 * j / tl)
                for q in np.linspace(0, nl, int(nl * 1.5) + 2):
                    pt = p + nd * q
                    iy, ix = int(round(pt[1])) % h, int(round(pt[0])) % w
                    f = 0.8 + 0.35 * q / nl
                    col[iy, ix] = base * f; hgt[iy, ix] = depth * 1.4 + 0.3; rough[iy, ix] = 0.8
                    col[(iy + 1) % h, ix] = base * f * 0.85; hgt[(iy + 1) % h, ix] = depth * 1.4 + 0.15
            iy, ix = int(round(p[1])) % h, int(round(p[0])) % w
            col[iy, ix] = np.array([70, 52, 38], np.float32) * (0.5 + 0.5 * depth); hgt[iy, ix] = depth * 1.4 + 0.4
    return col, hgt, rough


def paint_bark(h, w, rng, kind):
    """bark, tiles left-right. oak: deep vertical fissures; smooth: pale with lenticels; pine: red-brown plates."""
    if kind == "oak":
        n1 = fnoise(h, w, rng, 3.0, 9.0, 1.9, xcut=5); n2 = fnoise(h, w, rng, 8, 20, 1.7, xcut=9)
        ridge = 1.0 - np.abs(n1 + 0.45 * n2) * 1.6
        hgt = np.clip(ridge, 0, 1) ** 1.3
        base = np.array([122, 110, 96], np.float32); deep = np.array([40, 34, 29], np.float32)
        tint = fnoise(h, w, rng, 2, 3)
        col = deep[None, None] + (base - deep)[None, None] * hgt[..., None]
        col *= (0.9 + 0.15 * tint[..., None])
        col[..., 1] += 6 * np.clip(fnoise(h, w, rng, 3, 3), 0, 1)       # a little moss green in the cracks
        rough = 0.95 - 0.1 * hgt
    elif kind == "smooth":
        n1 = fnoise(h, w, rng, 2, 2, 2.2); n2 = fnoise(h, w, rng, 20, 2, 1.5)
        hgt = 0.5 + 0.25 * n1 + 0.1 * n2
        col = np.array([150, 148, 138], np.float32)[None, None] * (0.85 + 0.2 * n1[..., None])
        col += np.array([-6, 3, -4], np.float32) * np.clip(fnoise(h, w, rng, 3, 3), 0, 1)[..., None]
        for _ in range(140):     # horizontal lenticels
            y, x = rng.integers(h), rng.integers(w); ln = rng.integers(4, 12)
            xs = (x + np.arange(ln)) % w
            col[y, xs] *= 0.55; hgt[y, xs] -= 0.25
        rough = np.full((h, w), 0.8, np.float32)
    else:   # pine plates
        n1 = fnoise(h, w, rng, 2.0, 6.0, 1.7)
        cells = np.zeros((h, w), np.float32)
        pts = np.stack([rng.uniform(0, h, 150), rng.uniform(0, w, 150)], 1)
        yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
        d1 = np.full((h, w), 1e9, np.float32); d2 = np.full((h, w), 1e9, np.float32)
        for py, px in pts:
            dy = np.abs(yy - py); dy = np.minimum(dy, h - dy) * 0.45
            dx = np.abs(xx - px); dx = np.minimum(dx, w - dx)
            d = np.sqrt(dx * dx + dy * dy)
            d2 = np.where(d < d1, d1, np.minimum(d2, d)); d1 = np.minimum(d1, d)
        crack = np.clip((d2 - d1) / 4.0, 0, 1) ** 0.7
        hgt = crack * (0.75 + 0.25 * n1)
        hi = np.array([124, 90, 70], np.float32); lo = np.array([44, 34, 30], np.float32)
        col = lo[None, None] + (hi - lo)[None, None] * hgt[..., None]
        col *= (0.88 + 0.18 * fnoise(h, w, rng, 3, 3)[..., None])
        rough = 0.9 - 0.08 * hgt
    return col, hgt.astype(np.float32), rough.astype(np.float32)


def normal_from_height(hgt, strength):
    """OpenGL tangent normal for an image whose row 0 is the TOP (v = 1). Wraps (tiling)."""
    dx = (np.roll(hgt, -1, 1) - np.roll(hgt, 1, 1)) * 0.5
    dy_img = (np.roll(hgt, -1, 0) - np.roll(hgt, 1, 0)) * 0.5
    dv = -dy_img                                   # v grows upward
    n = np.stack([-dx * strength, -dv * strength, np.ones_like(hgt)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n * 0.5 + 0.5


def blur(a, r=1):
    out = a.copy()
    for ax in (0, 1):
        acc = out.copy()
        for k in range(1, r + 1):
            acc += np.roll(out, k, ax) + np.roll(out, -k, ax)
        out = acc / (2 * r + 1)
    return out


def main():
    from PIL import Image   # lazy: build_trees.py imports CELLS inside Blender, which has no PIL
    rng = np.random.default_rng(20261028)
    col = np.zeros((RES, RES, 3), np.float32); nor = np.zeros((RES, RES, 3), np.float32); rou = np.zeros((RES, RES), np.float32)
    # leaf families: A = deep summer green (oak / maple), B = fresher yellow-green (linden / birch)
    famA = [(64, 92, 40), (72, 100, 44), (58, 84, 38), (80, 104, 50)]
    famB = [(88, 116, 46), (100, 124, 52), (80, 108, 42), (110, 128, 60)]
    needle = [(52, 82, 56), (60, 90, 62), (46, 74, 50)]
    jobs = {
        "broadA_light": ("leaf", famA, 1.25), "broadA_mid": ("leaf", famA, 1.0), "broadA_dark": ("leaf", famA, 0.72),
        "broadB_light": ("leaf", famB, 1.25), "broadB_mid": ("leaf", famB, 1.0), "broadB_dark": ("leaf", famB, 0.72),
        "needle_light": ("needle", needle, 1.45), "needle_dark": ("needle", needle, 0.9),
        "bark_oak": ("bark", "oak", 1), "bark_smooth": ("bark", "smooth", 1), "bark_pine": ("bark", "pine", 1),
        "hedge": ("hedge", famA, 1.0),
    }
    for name, (kind, arg, gain) in jobs.items():
        u0, v0, u1, v1 = CELLS[name]
        x0, x1 = int(u0 * RES), int(u1 * RES)
        y0, y1 = int((1 - v1) * RES), int((1 - v0) * RES)     # image rows (row 0 = v 1)
        h, w = y1 - y0, x1 - x0
        if kind == "leaf":
            c, hg, r = paint_leaves(h, w, rng, 1400, 24, 11, [tuple(np.array(p) * gain) for p in arg],
                                    tuple(np.array((22, 34, 18)) * min(gain, 1.0)))
            strength = 1.3
        elif kind == "needle":
            c, hg, r = paint_needles(h, w, rng, 300, [tuple(np.array(p) * gain) for p in arg], tuple(np.array((20, 34, 26)) * min(gain, 1.0)))
            strength = 1.3
        elif kind == "hedge":   # privet: small round-ish leaves, denser
            c, hg, r = paint_leaves(h, w, rng, 5200, 12, 7, [tuple(np.array(p) * 1.05) for p in arg], (20, 32, 18))
            strength = 1.3
        else:
            c, hg, r = paint_bark(h, w, rng, arg)
            strength = 6.0
        col[y0:y1, x0:x1] = c
        nor[y0:y1, x0:x1] = normal_from_height(blur(hg, 1), strength)
        rou[y0:y1, x0:x1] = r
    os.makedirs(TEX, exist_ok=True)
    Image.fromarray(np.clip(col, 0, 255).astype(np.uint8)).save(os.path.join(TEX, "H_Trees_color.png"))
    Image.fromarray(np.clip(nor * 255, 0, 255).astype(np.uint8)).save(os.path.join(TEX, "H_Trees_normal.png"))
    Image.fromarray(np.clip(rou * 255, 0, 255).astype(np.uint8)).save(os.path.join(TEX, "H_Trees_rough.png"))
    print("atlas written", TEX)


if __name__ == "__main__":
    main()

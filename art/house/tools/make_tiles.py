"""Seamless tiling textures for the house shell and the exterior (own work, procedural, numpy + PIL). Every texture tiles
exactly (periodic noise: FFT blur of wrapped white noise; patterns built on the tile period).
  python art/house/tools/make_tiles.py
Writes art/house/tex/tile/T_<name>.png and tiles.json (name -> studs per tile, for the UVs)."""
import json, os
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "tex", "tile")
os.makedirs(OUT, exist_ok=True)
R = np.random.default_rng(42)


def pnoise(n, scale, seed=None):
    """periodic smooth noise in 0..1 (scale = feature size in px)"""
    rng = np.random.default_rng(seed) if seed is not None else R
    w = rng.standard_normal((n, n))
    f = np.fft.fftfreq(n)
    k = np.sqrt(f[:, None] ** 2 + f[None, :] ** 2)
    g = np.exp(-(k * scale) ** 2 * 2)
    out = np.real(np.fft.ifft2(np.fft.fft2(w) * g))
    out -= out.min(); out /= max(out.max(), 1e-9)
    return out


def fbm(n, scales, weights, seed=0):
    acc = sum(w * pnoise(n, s, seed + i) for i, (s, w) in enumerate(zip(scales, weights)))
    acc -= acc.min(); return acc / acc.max()


def col(c):
    return np.array(c, np.float32)[None, None, :] / 255.0


def save(name, img, studs, tiles):
    im = np.clip(img * 255, 0, 255).astype(np.uint8)
    Image.fromarray(im).save(os.path.join(OUT, f"T_{name}.png"))
    tiles[name] = studs


def blend(base, other, m):
    return base * (1 - m[..., None]) + other * m[..., None]


def main():
    T = {}
    n = 512
    # interior paint: warm white, very subtle roller texture
    for name, c in (("PaintWhite", (234, 230, 220)), ("PaintGreige", (196, 190, 178)), ("PaintSlate", (104, 116, 128)),
                    ("CeilingWhite", (240, 238, 232))):
        nz = fbm(n, [2, 8, 40], [0.3, 0.4, 0.3], seed=len(name))
        img = col(c) * (0.965 + 0.06 * nz[..., None])
        save(name, img, 8.0, T)
    # oak floor: planks 0.75 stud wide (8 per 6-stud tile), staggered butt joints, grain along x
    n = 1024
    rows = 8
    ph = n // rows
    y = np.arange(n)[:, None]; x = np.arange(n)[None, :]
    grain = fbm(n, [1.5, 6], [0.6, 0.4], seed=3)
    streak = np.tile(pnoise(n, 3, seed=9).mean(axis=1, keepdims=True), (1, n))
    img = np.zeros((n, n, 3), np.float32)
    base = col((172, 134, 96))
    for r in range(rows):
        sl = slice(r * ph, (r + 1) * ph)
        off = int(R.integers(0, n))
        tone = R.uniform(0.86, 1.1)
        long_grain = pnoise(n, 2.5, seed=100 + r)[r * ph:(r + 1) * ph]
        long_grain = np.roll(np.repeat(long_grain.mean(axis=0, keepdims=True), ph, axis=0) * 0.0 + long_grain, 0, axis=1)
        g = 0.75 + 0.35 * long_grain + 0.12 * grain[sl]
        img[sl] = base * tone * g[..., None]
        joint = ((x + off) % (n // 2) < 3)
        img[sl] = np.where(joint[..., None].repeat(ph, axis=0), img[sl] * 0.55, img[sl])
        img[r * ph:r * ph + 2] *= 0.5
    img *= (0.95 + 0.1 * streak[..., None])
    save("OakFloor", img, 6.0, T)
    # large grey floor tile 2.5 studs (2 x 2 per 5-stud tile), thin grout
    n = 512
    nz = fbm(n, [3, 15, 60], [0.3, 0.3, 0.4], seed=11)
    img = col((150, 148, 142)) * (0.92 + 0.14 * nz[..., None])
    gm = ((x[:, :n] % (n // 2) < 3) | (y[:n] % (n // 2) < 3)).astype(np.float32)
    img = blend(img, col((96, 94, 90)), gm)
    save("FloorTile", img, 5.0, T)
    # white wall tile 1 x 0.5 (4 x 8 per 4-stud tile), offset rows
    nz = fbm(n, [2, 20], [0.4, 0.6], seed=12)
    img = col((226, 226, 222)) * (0.95 + 0.07 * nz[..., None])
    rowh = n // 8
    r = y[:n] // rowh
    xx = (x[:, :n] + (r % 2) * (n // 8)) % (n // 4)
    gm = ((xx < 3) | (y[:n] % rowh < 3)).astype(np.float32)
    img = blend(img, col((170, 170, 166)), gm)
    save("WallTile", img, 4.0, T)
    # exterior render: off-white, a little mottled
    nz = fbm(n, [1.5, 6, 40], [0.35, 0.35, 0.3], seed=13)
    img = col((226, 222, 212)) * (0.93 + 0.1 * nz[..., None])
    save("Render", img, 8.0, T)
    # charcoal timber cladding: vertical boards 0.75 wide (8 per 6-stud tile), shadow groove
    nz = fbm(n, [1.5, 8], [0.5, 0.5], seed=14)
    bw = n // 8
    bx = x[:, :n] % bw
    tone = np.repeat(R.uniform(0.9, 1.1, 8), bw)[None, :]
    img = col((58, 58, 56)) * tone[..., None] * (0.9 + 0.16 * nz[..., None])
    img = blend(img, col((22, 22, 22)), (bx < 5).astype(np.float32))
    save("Cladding", img, 6.0, T)
    # standing-seam metal roof: seams every 1.5 studs (4 per 6-stud tile)
    nz = fbm(n, [2, 30], [0.5, 0.5], seed=15)
    img = col((70, 72, 74)) * (0.94 + 0.1 * nz[..., None])
    sx = x[:, :n] % (n // 4)
    img = blend(img, col((110, 112, 114)), ((sx >= 0) & (sx < 4)).astype(np.float32))
    img = blend(img, col((40, 40, 42)), ((sx >= 4) & (sx < 8)).astype(np.float32))
    save("RoofMetal", img, 6.0, T)
    # flat roof membrane / gravel
    nz = fbm(n, [1, 3], [0.6, 0.4], seed=16)
    img = col((120, 120, 116)) * (0.8 + 0.35 * nz[..., None])
    save("Gravel", img, 6.0, T)
    # asphalt
    nz = fbm(n, [1, 4, 60], [0.5, 0.3, 0.2], seed=17)
    img = col((62, 63, 64)) * (0.82 + 0.3 * nz[..., None])
    save("Asphalt", img, 12.0, T)
    # concrete slabs with joints every 5 studs (2 x 2 per 10-stud tile)
    nz = fbm(n, [1.5, 10, 80], [0.3, 0.4, 0.3], seed=18)
    img = col((176, 174, 168)) * (0.9 + 0.14 * nz[..., None])
    gm = ((x[:, :n] % (n // 2) < 3) | (y[:n] % (n // 2) < 3)).astype(np.float32)
    img = blend(img, col((110, 108, 104)), gm)
    save("Concrete", img, 10.0, T)
    # lawn
    nz = fbm(n, [1, 3, 30, 120], [0.35, 0.25, 0.2, 0.2], seed=19)
    img = col((86, 116, 64)) * (0.78 + 0.4 * nz[..., None])
    save("Grass", img, 10.0, T)
    # hedge
    nz = fbm(n, [2, 6, 20], [0.4, 0.35, 0.25], seed=20)
    img = col((52, 80, 44)) * (0.6 + 0.6 * nz[..., None])
    save("Hedge", img, 6.0, T)
    # timber fence: horizontal boards 0.75 (8 per 6-stud tile), dark gaps
    nz = fbm(n, [1.5, 10], [0.5, 0.5], seed=21)
    bh = n // 8
    tone = np.repeat(R.uniform(0.88, 1.1, 8), bh)[:, None]
    img = col((128, 98, 70)) * tone[..., None] * (0.88 + 0.2 * nz[..., None])
    img = blend(img, col((40, 30, 22)), ((y[:n] % bh) < 4).astype(np.float32))
    save("Fence", img, 6.0, T)
    # neighbour brick (warm grey-brown), 1 x 0.33 bricks
    nz = fbm(n, [1.5, 10], [0.5, 0.5], seed=22)
    rowh = n // 18
    r = y[:n] // rowh
    xx = (x[:, :n] + (r % 2) * (n // 12)) % (n // 6)
    tone = R.uniform(0.85, 1.12, (18, 6))
    t = tone[np.clip(r, 0, 17), np.clip(((x[:, :n] + (r % 2) * (n // 12)) // (n // 6)) % 6, 0, 5)]
    img = col((150, 112, 92)) * t[..., None] * (0.9 + 0.15 * nz[..., None])
    gm = ((xx < 3) | (y[:n] % rowh < 3)).astype(np.float32)
    img = blend(img, col((196, 190, 180)), gm)
    save("Brick", img, 6.0, T)
    # siding for the house across: horizontal lap boards 0.6 (10 per 6-stud tile)
    nz = fbm(n, [1.5, 20], [0.5, 0.5], seed=23)
    bh = n // 10
    sh = (y[:n] % bh) / bh
    img = col((176, 186, 190)) * (0.82 + 0.18 * sh[..., None]) * (0.95 + 0.08 * nz[..., None])
    save("Siding", img, 6.0, T)
    json.dump(T, open(os.path.join(OUT, "tiles.json"), "w"), indent=1)
    print("tiles:", T)


main()

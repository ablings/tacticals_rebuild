"""House illusion pass: our own desert sky (procedural, no reference art).
Builds an equirectangular panorama (elevation gradient: haze-tan below and at the horizon, cream band, pale dusty blue zenith;
two faint periodic mountain ridges at the horizon in near-haze colours; a few soft high haze streaks) and cuts it into the six
Roblox Sky faces. The far ridges live in the sky so they always draw, also at graphics quality 1 (vault: Backdrops and World
Illusion, rule 15). Usage: python make_sky.py [outdir] [--test]  (--test paints face letters to check orientation).
Face convention (Roblox, measured in Studio 2026-10-29 with lettered test faces): Ft looks -Z, Bk +Z, Lf +X, Rt -X, side faces
upright. Up / Dn depend on elevation only (nothing azimuthal above 35 deg or below the horizon), so their turn can't show a seam."""
import math, os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

OUT = sys.argv[1] if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else os.path.dirname(os.path.abspath(__file__))
TEST = "--test" in sys.argv
N = 1024
rng = np.random.default_rng(1965)

HAZE = np.array([214, 196, 166.0])
HORIZON = np.array([222, 205, 166.0])  # r3: horizon join was 19 bluer than the far ground (grade r1)
MID = np.array([201, 194, 174.0])
ZENITH = np.array([156, 172, 188.0])
GROUND = np.array([200, 180, 146.0])
RIDGE_FAR = np.array([196, 180, 154.0])
RIDGE_NEAR = np.array([178, 156, 126.0])


def ridge(az, seed, octaves, amp, base):
    """periodic in azimuth (0..2pi): sum of sines with random phases, sharpened like eroded mesas. Normalised over the FULL
    circle (a per-face min/max made the ridge jump at the face seams, found on the round-2 preview)"""
    def raw(a):
        r = np.random.default_rng(seed)
        h = np.zeros_like(a)
        for o in range(octaves):
            f = 2 ** o * r.integers(2, 4)
            h += r.uniform(0.5, 1.0) / (o + 1) ** 1.2 * np.sin(f * a + r.uniform(0, 2 * math.pi))
        return h
    full = raw(np.linspace(0, 2 * math.pi, 20000, endpoint=False))
    lo, hi = full.min(), full.max()
    h = (raw(az) - lo) / (hi - lo)
    h = np.clip((h - 0.35) * 1.8, 0, 1) ** 0.6
    return base + amp * h


def sky_colour(d):
    """d: (...,3) unit directions, Y up. Returns (...,3) RGB float."""
    x, y, z = d[..., 0], d[..., 1], d[..., 2]
    el = np.degrees(np.arcsin(np.clip(y, -1, 1)))
    az = np.arctan2(x, -z) % (2 * math.pi)
    col = np.empty(d.shape, float)
    # above horizon: horizon -> mid by 12 deg -> zenith by 70 deg (smooth)
    t1 = np.clip(el / 12.0, 0, 1)[..., None]
    t2 = np.clip((el - 12.0) / 58.0, 0, 1)[..., None] ** 0.8
    up = HORIZON * (1 - t1) + MID * t1
    up = up * (1 - t2) + ZENITH * t2
    # below horizon: haze colour fading to desert ground
    tg = np.clip(-el / 10.0, 0, 1)[..., None]
    down = HAZE * (1 - tg) + GROUND * tg
    col[:] = np.where((el >= 0)[..., None], up, down)
    # soft high haze streaks between 16 and 34 deg (below the Up face's corners at 35.3 deg)
    s = np.sin(az * 3 + 0.7) * np.sin(az * 7 + 2.1) * np.sin(el * 0.21 + 1.3)
    streak = np.clip(s, 0, 1)[..., None] * np.clip((el - 16) / 8, 0, 1)[..., None] * np.clip((34 - el) / 8, 0, 1)[..., None]
    col = col * (1 - 0.10 * streak) + np.array([236, 228, 214.0]) * 0.10 * streak
    # far ridge (very faint) then a nearer ridge, both close to the haze colour; the ridge foot is hazed into the horizon
    for seed, oct_, amp, base, rc, a in ((7, 6, 7.0, 0.8, RIDGE_FAR, 0.75), (23, 7, 4.6, 0.2, RIDGE_NEAR, 0.88)):  # round 2: tall and solid enough to read at quality 1, where the 3D tiers are culled
        top = ridge(az, seed, oct_, amp, base)
        inside = (el <= top) & (el > -1.5)
        fade = np.clip((el + 1.5) / 1.5, 0, 1) * a  # haze at the foot, solid-ish higher up
        m = (inside * fade)[..., None]
        col = col * (1 - m) + rc * m
    return col


def face_dirs(face):
    u = (np.arange(N) + 0.5) / N * 2 - 1
    a, b = np.meshgrid(u, -u)  # a: right, b: up in the image
    one = np.ones_like(a)
    # (right, up, forward) per face, Y up world
    F = {
        "Ft": (np.array([1, 0, 0]), np.array([0, 1, 0]), np.array([0, 0, -1])),
        "Bk": (np.array([-1, 0, 0]), np.array([0, 1, 0]), np.array([0, 0, 1])),
        "Lf": (np.array([0, 0, 1]), np.array([0, 1, 0]), np.array([1, 0, 0])),  # measured in Studio: Lf is the +X face
        "Rt": (np.array([0, 0, -1]), np.array([0, 1, 0]), np.array([-1, 0, 0])),  # Rt is the -X face
        "Up": (np.array([1, 0, 0]), np.array([0, 0, 1]), np.array([0, 1, 0])),
        "Dn": (np.array([1, 0, 0]), np.array([0, 0, -1]), np.array([0, -1, 0])),
    }[face]
    r, up, f = F
    d = a[..., None] * r + b[..., None] * up + one[..., None] * f
    return d / np.linalg.norm(d, axis=-1, keepdims=True)


def main():
    os.makedirs(OUT, exist_ok=True)
    for face in ("Ft", "Bk", "Lf", "Rt", "Up", "Dn"):
        c = sky_colour(face_dirs(face))
        c += rng.normal(0, 0.8, c.shape)  # break banding
        im = Image.fromarray(np.clip(c, 0, 255).astype(np.uint8))
        if TEST:
            d = ImageDraw.Draw(im)
            try:
                font = ImageFont.truetype("arial.ttf", 300)
            except Exception:
                font = None
            d.text((N // 2 - 150, N // 2 - 170), face, fill=(200, 0, 0), font=font)
            d.text((20, 20), "TL", fill=(0, 0, 200), font=font and ImageFont.truetype("arial.ttf", 120))
        im.save(os.path.join(OUT, f"sky_{face}{'_test' if TEST else ''}.png"))
    print("faces written to", OUT)


if __name__ == "__main__":
    main()

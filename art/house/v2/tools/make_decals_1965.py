"""1965 House: wear decals (alpha atlas), our own signs, notices, calendar, posters and labels (all our own words).
  python art/house/v2/tools/make_decals_1965.py
Writes art/house/v2/tex/decals65/*.png. Stencil lettering = our own: glyphs cut with bridges (stencil_text)."""
import math, os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "tex", "decals65")
GEN = os.path.join(HERE, "..", "tex", "gen65")
os.makedirs(OUT, exist_ok=True)
FD = "C:/Windows/Fonts/"
F = lambda name, size: ImageFont.truetype(FD + name, size)
rng = np.random.default_rng(65)


def noise(w, h, scale, seed):
    r = np.random.default_rng(seed)
    a = r.random((max(2, h // scale), max(2, w // scale)))
    im = Image.fromarray((a * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
    return np.asarray(im).astype(np.float32) / 255


def stencil_text(d, xy, text, font, fill, bridge=None):
    """our stencil lettering: each glyph drawn, then cut by a bridge (vertical through closed glyphs, horizontal through
    the rest) so it reads as sprayed through a cut card"""
    x, y = xy
    bridge = bridge or max(2, font.size // 12)
    for ch in text:
        g = Image.new("L", (font.size * 2, font.size * 2), 0)
        gd = ImageDraw.Draw(g)
        gd.text((0, 0), ch, font=font, fill=255)
        bb = g.getbbox()
        w = font.getlength(ch)
        if bb:
            cx = (bb[0] + bb[2]) // 2; cy = (bb[1] + bb[3]) // 2
            if ch in "ABDOPQR0689@&":
                gd.rectangle((cx - bridge // 2, bb[1], cx + bridge // 2, bb[3]), fill=0)
            elif ch in "EFHKMNWXZ4":
                gd.rectangle((bb[0], cy - bridge // 2, bb[2], cy + bridge // 2), fill=0)
            im = Image.new("RGBA", g.size, fill)
            d._image.paste(im, (int(x), int(y)), g) if hasattr(d, "_image") else None
        x += w + font.size * 0.06
    return x


class Canvas:
    def __init__(s, w, h, bg=(0, 0, 0, 0)):
        s.im = Image.new("RGBA", (w, h), bg)
        s.d = ImageDraw.Draw(s.im)
        s.d._image = s.im

    def stencil(s, xy, text, font, fill, centre=False):
        if centre:
            w = sum(font.getlength(c) + font.size * 0.06 for c in text)
            xy = (xy[0] - w / 2, xy[1])
        stencil_text(s.d, xy, text, font, fill)

    def text(s, xy, t, font, fill, centre=False):
        if centre:
            w = s.d.textlength(t, font=font)
            xy = (xy[0] - w / 2, xy[1])
        s.d.text(xy, t, font=font, fill=fill)

    def save(s, name):
        s.im.save(os.path.join(OUT, name + ".png"))
        return s.im


def paper(w, h, base=(232, 222, 192), seed=0, age=0.25):
    a = np.zeros((h, w, 4), np.float32)
    n1 = noise(w, h, 3, seed); n2 = noise(w, h, 60, seed + 1)
    for i in range(3):
        a[..., i] = base[i] * (0.93 + 0.08 * n1) - age * 40 * n2 * (1 if i < 2 else 1.6)
    yy, xx = np.mgrid[0:h, 0:w]
    edge = np.minimum(np.minimum(xx, w - 1 - xx), np.minimum(yy, h - 1 - yy)) / max(w, h)
    a[..., :3] -= np.clip(0.04 - edge, 0, 1)[..., None] * 900 * age
    a[..., 3] = 255
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8), "RGBA")


def soft_blob(size, seed, rough=8, power=1.0):
    """irregular alpha blob in 0..1"""
    w = h = size
    yy, xx = np.mgrid[0:h, 0:w]
    r = np.sqrt((xx - w / 2) ** 2 + (yy - h / 2) ** 2) / (w / 2)
    n = noise(w, h, rough, seed)
    a = np.clip(1.0 - r - 0.45 * (n - 0.5), 0, 1)
    return a ** power


# =============================================================================================== wear atlas (4 x 4, 256 cells)
CELL = 256
WEAR = ["water_stain_a", "water_stain_b", "peel_corner", "peel_seam",
        "scorch_a", "scorch_b", "bullets_a", "bullets_b",
        "faded_rect", "chalk_marks_a", "chalk_marks_b", "floor_scuff",
        "sand_fan", "cobweb", "lino_crack", "dust_patch"]


def wear_atlas():
    at = Image.new("RGBA", (CELL * 4, CELL * 4), (0, 0, 0, 0))
    def put(i, im):
        at.paste(im, ((i % 4) * CELL, (i // 4) * CELL))
    S = CELL
    for k, seed in ((0, 1), (1, 2)):                 # water stains: brown tide rings, pale centre
        a = np.asarray(Image.fromarray((soft_blob(S, seed, rough=48) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(6))).astype(np.float32) / 255
        ring = np.clip(1 - np.abs(a - 0.12) / 0.06, 0, 1) * 0.85 + np.clip(1 - np.abs(a - 0.35) / 0.05, 0, 1) * 0.5
        body = np.clip(a * 1.6, 0, 1) * 0.35
        yy_, xx_ = np.mgrid[0:S, 0:S]
        al = np.clip(ring + body, 0, 1) * np.clip((1 - np.sqrt((xx_ - S / 2) ** 2 + (yy_ - S / 2) ** 2) / (S / 2)) * 5, 0, 1)
        c = np.zeros((S, S, 4), np.uint8)
        c[..., 0], c[..., 1], c[..., 2] = 124, 92, 52
        c[..., 3] = (al * 210).astype(np.uint8)
        put(k, Image.fromarray(c, "RGBA").filter(ImageFilter.GaussianBlur(2.0)))
    # peeled wallpaper: a curled-back flap (paper back side cream, its shadow), bare plaster underneath
    for k, seed in ((2, 3), (3, 4)):
        c = Canvas(S, S)
        if k == 2:      # corner flap
            plaster = [(40, 40), (220, 40), (220, 60), (120, 150), (60, 220), (40, 220)]
            c.d.polygon(plaster, fill=(196, 188, 170, 255))
            c.d.polygon([(220, 60), (120, 150), (150, 170), (236, 92)], fill=(70, 60, 44, 120))
            c.d.polygon([(220, 60), (120, 150), (130, 112), (200, 70)], fill=(232, 226, 204, 255))
            c.d.line([(220, 60), (120, 150)], fill=(150, 140, 116, 255), width=3)
        else:           # a lifted seam: a vertical tear strip
            c.d.polygon([(110, 10), (146, 10), (152, 246), (104, 246)], fill=(196, 188, 170, 255))
            c.d.polygon([(146, 10), (182, 40), (176, 200), (152, 246)], fill=(232, 226, 204, 255))
            c.d.polygon([(182, 40), (196, 52), (190, 210), (176, 200)], fill=(70, 60, 44, 110))
        im = c.im
        arr = np.asarray(im).astype(np.float32)
        n = noise(S, S, 4, seed)
        arr[..., :3] *= (0.92 + 0.12 * n)[..., None]
        put(k, Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA").filter(ImageFilter.GaussianBlur(0.6)))
    for k, seed in ((4, 5), (5, 6)):                 # scorch: soot fan rising (upward = image top)
        yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
        u = (xx - S / 2) / (S / 2); v = (S - yy) / S
        width = 0.25 + 0.7 * v
        a = np.clip(1 - np.abs(u) / width, 0, 1) * np.clip(1 - v * 0.9, 0, 1) * np.clip(v * 6, 0, 1)
        a = a * (0.55 + 0.6 * noise(S, S, 12, seed)) * (0.7 + 0.4 * noise(S, S, 3, seed + 9))
        core = np.clip(1 - np.sqrt(u ** 2 + ((v - 0.12) * 2.2) ** 2) / 0.35, 0, 1)
        c = np.zeros((S, S, 4), np.uint8)
        c[..., 0] = (22 + 30 * (1 - core)).astype(np.uint8); c[..., 1] = (18 + 22 * (1 - core)).astype(np.uint8); c[..., 2] = 14
        c[..., 3] = (np.clip(a * 1.2 + core * 0.6, 0, 1) * 235).astype(np.uint8)
        put(k, Image.fromarray(c, "RGBA").filter(ImageFilter.GaussianBlur(1.5)))
    for k, seed in ((6, 7), (7, 8)):                 # bullet holes: dark hole, broken plaster rim, radial cracks
        c = Canvas(S, S)
        r = np.random.default_rng(seed)
        for _ in range(4 if k == 6 else 6):
            x, y = r.uniform(40, 216), r.uniform(40, 216)
            rr = r.uniform(5, 8)
            c.d.ellipse((x - rr * 2.3, y - rr * 2.3, x + rr * 2.3, y + rr * 2.3), fill=(214, 206, 186, 230))
            for j in range(5):
                a = r.uniform(0, 2 * math.pi); L = r.uniform(12, 30)
                c.d.line([(x, y), (x + L * math.cos(a), y + L * math.sin(a))], fill=(60, 50, 40, 200), width=2)
            c.d.ellipse((x - rr * 1.3, y - rr * 1.3, x + rr * 1.3, y + rr * 1.3), fill=(110, 100, 86, 255))
            c.d.ellipse((x - rr, y - rr, x + rr, y + rr), fill=(16, 14, 12, 255))
        put(k, c.im.filter(ImageFilter.GaussianBlur(0.5)))
    # faded rectangle where a frame hung (paler, a clean edge, a nail hole)
    c = Canvas(S, S)
    c.d.rectangle((48, 30, 208, 226), fill=(250, 244, 226, 90))
    c.d.rectangle((48, 30, 208, 34), fill=(120, 104, 80, 70))
    c.d.ellipse((124, 14, 132, 22), fill=(30, 26, 22, 230))
    put(8, c.im.filter(ImageFilter.GaussianBlur(1.0)))
    # chalk test marks (our own wording): a height line with numbers, an arrow and a code
    hand = F("segoeprb.ttf", 30)
    for k, lines in ((9, ["T-7", "5 FT", "CAM 2"]), (10, ["ROOM 4", "ok 3/15", "<- 12 ft"])):
        c = Canvas(S, S)
        if k == 9:
            c.d.line([(30, 120), (226, 120)], fill=(236, 234, 226, 220), width=4)
            for i in range(5):
                c.d.line([(40 + i * 45, 110), (40 + i * 45, 130)], fill=(236, 234, 226, 220), width=3)
        else:
            c.d.line([(40, 200), (200, 200)], fill=(236, 234, 226, 220), width=4)
            c.d.polygon([(200, 186), (226, 200), (200, 214)], fill=(236, 234, 226, 220))
        for i, t in enumerate(lines):
            c.text((30, 20 + i * 44 if k == 9 else 20 + i * 50), t, hand, (238, 236, 228, 225))
        arr = np.asarray(c.im).astype(np.float32)
        arr[..., 3] *= (0.55 + 0.6 * noise(S, S, 2, k))
        put(k, Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA"))
    # floor scuffs: dark streaky arcs
    c = Canvas(S, S)
    r = np.random.default_rng(11)
    for _ in range(18):
        x, y = r.uniform(20, 236), r.uniform(20, 236); L = r.uniform(20, 70); a = r.uniform(-0.5, 0.5)
        c.d.line([(x, y), (x + L * math.cos(a), y + L * math.sin(a))], fill=(50, 40, 30, int(r.uniform(60, 140))), width=int(r.uniform(2, 6)))
    put(11, c.im.filter(ImageFilter.GaussianBlur(1.5)))
    # sand fan: from the bottom edge (door side) fanning in
    yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)
    rr_ = np.sqrt((xx - S / 2) ** 2 + (yy - S) ** 2) / S
    a = np.clip(1 - rr_ / (0.7 + 0.25 * noise(S, S, 20, 12)), 0, 1) ** 0.8
    rip = 0.85 + 0.15 * np.sin(rr_ * 90)
    c = np.zeros((S, S, 4), np.uint8)
    c[..., 0], c[..., 1], c[..., 2] = 206, 180, 136
    c[..., 3] = (np.clip(a * rip, 0, 1) * 235).astype(np.uint8)
    put(12, Image.fromarray(c, "RGBA"))
    # cobweb: radial threads + spiral, in a corner (top-left = the corner)
    c = Canvas(S, S)
    for j in range(9):
        a = j / 8 * math.pi / 2
        c.d.line([(0, 0), (240 * math.cos(a), 240 * math.sin(a))], fill=(232, 230, 222, 150), width=2)
    for ring in range(1, 9):
        pts = [(ring * 26 * math.cos(j / 8 * math.pi / 2) * (1 + 0.08 * math.sin(j * 3)), ring * 26 * math.sin(j / 8 * math.pi / 2)) for j in range(9)]
        c.d.line(pts, fill=(232, 230, 222, 120), width=1)
    put(13, c.im.filter(ImageFilter.GaussianBlur(0.4)))
    # cracked lino: dark crack lines + chipped corner
    c = Canvas(S, S)
    r = np.random.default_rng(14)
    for _ in range(3):
        x, y = r.uniform(20, 236), r.uniform(20, 236)
        pts = [(x, y)]
        for _ in range(8):
            x += r.uniform(-30, 30); y += r.uniform(-30, 30); pts.append((x, y))
        c.d.line(pts, fill=(30, 26, 20, 230), width=3)
    c.d.polygon([(0, 0), (60, 0), (30, 26), (0, 50)], fill=(120, 108, 90, 255))
    put(14, c.im)
    # dust patch: soft tan film
    a = soft_blob(S, 15, rough=20, power=0.7) * (0.6 + 0.4 * noise(S, S, 3, 16))
    c = np.zeros((S, S, 4), np.uint8)
    c[..., 0], c[..., 1], c[..., 2] = 170, 150, 115
    c[..., 3] = (np.clip(a, 0, 1) * 160).astype(np.uint8)
    put(15, Image.fromarray(c, "RGBA"))
    at.save(os.path.join(OUT, "wear_atlas.png"))


# =============================================================================================== paper things (our words)
def notice_board():
    """civil-defence-style household drill notice (our own wording), typewritten on a pinned sheet"""
    c = Canvas(768, 768, (0, 0, 0, 0))
    c.im.paste(paper(768, 768, (226, 214, 180), 1, 0.35), (0, 0))
    big = F("impact.ttf", 70); typ = F("courbd.ttf", 30); sm = F("cour.ttf", 26)
    c.d.rectangle((24, 24, 744, 150), fill=(107, 122, 58, 255))
    c.stencil((384, 42), "HOUSEHOLD DRILL", big, (236, 232, 218, 255), centre=True)
    rows = ["WHEN THE SIREN SOUNDS:", "", "1. STAY AWAY FROM WINDOWS", "2. GO TO THE LOWEST ROOM", "3. TURN OFF THE GAS AT THE TAP",
            "4. KEEP THE RADIO ON", "", "DRILL DAYS: MON  WED  FRI", "ASSEMBLY: CORNER OF RANGE RD", "", "-- RANGE CONTROL, AREA 7 --"]
    for i, t in enumerate(rows):
        c.text((60, 180 + i * 46), t, typ if i in (0, 7, 8) else sm, (40, 36, 30, 255))
    c.d.ellipse((370, 4, 398, 32), fill=(176, 40, 30, 255))          # a drawing pin (tiny, a pin not a room colour)
    return c.save("notice_drill")


def calendar_1965(month="MARCH", seed=3):
    c = Canvas(512, 768)
    c.im.paste(paper(512, 768, (238, 232, 214), seed, 0.3), (0, 0))
    art = Image.open(os.path.join(GEN, "oil_mesa.png")).convert("RGBA").resize((464, 300))
    c.im.paste(art, (24, 24))
    hd = F("georgiab.ttf", 46); sm = F("georgia.ttf", 22); num = F("arialbd.ttf", 24)
    c.text((256, 340), f"{month}  1965", hd, (60, 50, 40, 255), centre=True)
    c.text((256, 396), "MESA VALLEY FEED & SUPPLY", sm, (107, 122, 58, 255), centre=True)
    days = "S M T W T F S".split()
    for i, dname in enumerate(days):
        c.text((44 + i * 64, 440), dname, num, (90, 70, 50, 255))
    day = 1
    for w in range(5):
        for i in range(7):
            if (w == 0 and i < 1) or day > 31:
                continue
            x, y = 40 + i * 64, 480 + w * 52
            c.text((x, y), str(day), num, (50, 44, 36, 255))
            if day < 15:
                c.d.line([(x - 4, y + 2), (x + 34, y + 26)], fill=(40, 40, 40, 255), width=3)   # days crossed off, stopped on the 15th
            day += 1
    c.d.ellipse((40 + 1 * 64 - 10, 480 + 2 * 52 - 8, 40 + 1 * 64 + 44, 480 + 2 * 52 + 34), outline=(138, 40, 30, 255), width=3)
    return c.save("calendar_1965")


def poster(name, art, title, sub, colour=(107, 122, 58), title_top=True):
    c = Canvas(768, 1024)
    c.im.paste(paper(768, 1024, (236, 226, 196), hash(name) % 99, 0.3), (0, 0))
    a = Image.open(os.path.join(GEN, art)).convert("RGBA").resize((688, 688))
    c.im.paste(a, (40, 220 if title_top else 60))
    hd = F("impact.ttf", 104); sb = F("georgiab.ttf", 38)
    if title_top:
        c.text((384, 50), title, hd, colour + (255,), centre=True)
        c.text((384, 930), sub, sb, (70, 56, 40, 255), centre=True)
    else:
        c.text((384, 770), title, hd, colour + (255,), centre=True)
        c.text((384, 900), sub, sb, (70, 56, 40, 255), centre=True)
    im = c.im
    arr = np.asarray(im).astype(np.float32)
    n = noise(768, 1024, 80, 4)
    arr[..., :3] = arr[..., :3] * (0.9 + 0.1 * n[..., None]) + np.array([12, 6, -10]) * n[..., None]     # sun-faded, yellowed
    Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, name + ".png"))


def pennant():
    c = Canvas(1024, 512)
    c.d.polygon([(20, 40), (1000, 256), (20, 472)], fill=(107, 122, 58, 255))
    c.d.rectangle((0, 30, 40, 482), fill=(236, 232, 218, 255))
    f = F("impact.ttf", 110)
    c.text((90, 190), "MESA HIGH", f, (236, 232, 218, 255))
    c.save("pennant")


def sign(name, lines, bg=(232, 222, 190), fg=(30, 28, 24), band=None, w=1024, h=640, trefoil=False):
    """outdoor warning sign, sun-bleached, rust weeping from the bolt holes; our own words"""
    c = Canvas(w, h)
    base = paper(w, h, bg, len(name), 0.4)
    c.im.paste(base, (0, 0))
    if band:
        c.d.rectangle((0, 0, w, int(h * 0.3)), fill=band + (255,))
    y = int(h * 0.06)
    for i, (t, size, col_) in enumerate(lines):
        f = F("impact.ttf", size)
        c.stencil((w / 2 + (90 if (trefoil and i > 0) else 0), y), t, f, col_ + (255,), centre=True)
        y += int(size * 1.12)
    if trefoil:   # our own hazard mark: three blades round a dot inside a ring (simple geometry, own proportions)
        cx, cy, R = 150, int(h * 0.68), 110
        c.d.ellipse((cx - R, cy - R, cx + R, cy + R), outline=fg + (255,), width=10)
        for k in range(3):
            a0 = -90 + k * 120 - 28
            c.d.pieslice((cx - R + 22, cy - R + 22, cx + R - 22, cy + R - 22), a0, a0 + 56, fill=fg + (255,))
        c.d.ellipse((cx - 28, cy - 28, cx + 28, cy + 28), fill=bg + (255,))
        c.d.ellipse((cx - 16, cy - 16, cx + 16, cy + 16), fill=fg + (255,))
    for (bx, by) in ((30, 30), (w - 30, 30), (30, h - 30), (w - 30, h - 30)):
        c.d.ellipse((bx - 9, by - 9, bx + 9, by + 9), fill=(70, 50, 30, 255))
        c.d.polygon([(bx - 6, by), (bx + 6, by), (bx + 3, by + 70), (bx - 3, by + 70)], fill=(140, 80, 40, 120))
    arr = np.asarray(c.im).astype(np.float32)
    n = noise(w, h, 6, len(name) + 1)
    arr[..., :3] = arr[..., :3] * (0.86 + 0.18 * n[..., None]) + 18 * (1 - n[..., None])
    Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, name + ".png"))


def labels():
    """small square labels: dummy chest numbers, truck side, canister set, cereal box, radio dial"""
    for i in range(1, 9):
        c = Canvas(256, 256)
        f = F("impact.ttf", 150)
        c.stencil((128, 40), f"{i:02d}", f, (40, 36, 30, 255), centre=True)
        c.save(f"dummy_num_{i}")
    c = Canvas(1024, 512, (232, 226, 206, 255))
    c.d.rectangle((0, 330, 1024, 400), fill=(107, 122, 58, 255))
    c.text((512, 70), "MESA VALLEY", F("georgiab.ttf", 120), (107, 122, 58, 255), centre=True)
    c.text((512, 210), "DAIRY  &  ICE", F("impact.ttf", 96), (70, 56, 40, 255), centre=True)
    c.text((512, 420), "FRESH TO YOUR DOOR SINCE 1951", F("arialbd.ttf", 44), (70, 56, 40, 255), centre=True)
    c.save("truck_side")
    c = Canvas(512, 256, (226, 214, 180, 255))
    for i, t in enumerate(("FLOUR", "SUGAR", "COFFEE", "TEA")):
        c.text((64 + i * 128, 100), t, F("georgiab.ttf", 30), (107, 122, 58, 255), centre=True)
    c.save("canisters")
    c = Canvas(512, 256, (40, 34, 28, 255))      # radio dial strip
    c.d.rectangle((16, 60, 496, 196), fill=(214, 200, 160, 255))
    for i in range(11):
        x = 40 + i * 43
        c.d.line([(x, 70), (x, 110)], fill=(40, 34, 28, 255), width=3)
        c.text((x, 120), str(55 + i * 10), F("arialbd.ttf", 22), (40, 34, 28, 255), centre=True)
    c.d.line([(230, 64), (230, 192)], fill=(150, 40, 30, 255), width=4)
    c.save("radio_dial")


def newspaper():
    c = Canvas(512, 512)
    c.im.paste(paper(512, 512, (226, 218, 196), 5, 0.4), (0, 0))
    c.text((256, 20), "THE RANGE COURIER", F("georgiab.ttf", 46), (30, 28, 24, 255), centre=True)
    c.d.line([(20, 80), (492, 80)], fill=(30, 28, 24, 255), width=3)
    c.text((256, 96), "TEST DATE SET FOR FRIDAY", F("impact.ttf", 44), (30, 28, 24, 255), centre=True)
    for col_ in range(3):
        for r in range(16):
            y = 170 + r * 20
            c.d.line([(24 + col_ * 162, y), (24 + col_ * 162 + 140 - (r % 5 == 4) * 50, y)], fill=(80, 76, 68, 255), width=6)
    c.save("newspaper")


def fabric_prints():
    """own printed fabrics: cowboy-print spread (kid's), plaid, chenille tufts, braided-rug ring, shag"""
    S = 512
    # plaid: olive / cream / rust
    yy, xx = np.mgrid[0:S, 0:S]
    a = np.zeros((S, S, 3), np.float32) + np.array([200, 190, 160])
    for per, w, colr in ((128, 36, (107, 122, 58)), (128, 10, (154, 90, 52)), (64, 4, (60, 50, 36))):
        m = ((xx % per) < w).astype(np.float32) * 0.5 + ((yy % per) < w).astype(np.float32) * 0.5
        a = a * (1 - m[..., None]) + np.array(colr) * m[..., None]
    Image.fromarray(a.astype(np.uint8)).save(os.path.join(OUT, "fab_plaid.png"))
    # chenille: cream with olive tufted diamonds
    im = Image.new("RGB", (S, S), (226, 218, 192)); d = ImageDraw.Draw(im)
    for gy in range(8):
        for gx in range(8):
            cx, cy = gx * 64 + (32 if gy % 2 else 0), gy * 64 + 32
            for t in range(8):
                ang = t * math.pi / 4
                d.ellipse((cx + 18 * math.cos(ang) - 3, cy + 18 * math.sin(ang) - 3, cx + 18 * math.cos(ang) + 3, cy + 18 * math.sin(ang) + 3), fill=(128, 136, 98))
            d.ellipse((cx - 5, cy - 5, cx + 5, cy + 5), fill=(176, 120, 104))
    im.save(os.path.join(OUT, "fab_chenille.png"))
    # cowboy print: lassos, boots, cacti, stars on sand
    im = Image.new("RGB", (S, S), (222, 206, 160)); d = ImageDraw.Draw(im)
    r = np.random.default_rng(9)
    for gy in range(4):
        for gx in range(4):
            cx, cy = gx * 128 + 64 + (32 if gy % 2 else 0), gy * 128 + 64
            k = (gx + gy) % 3
            if k == 0:   # cactus
                d.rectangle((cx - 8, cy - 40, cx + 8, cy + 36), fill=(107, 122, 58))
                d.rectangle((cx - 30, cy - 10, cx - 8, cy), fill=(107, 122, 58)); d.rectangle((cx - 30, cy - 30, cx - 20, cy), fill=(107, 122, 58))
                d.rectangle((cx + 8, cy - 2, cx + 28, cy + 8), fill=(107, 122, 58)); d.rectangle((cx + 20, cy - 24, cx + 30, cy + 8), fill=(107, 122, 58))
            elif k == 1:   # boot
                d.polygon([(cx - 14, cy - 36), (cx + 8, cy - 36), (cx + 8, cy + 14), (cx + 34, cy + 22), (cx + 34, cy + 34), (cx - 14, cy + 34)], fill=(140, 84, 46))
            else:   # star + lasso loop
                d.ellipse((cx - 26, cy - 18, cx + 26, cy + 18), outline=(154, 90, 52), width=4)
                d.polygon([(cx, cy - 12), (cx + 4, cy - 3), (cx + 12, cy), (cx + 4, cy + 3), (cx, cy + 12), (cx - 4, cy + 3), (cx - 12, cy), (cx - 4, cy - 3)], fill=(206, 160, 52))
    im.save(os.path.join(OUT, "fab_cowboy.png"))
    # braided rug: concentric bands olive / cream / rust with a braid twist
    im = Image.new("RGB", (S, S), (200, 190, 160)); d = ImageDraw.Draw(im)
    cols = [(107, 122, 58), (226, 214, 180), (154, 90, 52), (138, 156, 74), (200, 165, 60)]
    for i in range(24):
        inset = i * 10
        if inset * 2 >= S - 20:
            break
        d.ellipse((inset, inset * 0.9, S - inset, S - inset * 0.9), fill=cols[i % len(cols)])
    arr = np.asarray(im).astype(np.float32)
    tw = 0.85 + 0.15 * np.sin((xx + yy) * 0.7)
    Image.fromarray(np.clip(arr * tw[..., None], 0, 255).astype(np.uint8)).save(os.path.join(OUT, "fab_braid.png"))
    # shag: olive with long-pile noise
    n1 = noise(S, S, 2, 3); n2 = noise(S, S, 12, 4)
    a = np.stack([110 * (0.7 + 0.5 * n1) * (0.9 + 0.2 * n2), 124 * (0.7 + 0.5 * n1), 64 * (0.7 + 0.5 * n1)], -1)
    Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).save(os.path.join(OUT, "fab_shag.png"))
    # shower curtain: pale yellow with our own daisy dots
    im = Image.new("RGB", (S, S), (236, 226, 170)); d = ImageDraw.Draw(im)
    for gy in range(6):
        for gx in range(6):
            cx, cy = gx * 86 + (43 if gy % 2 else 0), gy * 86 + 43
            for t in range(6):
                ang = t * math.pi / 3
                d.ellipse((cx + 12 * math.cos(ang) - 7, cy + 12 * math.sin(ang) - 7, cx + 12 * math.cos(ang) + 7, cy + 12 * math.sin(ang) + 7), fill=(250, 246, 230))
            d.ellipse((cx - 6, cy - 6, cx + 6, cy + 6), fill=(206, 160, 52))
    im.save(os.path.join(OUT, "fab_curtain.png"))


def furniture_fx():
    """decals projected on furniture by the baker: torn upholstery (foam through a ragged rip), coffee rings, a water
    blot, a cigarette burn"""
    S = 256
    c = Canvas(S, S)
    r = np.random.default_rng(31)
    pts = []
    for i in range(28):
        a = i / 28 * 2 * math.pi
        rr = (0.62 + 0.3 * r.random()) * (100 if abs(math.sin(a)) < 0.6 else 54)
        pts.append((S / 2 + rr * math.cos(a), S / 2 + rr * 0.8 * math.sin(a)))
    c.d.polygon(pts, fill=(60, 48, 34, 255))
    inner = [(S / 2 + (x - S / 2) * 0.86, S / 2 + (y - S / 2) * 0.8) for x, y in pts]
    c.d.polygon(inner, fill=(214, 192, 126, 255))
    for i in range(40):          # foam crumbs / pores
        x, y = r.uniform(70, 186), r.uniform(100, 156)
        c.d.ellipse((x - 3, y - 2, x + 3, y + 2), fill=(176, 150, 90, 255))
    for (x, y) in pts[::3]:      # loose threads
        c.d.line([(x, y), (x + r.uniform(-14, 14), y + r.uniform(-14, 14))], fill=(70, 60, 44, 255), width=2)
    c.im.filter(ImageFilter.GaussianBlur(0.6)).save(os.path.join(OUT, "fx_tear.png"))
    c = Canvas(S, S)
    for (x, y, rr) in ((90, 100, 42), (150, 150, 40), (170, 80, 38)):
        c.d.ellipse((x - rr, y - rr, x + rr, y + rr), outline=(92, 62, 34, 170), width=6)
        c.d.ellipse((x - rr + 6, y - rr + 6, x + rr - 6, y + rr - 6), outline=(120, 86, 52, 70), width=3)
    c.im.filter(ImageFilter.GaussianBlur(1.2)).save(os.path.join(OUT, "fx_rings.png"))
    a = soft_blob(S, 33, rough=40)
    arr = np.zeros((S, S, 4), np.uint8); arr[..., 0], arr[..., 1], arr[..., 2] = 96, 72, 46
    arr[..., 3] = (np.clip(a * 1.5, 0, 1) * 150).astype(np.uint8)
    Image.fromarray(arr, "RGBA").filter(ImageFilter.GaussianBlur(3)).save(os.path.join(OUT, "fx_blot.png"))
    c = Canvas(S, S)
    c.d.ellipse((96, 96, 160, 160), fill=(40, 30, 20, 200)); c.d.ellipse((112, 112, 144, 144), fill=(20, 14, 10, 255))
    c.im.filter(ImageFilter.GaussianBlur(4)).save(os.path.join(OUT, "fx_burn.png"))


def main():
    wear_atlas()
    furniture_fx()
    notice_board()
    calendar_1965()
    pennant()
    labels()
    newspaper()
    fabric_prints()
    if os.path.exists(os.path.join(GEN, "poster_travel.png")):
        poster("poster_travel", "poster_travel.png", "SEE THE MESAS", "DRIVE THE OLD RANGE ROAD", (107, 122, 58), True)
    if os.path.exists(os.path.join(GEN, "poster_family.png")):
        poster("poster_kitchen", "poster_family.png", "MODERN LIVING", "ELECTRIC KITCHENS  -  1965 MODELS", (154, 90, 52), False)
    sign("sign_restricted", [("RESTRICTED", 150, (236, 232, 218)), ("TEST AREA 7", 110, (30, 28, 24)), ("NO ENTRY PAST THIS POINT", 64, (30, 28, 24)),
                             ("BY ORDER OF RANGE CONTROL", 44, (70, 60, 50))], band=(107, 122, 58))
    sign("sign_danger", [("DANGER", 170, (236, 232, 218)), ("BLAST ZONE", 120, (30, 28, 24)), ("KEEP OUT", 90, (30, 28, 24))],
         band=(40, 36, 30), trefoil=True)
    sign("sign_road", [("RANGE ROAD", 140, (30, 28, 24)), ("CLOSED TO", 100, (30, 28, 24)), ("ALL TRAFFIC", 100, (30, 28, 24))],
         bg=(236, 230, 210), w=1024, h=640)
    print("decals:", sorted(os.listdir(OUT)))


main()

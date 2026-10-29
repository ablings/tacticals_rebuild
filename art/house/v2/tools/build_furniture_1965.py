"""House map, 1965 test-site restyle, PART A: furniture (cover at the game's cover heights, EXACTLY the v1 footprints),
room variants with the same boxes, dressing, and the loose 1965 dressing masters (D65_*) that build_house.py places.
  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python art/house/v2/tools/build_furniture_1965.py -- [--nobake]

Rules (notes/house_1965_style.md): every H_* keeps its name, W x H x D, pivot, front (-Y) and collision boxes (ASM below is
v1's, unchanged); the look changes inside the box. Cover pieces get closed bases (skirts / plinths / kick boards).
Footprints are proved by tools/footprint_diff.py (v1 json vs v2 json). 1 unit = 1 stud, Z up, front = Blender -Y."""
import os, sys, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hcore import *          # noqa: F401,F403
import hcore
import kinds65               # noqa: F401  (1965 kinds into hcore.K)

BLEND = os.path.join(ROOT, "house_furniture.blend")
ROT = lambda deg, ax="X": Matrix.Rotation(math.radians(deg), 4, ax)
T = lambda x, y, z: Matrix.Translation((x, y, z))
FX = "decals65/"
G65 = "gen65/"


def xf(fs, M):
    vs = {v for f in fs for v in f.verts}
    for v in vs:
        v.co = M @ v.co
    for f in fs:
        f.normal_update()
    return fs


def about(p, M):
    p = Vector(p)
    return Matrix.Translation(p) @ M @ Matrix.Translation(-p)


def zstretch(mb, H0, H1):
    k = H1 / H0
    for v in mb.bm.verts:
        v.co.z *= k
    mb.height = H1
    return mb


def pull(mb, x, y, z, kind="brass", w=0.5, facing=-1, proud=0.08):
    """1960s bar pull: two posts + a bar whose front is exactly `proud` off the face at y (facing -Y by default)"""
    s = facing
    a, b = sorted((y + s * proud, y + s * (proud - 0.05)))
    mb.boxr((x - w / 2, a, z - 0.035), (x + w / 2, b, z + 0.035), kind)
    for dx in (-w / 2 + 0.04, w / 2 - 0.04):
        a, b = sorted((y - s * 0.01, y + s * (proud - 0.04)))
        mb.boxr((x + dx - 0.03, a, z - 0.03), (x + dx + 0.03, b, z + 0.03), kind)


def knob(mb, x, y, z, kind="brass", r=0.09, facing=-1, depth=0.17):
    """round knob whose front is exactly `depth` off the face at y"""
    M = T(x, y - facing * 0.01, z) @ ROT(90 * (-facing))
    k = (depth + 0.01) / 0.17
    mb.lathe([(0, 0), (0.04, 0), (0.04, 0.06 * k), (r, 0.1 * k), (r * 0.9, 0.16 * k), (0, 0.17 * k)], 10, kind, M=M)


def tapered_leg(mb, x, y, z0, z1, r0=0.1, r1=0.05, kind="walnut65", splay=(0, 0)):
    mb.tube([(x, y, z1), (x + splay[0], y + splay[1], z0)], r0, kind, segs=6)


def stain(mb, img, n, c, w, h, kinds, op=0.9):
    mb.decal(FX + img, n, c, w, h, col=None, op=op, kinds=kinds, depth=0.3)


# =========================================================================================================== LOW COVER
def sofa_sectional():
    """skirted L-sectional in cream vinyl: tufted back to 3.4, rolled arms 2.45, olive bolsters, a torn seat cushion.
    v1 boxes (pre-centre coords): back y 0.15..1.8 to 3.4, arms to 2.6, seats to 1.8; union x -6..6, y -5.4..1.8"""
    mb = MB("H_Sofa_Sectional", "Sofa", 3.4)
    V = "vinyl_cream"
    mb.boxr((-5.9, -1.7, 0), (5.9, 1.7, 1.12), V)                         # skirt (closed base)
    mb.boxr((2.25, -5.3, 0), (5.9, -1.6, 1.12), V)
    mb.boxr((-5.92, -1.72, 1.02), (5.92, 1.72, 1.12), "vinyl_olive")        # welt band at the skirt top
    mb.boxr((2.23, -5.32, 1.02), (5.92, -1.62, 1.12), "vinyl_olive")
    for x0, x1 in ((-5.05, -1.7), (-1.7, 1.65), (1.65, 5.05)):
        rbox(mb, (x0 + 0.02, -1.8, 1.08), (x1 - 0.02, 0.6, 1.78), V, r=0.2, segs=2)
    rbox(mb, (2.22, -5.4, 1.08), (5.03, -1.82, 1.78), V, r=0.2, segs=2)
    rbox(mb, (-6.0, 0.6, 0.0), (6.0, 1.8, 3.4), V, r=0.35, segs=3)          # tufted back
    for row, z in enumerate((2.2, 2.75)):
        for i in range(17):
            x = -5.3 + i * 0.66 + (0.33 if row else 0)
            if x > 5.4:
                continue
            mb.lathe([(0, 0), (0.07, 0), (0.06, 0.06), (0, 0.07)], 6, "vinyl_olive", M=T(x, 0.62, z) @ ROT(90))
    rbox(mb, (-6.0, -1.8, 0.0), (-5.05, 1.8, 2.45), V, r=0.38, segs=3)      # rolled arms
    rbox(mb, (5.05, -5.4, 0.0), (6.0, 1.8, 2.45), V, r=0.38, segs=3)
    for x0, x1 in ((-4.9, -1.9), (1.4, 4.4)):                               # olive bolsters against the back
        mb.tube([(x0, 0.35, 2.05), (x1, 0.35, 2.05)], 0.27, "vinyl_olive", segs=12)
    for x in (-4.9, -1.9, 1.4, 4.4):
        mb.lathe([(0, -0.01), (0.27, -0.01), (0.27, 0.01), (0, 0.01)], 12, "vinyl_olive", M=T(x, 0.35, 2.05) @ ROT(90, "Y"))
    stain(mb, "fx_tear", (0, 0, 1), (-3.3, -0.7, 1.78), 1.4, 1.0, [V])
    stain(mb, "fx_tear", (-1, 0, 0), (-6.0, 0.3, 1.7), 1.0, 0.8, [V])
    stain(mb, "fx_blot", (0, 0, 1), (3.6, -3.5, 1.78), 1.6, 1.6, [V])
    stain(mb, "fx_rings", (0, 0, 1), (5.5, 0.2, 2.45), 0.7, 0.7, [V])
    stain(mb, "fx_burn", (0, 0, 1), (0.4, -1.0, 1.78), 0.35, 0.35, [V])
    return finish(mb)


def armchair(name="H_Armchair", F="tweed_olive", atlas="Chairs"):
    """club armchair: rounded arms flowing into the back, skirt to the floor. boxes: back y 0.35..2 to 3.4, arms 2.5,
    seat 1.8; footprint x -2.1..2.1, y -2..2"""
    mb = MB(name, atlas, 3.4)
    mb.boxr((-2.0, -1.9, 0), (2.0, 1.9, 1.05), F)                           # skirt
    mb.boxr((-2.02, -1.92, 0.95), (2.02, 1.92, 1.05), "walnut65")           # wood band at the skirt top
    rbox(mb, (-1.38, -2.0, 1.0), (1.38, 0.5, 1.78), F, r=0.22, segs=2)      # seat cushion
    rbox(mb, (-2.1, 0.45, 0.0), (2.1, 2.0, 3.4), F, r=0.45, segs=3)         # back
    for sx in (-1, 1):
        rbox(mb, (sx * 1.36 - (0.74 if sx > 0 else 0) + (0 if sx > 0 else -0.74) + (0.74 if sx > 0 else 0) * 0, -2.0, 0.0),
             (sx * 1.36 + (0.74 if sx > 0 else 0), 2.0, 2.45), F, r=0.36, segs=3) if False else None
        x0, x1 = (1.36, 2.1) if sx > 0 else (-2.1, -1.36)
        rbox(mb, (x0, -2.0, 0.0), (x1, 2.0, 2.45), F, r=0.34, segs=3)
    for sx in (-1, 1):                                                      # short tapered leg stubs under the skirt
        for sy in (-1, 1):
            mb.lathe([(0, 0), (0.08, 0), (0.1, 0.06), (0, 0.06)], 6, "walnut65", M=T(sx * 1.85, sy * 1.65, 0))
    stain(mb, "fx_tear", (0, -1, 0), (1.73, -2.0, 1.6), 0.6, 0.6, [F])
    stain(mb, "fx_blot", (0, 0, 1), (-0.3, -0.8, 1.78), 1.2, 1.2, [F])
    return finish(mb)


def bed(name, W, L, atlas, frame, spread, spread_img, pillows, maple=False):
    """1960s bed: wood headboard 3.4 at +Y (spindles + solid backer for maple), spread draping to the floor (closed base),
    low footboard. v1 boxes: headboard y L/2-0.6..L/2 to 3.4, body to 2.4"""
    mb = MB(name, atlas, 3.4)
    y0, y1 = -L / 2, L / 2
    Wh = W / 2 + 0.15
    if maple:   # spindle headboard: posts, rails, spindles, solid backer board against the wall
        for sx in (-1, 1):
            mb.lathe([(0, 0), (0.2, 0), (0.2, 2.6), (0.16, 2.8), (0.2, 3.0), (0.14, 3.25), (0.08, 3.4), (0, 3.4)], 10, frame,
                     M=T(sx * (Wh - 0.2), y1 - 0.27, 0))
        mb.boxr((-Wh + 0.3, y1 - 0.4, 2.8), (Wh - 0.3, y1 - 0.14, 3.1), frame)
        mb.boxr((-Wh + 0.3, y1 - 0.4, 1.0), (Wh - 0.3, y1 - 0.14, 1.3), frame)
        n = int((2 * Wh - 0.6) / 0.45)
        for i in range(n):
            x = -Wh + 0.3 + (2 * Wh - 0.6) * (i + 0.5) / n
            mb.lathe([(0, 1.3), (0.06, 1.3), (0.09, 1.8), (0.05, 2.1), (0.09, 2.5), (0.06, 2.8), (0, 2.8)], 6, frame, M=T(x, y1 - 0.27, 0))
        mb.boxr((-Wh + 0.25, y1 - 0.12, 0.0), (Wh - 0.25, y1, 3.05), frame)        # backer
    else:       # walnut panel headboard with a shaped top
        mb.prism([(-Wh, 0), (Wh, 0), (Wh, 3.0), (Wh - 0.6, 3.25), (Wh - 1.4, 3.4), (-Wh + 1.4, 3.4), (-Wh + 0.6, 3.25), (-Wh, 3.0)],
                 "Y", y1 - 0.55, y1, frame)
    # footboard 2.3 (inside the 2.4 body box)
    mb.boxr((-W / 2, y0, 0.0), (W / 2, y0 + 0.3, 2.3), frame)
    # mattress + spread draped to the floor (sides), pillows under the spread fold
    rbox(mb, (-W / 2 + 0.15, y0 + 0.32, 1.0), (W / 2 - 0.15, y1 - 0.6, 2.1), "linen_old", r=0.18, segs=2)
    rbox(mb, (-W / 2 + 0.02, y0 + 0.3, 0.02), (W / 2 - 0.02, y1 - 1.9, 2.25), spread, r=0.15, segs=2)     # spread over the bed, down to the floor
    for sx in (-1, 1):
        mb.boxr((sx * (W / 2 - 0.06) - 0.06, y1 - 1.95, 0.02), (sx * (W / 2 - 0.06) + 0.06, y1 - 0.6, 2.0), spread)   # drop at the pillow end
    rbox(mb, (-W / 2 + 0.02, y1 - 2.1, 1.85), (W / 2 - 0.02, y1 - 1.6, 2.38), spread, r=0.2, segs=2)              # turned-back fold
    n = len(pillows)
    pw = (W - 0.6) / n
    for i, k in enumerate(pillows):
        cx = -W / 2 + 0.3 + pw * (i + 0.5)
        xf(rbox(mb, (-pw / 2 + 0.06, -0.5, 0), (pw / 2 - 0.06, 0.5, 0.5), k, r=0.24, segs=2), T(cx, y1 - 1.15, 1.88) @ ROT(-10))
    mb.decal(FX + spread_img, (0, 0, 1), (0, (y0 + y1 - 1.9) / 2, 2.25), W, L - 2.2, col=None, op=1.0, kinds=[spread], depth=0.3)
    stain(mb, "fx_blot", (0, 0, 1), (W * 0.2, y0 + 2.0, 2.25), 1.6, 1.6, [spread], op=0.7)
    return finish(mb)


def dresser(name="H_Dresser", wood="walnut65", atlas="WoodA", style="lowboy"):
    """6 x 2.3 x 3.4 low cover. styles: lowboy (3 x 2 drawers, skirted plinth), credenza (sliding doors), phone (telephone
    table: one drawer over a skirted cupboard), cream (painted kid's chest). Front -Y; v1 extents y -1.2..1.1 (pulls)"""
    mb = MB(name, atlas, 3.4)
    mb.boxr((-3.0, -1.05, 0.3), (3.0, 1.1, 3.25), wood)
    mb.boxr((-3.0, -1.1, 3.22), (3.0, 1.1, 3.4), wood)                      # top with a small overhang at the front
    mb.prism([(-3.0, 0.0), (3.0, 0.0), (3.0, 0.32), (2.6, 0.32), (2.4, 0.18), (-2.4, 0.18), (-2.6, 0.32), (-3.0, 0.32)], "Y", -1.08, 1.05, wood)  # shaped skirt
    if style == "credenza":
        for i, (x0, x1) in enumerate(((-2.95, -0.02), (0.02, 2.95))):
            mb.boxr((x0, -1.12, 0.4), (x1, -1.06, 3.15), "walnut_slat65", grain=2)
            mb.boxr((x0 + 0.1 if i else x1 - 0.5, -1.2, 1.5), (x0 + 0.5 if i else x1 - 0.1, -1.1, 2.3), "brass")      # finger pulls
    elif style == "phone":
        mb.boxr((-2.95, -1.12, 2.5), (2.95, -1.05, 3.15), wood)
        pull(mb, 0, -1.12, 2.82, proud=0.08)
        for x0, x1 in ((-2.95, -0.02), (0.02, 2.95)):
            mb.boxr((x0, -1.12, 0.4), (x1, -1.05, 2.45), wood)
            knob(mb, x1 - 0.35 if x0 < 0 else x0 + 0.35, -1.12, 1.5, depth=0.08)
    else:
        kind_d = wood
        for (x0, x1) in ((-2.95, -0.02), (0.02, 2.95)):
            for (z0, z1) in ((0.36, 1.32), (1.36, 2.28), (2.32, 3.18)):
                mb.boxr((x0 + 0.03, -1.12, z0 + 0.03), (x1 - 0.03, -1.05, z1 - 0.03), kind_d)
                pull(mb, (x0 + x1) / 2, -1.12, (z0 + z1) / 2 + 0.1, kind="brass" if style != "cream" else "chrome65", w=0.7)
    stain(mb, "fx_rings", (0, 0, 1), (1.6, 0.2, 3.4), 0.9, 0.9, [wood])
    # pulls reach y -1.2: same depth as v1
    return finish(mb)


def nightstand(name="H_Nightstand", wood="walnut65"):
    mb = MB(name, "WoodA", 2.0)
    mb.boxr((-1.1, -0.95, 0.3), (1.1, 0.95, 2.0), wood)
    mb.boxr((-1.0, -0.85, 0), (1.0, 0.85, 0.32), "plinth65")
    mb.boxr((-1.06, -1.02, 1.2), (1.06, -0.95, 1.92), wood)
    pull(mb, 0, -1.02, 1.55, w=0.6, proud=0.08)
    mb.boxr((-1.06, -1.02, 0.36), (1.06, -0.95, 1.14), wood)
    knob(mb, 0.7, -1.02, 0.75, depth=0.08)
    stain(mb, "fx_rings", (0, 0, 1), (0.3, 0.2, 2.0), 0.8, 0.8, [wood])
    return finish(mb)


def tv_console(name="H_TVConsole", style="tv"):
    """8 x 2.02 x 3.4 low cover. tv: walnut console TV + radiogram, CRT in the middle, speaker cloth both sides, lid with a
    record player under it; buffet: walnut sideboard with louvred doors (dining room)"""
    mb = MB(name, "WoodA", 3.4)
    W = "walnut65"
    mb.boxr((-4.0, -0.95, 0.3), (4.0, 1.0, 3.4), W)
    mb.prism([(-4.0, 0), (4.0, 0), (4.0, 0.34), (3.6, 0.34), (3.45, 0.12), (-3.45, 0.12), (-3.6, 0.34), (-4.0, 0.34)], "Y", -0.98, 0.98, W)
    if style == "tv":
        mb.boxr((-1.6, -1.01, 0.75), (1.6, -0.95, 3.0), W)                   # bezel frame
        rbox(mb, (-1.35, -1.01, 1.0), (1.35, -0.9, 2.8), "screen_crt", r=0.25, segs=2)
        for sx in (-1, 1):
            mb.boxr((sx * 2.8 - 1.05, -1.0, 0.6), (sx * 2.8 + 1.05, -0.94, 2.95), "speaker_cloth")
            for i in range(5):
                x = sx * 2.8 - 0.95 + i * 0.475
                mb.boxr((x - 0.04, -1.01, 0.6), (x + 0.04, -0.95, 2.95), W)
        for i, x in enumerate((-0.9, -0.3, 0.3, 0.9)):
            knob(mb, x, -0.95, 0.52, kind="brass", r=0.07, depth=0.07)
        mb.boxr((-3.9, -0.95, 3.38), (3.9, 0.95, 3.4), W)
        stain(mb, "fx_rings", (0, 0, 1), (-2.6, 0.0, 3.4), 0.8, 0.8, [W])
    else:
        for x0, x1 in ((-3.95, -2.0), (-1.98, -0.02), (0.02, 1.98), (2.0, 3.95)):
            mb.boxr((x0, -1.01, 0.42), (x1, -0.95, 3.2), "walnut_slat65", grain=2)
            knob(mb, x1 - 0.3 if x0 < 0 else x0 + 0.3, -1.01, 1.8, depth=0.01)
        stain(mb, "fx_blot", (0, 0, 1), (1.5, 0.0, 3.4), 1.2, 1.2, [W])
    return finish(mb)


def coffee_table():
    """kidney-shaped walnut coffee table with peg legs, magazines and an ashtray (dressing, 5 x 2.8)"""
    mb = MB("H_CoffeeTable", "Decor", 1.66)
    pts = []
    for i in range(32):
        a = 2 * math.pi * i / 32
        r = 1.0 - 0.18 * max(0, math.cos(a - math.pi / 2)) ** 2
        pts.append((2.5 * math.cos(a), 1.4 * math.sin(a) * r - 0.0))
    ymax = max(p[1] for p in pts)
    pts = [(x, y * (1.4 / ymax) if y > 0 else y) for x, y in pts]
    mb.prism(pts, "Z", 1.2, 1.38, "walnut65")
    for (x, y) in ((-1.8, -0.6), (1.8, -0.6), (-1.3, 0.75), (1.3, 0.75)):
        mb.tube([(x * 0.9, y * 0.9, 1.22), (x, y, 0.02)], 0.07, "walnut65", segs=6)
    mb.boxr((-1.4, -0.5, 1.38), (-0.2, 0.4, 1.44), "paper65"); mb.boxr((-1.2, -0.3, 1.44), (-0.1, 0.55, 1.5), "paper65")
    mb.lathe([(0, 1.38), (0.32, 1.38), (0.36, 1.5), (0.28, 1.5), (0.22, 1.44), (0, 1.44)], 12, "glass65", M=T(1.2, 0.0, 0))
    mb.lathe([(0, 1.38), (0.16, 1.38), (0.05, 1.45), (0.05, 1.5), (0.4, 1.6), (0.42, 1.66), (0.36, 1.66), (0, 1.56)], 14, "glass65", M=T(0.3, 0.5, 0))   # candy dish
    stain(mb, "fx_rings", (0, 0, 1), (0.6, -0.3, 1.38), 0.9, 0.9, ["walnut65"])
    return finish(mb)


def side_table():
    mb = MB("H_SideTable", "Decor", 2.14)
    mb.lathe([(0, 2.0), (0.9, 2.0), (0.9, 2.14), (0, 2.14)], 20, "walnut65")
    mb.lathe([(0, 0.9), (0.75, 0.9), (0.75, 0.98), (0, 0.98)], 18, "walnut65")
    for i in range(3):
        a = 2 * math.pi * i / 3
        mb.tube([(0.45 * math.cos(a), 0.45 * math.sin(a), 2.0), (0.8 * math.cos(a), 0.8 * math.sin(a), 0.0)], 0.06, "walnut65", segs=6)
    return finish(mb)


def desk(name="H_Desk", style="tanker"):
    """5 x 2.44 x 2.62: tanker = steel office desk in grey-green with a drawer pedestal; school = maple kid's desk"""
    mb = MB(name, "Desk", 2.62)
    if style == "tanker":
        K_ = "paint_grey_green"
        mb.boxr((-2.5, -1.2, 2.45), (2.5, 1.2, 2.62), "laminate")
        mb.boxr((0.8, -1.1, 0.1), (2.45, 1.1, 2.46), K_)
        mb.boxr((-2.45, -1.1, 0.1), (-2.2, 1.1, 2.46), K_)
        mb.boxr((-2.2, 0.95, 0.9), (0.8, 1.1, 2.46), K_)
        mb.boxr((-2.45, -1.0, 0.0), (2.45, 1.0, 0.12), "rubber65")
        for z0, z1 in ((0.15, 1.15), (1.2, 1.8), (1.85, 2.42)):
            mb.boxr((0.84, -1.17, z0), (2.41, -1.1, z1), K_)
            pull(mb, 1.62, -1.15, z1 - 0.25, kind="chrome65", w=0.6)
    else:
        mb.boxr((-2.5, -1.2, 2.45), (2.5, 1.2, 2.62), "maple")
        for sx in (-1, 1):
            for sy in (-1, 1):
                mb.tube([(sx * 2.25, sy * 0.95, 2.46), (sx * 2.35, sy * 1.05, 0.02)], 0.08, "maple", segs=6)
        mb.boxr((-2.2, -0.95, 2.0), (2.2, 0.95, 2.45), "maple")
        mb.boxr((-2.0, -1.17, 2.05), (2.0, -0.95, 2.4), "maple")
        knob(mb, 0, -1.17, 2.22, kind="maple", depth=0.07)
    return finish(mb)


def desk_chair():
    """wooden spindle-back desk chair (dressing)"""
    mb = MB("H_DeskChair", "Desk", 3.59)
    mb.boxr((-1.091, -0.95, 1.45), (1.091, 0.9, 1.6), "maple")
    for sx in (-1, 1):
        for sy in (-1, 1):
            mb.tube([(sx * 0.8, sy * 0.7, 1.46), (sx * 0.95, sy * 0.85 + (0.1 if sy > 0 else 0), 0.02)], 0.07, "maple", segs=6)
    for sx in (-1, 1):
        mb.tube([(sx * 0.8, 0.82, 1.55), (sx * 0.85, 1.05, 3.4)], 0.07, "maple", segs=6)
    mb.boxr((-0.95, 0.95, 3.22), (0.95, 1.14, 3.59), "maple")
    for i in range(5):
        x = -0.6 + i * 0.3
        mb.tube([(x, 0.85, 1.58), (x, 1.04, 3.24)], 0.035, "maple", segs=5)
    for sx in (-1, 1):
        mb.tube([(sx * 1.091 + (-0.03 if sx > 0 else 0.03), 0.0, 0.6), (sx * 0.9, 0.0, 0.6)], 0.03, "maple", segs=4) if False else None
    return finish(mb)


# --- dining
def pleated_rect(hx, hy, amp=0.07, pitch=0.9, grow=0.0):
    """plan outline of a cloth drop hanging inside x +-hx, y +-hy: soft vertical pleats pull the cloth inward by up to amp
    (never outward, so the cover box and the art bbox stay put); grow pushes the whole outline out (a hem over the drop)"""
    pts = []
    for (x0, y0), (x1, y1) in (((-hx, -hy), (hx, -hy)), ((hx, -hy), (hx, hy)), ((hx, hy), (-hx, hy)), ((-hx, hy), (-hx, -hy))):
        L = math.hypot(x1 - x0, y1 - y0)
        n = max(2, int(round(L / (pitch / 4))))
        ux, uy = (x1 - x0) / L, (y1 - y0) / L
        nx, ny = uy, -ux                         # outward normal of a counter-clockwise side
        for i in range(n):
            t = i / n * L
            d = amp * (0.5 - 0.5 * math.cos(2 * math.pi * t / pitch)) * min(1.0, t / 0.4, (L - t) / 0.4) - grow
            pts.append((x0 + ux * t - nx * d, y0 + uy * t - ny * d))
    return pts


def dining_table():
    """walnut table under a floor-length cream linen tablecloth (fix65: the cloth closes the 2.6 table box down to 0.1, so
    a crouching player sees cloth, not floor, where shots stop). Olive woven hem, dust and stains; brass feet in the gap."""
    mb = MB("H_DiningTable", "Dining", 2.6)
    C, H = "tablecloth65", "hem65"
    mb.boxr((-4.0, -2.0, 2.5), (4.0, 2.0, 2.6), C)                           # cloth over the top (the chrome edge is under it)
    mb.prism(pleated_rect(3.96, 1.96), "Z", 0.16, 2.54, C)                   # the drop, pleated (the hem takes it to 0.1)
    mb.prism(pleated_rect(3.96, 1.96, grow=0.025), "Z", 0.1, 0.34, H)        # woven hem band
    for sx in (-1, 1):
        for sy in (-1, 1):
            mb.lathe([(0, 0), (0.09, 0), (0.09, 0.14), (0, 0.14)], 8, "brass", M=T(sx * 3.45, sy * 1.45, 0))
    stain(mb, "fx_rings", (0, 0, 1), (2.6, 0.6, 2.6), 0.8, 0.8, [C])
    stain(mb, "fx_blot", (0, 0, 1), (-2.4, -0.7, 2.6), 1.3, 1.1, [C], op=0.7)
    stain(mb, "fx_blot", (0, -1, 0), (1.2, -2.0, 1.8), 1.4, 1.6, [C], op=0.55)
    stain(mb, "fx_tear", (0, 1, 0), (-2.2, 2.0, 0.6), 0.9, 0.8, [C, H])
    stain(mb, "fx_burn", (1, 0, 0), (4.0, 0.5, 2.1), 0.4, 0.4, [C], op=0.8)
    return finish(mb)


def dining_chair():
    """vinyl-and-chrome dinette chair with a skirted seat and a solid back down to the floor (fix65: nothing see-through
    inside the set's 1.75 seat and 3.4 back boxes). Mustard seat and back pad, cream vinyl skirt and kick panel, chrome
    welt, kick band, back edges and glides. Back top 3.39 and extents exactly as before"""
    mb = MB("H_DiningChair", "Dining", 3.39)
    rbox(mb, (-0.95, -0.95, 1.36), (0.95, 0.9, 1.72), "vinyl_mustard", r=0.12)          # seat cushion (unchanged extents)
    rbox(mb, (-0.92, 0.72, 2.1), (0.92, 0.987, 3.392), "vinyl_mustard", r=0.14)         # back pad (top 3.392 = v1)
    mb.boxr((-0.93, -0.93, 1.32), (0.93, 0.88, 1.42), "chrome65")                       # chrome welt under the seat
    mb.boxr((-0.9, -0.9, 0.12), (0.9, 0.8, 1.4), "vinyl_cream")                         # skirt, closed to the floor
    mb.boxr((-0.91, 0.72, 0.2), (0.91, 0.97, 2.18), "vinyl_cream")                      # solid kick panel under the back pad
    mb.boxr((-0.92, -0.92, 0.08), (0.92, 0.98, 0.26), "chrome65")                       # chrome kick band
    for sx in (-1, 1):                                                                  # chrome edges up the back
        mb.tube([(sx * 0.9, 0.86, 0.22), (sx * 0.9, 0.86, 2.2)], 0.05, "chrome65", segs=8)
        for sy in (-0.82, 0.82):                                                        # glides in the 0.1 gap
            mb.lathe([(0, 0), (0.08, 0), (0.08, 0.12), (0, 0.12)], 8, "chrome65", M=T(sx * 0.8, sy, 0))
    stain(mb, "fx_tear", (0, 0, 1), (0.3, -0.2, 1.72), 0.6, 0.5, ["vinyl_mustard"])
    stain(mb, "fx_blot", (0, 1, 0), (-0.3, 0.97, 0.9), 0.9, 1.0, ["vinyl_cream"], op=0.6)
    return finish(mb)


def table_setting():
    """a table fully set and left: 6 plates, glasses, cutlery, a roast under a dome cover, a jug (inside the set's 3.39 top)"""
    mb = MB("H_TableSetting", "Dining", 3.3)
    for x in (-2.1, 0.0, 2.1):
        for sy in (-1, 1):
            y = sy * 1.35
            mb.lathe([(0, 2.6), (0.42, 2.6), (0.5, 2.66), (0.46, 2.67), (0.3, 2.63), (0, 2.63)], 16, "china", M=T(x, y, 0))
            mb.lathe([(0, 2.6), (0.1, 2.6), (0.13, 2.98), (0.11, 2.98), (0.09, 2.62), (0, 2.62)], 10, "glass65", M=T(x + 0.55, y - sy * 0.35, 0))
            for dx in (-0.62, 0.62):
                mb.boxr((x + dx - 0.04, y - 0.38, 2.6), (x + dx + 0.04, y + 0.38, 2.63), "chrome65")
    mb.lathe([(0, 2.6), (0.85, 2.6), (0.95, 2.66), (0, 2.66)], 20, "china", M=T(-0.8, 0, 0))
    ellipsoid(mb, (-0.8, 0, 2.86), (0.55, 0.45, 0.3), "food_roast", segs=12, rings=6)
    mb.lathe([(0, 2.66), (0.8, 2.66), (0.78, 2.9), (0.55, 3.18), (0.12, 3.24), (0.12, 3.3), (0, 3.3)], 18, "chrome65", M=T(0.9, 0, 0))   # dome cover
    mb.lathe([(0, 2.6), (0.22, 2.6), (0.26, 2.9), (0.18, 3.15), (0.2, 3.2), (0, 3.2)], 12, "glass65", M=T(-2.9, 0.4, 0))
    return finish(mb)


def bar_stool():
    """chrome bar stool with an olive vinyl top and a foot ring"""
    mb = MB("H_BarStool", "Kitchen", 2.6)
    mb.lathe([(0, 2.3), (0.7, 2.3), (0.74, 2.42), (0.68, 2.6), (0, 2.6)], 20, "vinyl_olive")
    mb.lathe([(0, 2.2), (0.55, 2.2), (0.55, 2.32), (0, 2.32)], 16, "chrome65")
    for i in range(4):
        a = math.pi / 4 + i * math.pi / 2
        mb.tube([(0.38 * math.cos(a), 0.38 * math.sin(a), 2.22), (0.62 * math.cos(a), 0.62 * math.sin(a), 0.0)], 0.05, "chrome65", segs=6)
    mb.revolve([(0.5, 0.8), (0.56, 0.8), (0.56, 0.86), (0.5, 0.86)], 16, "chrome65")
    return finish(mb)


# --- kitchen (harvest gold enamel, chrome bar handles, grey laminate counters with a chrome edge)
EN = "enamel_olive"


def counter_top(mb, x0, x1, y0, y1, z0=3.12, z1=3.4, hole=None):
    """laminate slab with a ribbed chrome edge band on the front (-Y) and ends, optional rectangular cut-out"""
    def slab(a, b, c, d):
        mb.boxr((a, c, z0), (b, d, z1), "laminate")
    if hole:
        hx0, hx1, hy0, hy1 = hole
        slab(x0 + 0.04, x1 - 0.04, y0 + 0.04, hy0); slab(x0 + 0.04, x1 - 0.04, hy1, y1)
        slab(x0 + 0.04, hx0, hy0 - 0.02, hy1 + 0.02); slab(hx1, x1 - 0.04, hy0 - 0.02, hy1 + 0.02)
    else:
        slab(x0 + 0.04, x1 - 0.04, y0 + 0.04, y1)
    mb.boxr((x0, y0, z0), (x1, y0 + 0.045, z1), "chrome65", groove=1.0)
    mb.boxr((x0, y0 + 0.02, z0), (x0 + 0.045, y1, z1), "chrome65")
    mb.boxr((x1 - 0.045, y0 + 0.02, z0), (x1, y1, z1), "chrome65")


def island():
    """10 x 4.68 x 3.4 enamel peninsula island: gold doors + drawers with chrome bar pulls, laminate top, seating overhang +Y"""
    mb = MB("H_KitchenIsland", "Kitchen", 3.4)
    mb.boxr((-4.75, -2.2, 0.35), (4.75, 1.3, 3.13), EN)
    mb.boxr((-4.6, -2.0, 0), (4.6, 1.15, 0.4), "plinth65")
    counter_top(mb, -5.0, 5.0, -2.3, 2.3)
    for sx in (-1, 1):
        mb.boxr((sx * 4.875 - 0.125, -2.24, 0.0), (sx * 4.875 + 0.125, 2.24, 3.13), EN)
    xs = [-4.68, -2.34, 0.0, 2.34, 4.68]
    for x0, x1 in zip(xs, xs[1:]):
        mb.boxr((x0 + 0.03, -2.27, 2.45), (x1 - 0.03, -2.2, 3.05), EN)
        pull(mb, (x0 + x1) / 2, -2.27, 2.75, kind="chrome65", w=1.0, proud=0.11)
        mb.boxr((x0 + 0.03, -2.27, 0.45), (x1 - 0.03, -2.2, 2.4), EN)
        pull(mb, x1 - 0.3 if x0 < 0 else x0 + 0.3, -2.27, 2.0, kind="chrome65", w=0.6, proud=0.11)
    # pulls reach y -2.37 .. -2.38: v1 extents -2.38 (pulls) .. 2.3 (top)
    stain(mb, "fx_rings", (0, 0, 1), (-2.5, 1.2, 3.4), 0.8, 0.8, ["laminate"])
    return finish(mb)


def fruit_bowl():
    mb = MB("H_FruitBowl", "Kitchen", 0.66)
    mb.lathe([(0, 0), (0.45, 0), (0.75, 0.32), (0.7, 0.34), (0.4, 0.07), (0, 0.07)], 18, "ceramic_olive")
    for (dx, dy, dz, k) in ((0.2, 0.1, 0.24, "wax_fruit"), (-0.2, 0.15, 0.24, "wax_fruit2"), (0.0, -0.22, 0.26, "wax_fruit"), (0.05, 0.05, 0.47, "wax_fruit2")):
        ellipsoid(mb, (dx, dy, dz), (0.2, 0.2, 0.19), k, segs=7, rings=4)
    return finish(mb)


def kitchen_base(kind):
    """4 x 2.46 x 3.4 module: gold enamel; sink = double drainer in chrome with a mixer tap; hob = freestanding-look range in
    cream enamel with coil burners, oven door with a window. Front -Y; v1 y extents -1.29..1.2 (hob) / -1.26..1.2"""
    name = {"plain": "H_KitchenBase", "sink": "H_KitchenSink", "hob": "H_KitchenHob"}[kind]
    mb = MB(name, "Kitchen", 3.4)
    body = EN if kind != "hob" else "enamel_cream"
    mb.boxr((-2.0, -1.1, 0.35), (2.0, 1.2, 3.13), body)
    mb.boxr((-2.0, -0.9, 0), (2.0, 1.2, 0.4), "plinth65")
    if kind == "sink":
        counter_top(mb, -2.0, 2.0, -1.25, 1.2, hole=(-1.4, 1.4, -0.85, 0.75))
        mb.boxr((-1.42, -0.87, 2.6), (1.42, 0.77, 3.38), "steel65")                # basin box (steel)
        mb.boxr((-1.36, -0.81, 2.66), (-0.04, 0.71, 3.42), "steel65") if False else None
        mb.boxr((-1.38, -0.83, 3.3), (1.38, 0.73, 3.4), "steel65")                 # drainer rim
        mb.tube([(0, 0.95, 3.38), (0, 0.95, 4.6), (0, 0.6, 4.937), (0, 0.25, 4.6)], 0.07, "chrome65", segs=8)
        for sx in (-1, 1):
            mb.lathe([(0, 3.38), (0.12, 3.38), (0.1, 3.62), (0.2, 3.66), (0.2, 3.72), (0, 3.74)], 8, "chrome65", M=T(sx * 0.6, 0.95, 0))
        fronts = [((-1.98, 0.42), (-0.01, 3.06)), ((0.01, 0.42), (1.98, 3.06))]
        stain(mb, "lino", (0, 0, 1), (0, 0, 0), 0, 0, []) if False else None
    elif kind == "hob":
        mb.boxr((-2.0, -1.25, 3.12), (2.0, 1.2, 3.4), "enamel_cream")
        for (x, y) in ((-0.9, -0.5), (0.9, -0.5), (-0.9, 0.5), (0.9, 0.5)):
            mb.revolve([(0.18, 3.36), (0.42, 3.36), (0.42, 3.4), (0.18, 3.4)], 16, "iron_black", M=T(x, y, 0))
            mb.lathe([(0, 3.37), (0.16, 3.37), (0.16, 3.4), (0, 3.4)], 10, "chrome65", M=T(x, y, 0))
        fronts = []
        mb.boxr((-1.95, -1.17, 2.58), (1.95, -1.1, 3.08), "chrome65")                 # control strip
        for i in range(4):
            knob(mb, -1.2 + i * 0.8, -1.17, 2.83, kind="bakelite_cream", r=0.1)
        mb.boxr((-1.9, -1.17, 0.45), (1.9, -1.1, 2.5), "enamel_cream")                 # oven door
        mb.boxr((-1.3, -1.2, 1.1), (1.3, -1.15, 2.1), "glass65")
        mb.tube([(-1.5, -1.31, 2.3), (1.5, -1.31, 2.3)], 0.07, "chrome65", segs=8)
        for sx in (-1, 1):
            mb.boxr((sx * 1.45 - 0.05, -1.31, 2.25), (sx * 1.45 + 0.05, -1.1, 2.35), "chrome65")
        stain(mb, "fx_burn", (0, 0, 1), (0.9, 0.5, 3.4), 1.2, 1.2, ["enamel_cream"], op=0.8)
    else:
        counter_top(mb, -2.0, 2.0, -1.25, 1.2)
        fronts = [((-1.98, 2.5), (1.98, 3.06)), ((-1.98, 0.42), (-0.01, 2.46)), ((0.01, 0.42), (1.98, 2.46))]
    for (x0, z0), (x1, z1) in fronts:
        mb.boxr((x0 + 0.02, -1.17, z0 + 0.02), (x1 - 0.02, -1.1, z1 - 0.02), EN)
        if (z1 - z0) > 1.0:
            pull(mb, x1 - 0.35 if x0 < -0.5 else x0 + 0.35, -1.17, z1 - 0.5, kind="chrome65", w=0.5, proud=0.09)
        else:
            pull(mb, (x0 + x1) / 2, -1.17, (z0 + z1) / 2, kind="chrome65", w=0.9, proud=0.09)
    return finish(mb)


def kitchen_upper():
    mb = MB("H_KitchenUpper", "Kitchen", 2.6)
    mb.boxr((-2.0, -0.55, 0.0), (2.0, 0.75, 2.6), EN)
    for x0, x1 in ((-1.98, -0.01), (0.01, 1.98)):
        mb.boxr((x0 + 0.02, -0.62, 0.02), (x1 - 0.02, -0.55, 2.58), EN)
        pull(mb, x1 - 0.3 if x0 < -0.5 else x0 + 0.3, -0.6, 0.4, kind="chrome65", w=0.4) if False else None
        mb.boxr((x1 - 0.35 if x0 < -0.5 else x0 + 0.25, -0.7, 0.2), (x1 - 0.25 if x0 < -0.5 else x0 + 0.35, -0.6, 0.7), "chrome65")
    return finish(mb)


def range_hood():
    mb = MB("H_RangeHood", "Kitchen", 3.4)
    mb.prism([(-1.6, 0.0), (1.6, 0.0), (1.6, 0.25), (0.9, 1.0), (-0.9, 1.0), (-1.6, 0.25)], "Y", -0.9, 0.75, EN)
    mb.boxr((-0.85, -0.5, 0.95), (0.85, 0.75, 3.4), EN)
    mb.boxr((-1.5, -0.8, -0.04), (1.5, 0.65, 0.02), "steel65")
    return finish(mb)


def pantry():
    """tall gold enamel broom / pantry cupboard"""
    mb = MB("H_Pantry", "Kitchen", 8.0)
    mb.boxr((-2.0, -1.1, 0.35), (2.0, 1.2, 8.0), EN)
    mb.boxr((-2.0, -0.9, 0), (2.0, 1.2, 0.4), "plinth65")
    for x0, x1 in ((-1.98, -0.01), (0.01, 1.98)):
        for z0, z1 in ((0.42, 5.2), (5.24, 7.96)):
            mb.boxr((x0 + 0.02, -1.17, z0 + 0.02), (x1 - 0.02, -1.1, z1 - 0.02), EN)
        pull(mb, x1 - 0.3 if x0 < -0.5 else x0 + 0.3, -1.17, 4.4, kind="chrome65", w=0.7, proud=0.09)
    return finish(mb)


# --- appliances
def fridge():
    """rounded-top single-door fridge (~6.5) in white enamel with a chrome lever handle; a walnut cabinet over it to 8.
    v1 extents x -1.8..1.8, y -1.554..1.3 (pre-centre), z 0..8"""
    mb = MB("H_Fridge", "Appliances", 8.0)
    rbox(mb, (-1.8, -1.15, 0.0), (1.8, 1.3, 6.5), "enamel_white", r=0.45, segs=3)
    mb.boxr((-1.6, -1.18, 0.0), (1.6, -1.0, 0.35), "chrome65")
    rbox(mb, (-1.72, -1.3, 0.45), (1.72, -1.1, 6.3), "enamel_white", r=0.35, segs=3)     # door
    mb.boxr((-1.4, -1.32, 5.6), (1.4, -1.25, 5.75), "chrome65")                           # brand strip (no lettering)
    mb.tube([(1.3, -1.3, 3.7), (1.38, -1.5, 3.8), (1.38, -1.554 + 0.06, 4.6), (1.3, -1.3, 4.7)], 0.06, "chrome65", segs=8)
    mb.boxr((-1.8, -1.15, 6.5), (1.8, 1.3, 8.0), "walnut65")                              # cabinet over to 8
    for x0, x1 in ((-1.78, -0.01), (0.01, 1.78)):
        mb.boxr((x0, -1.22, 6.56), (x1, -1.15, 7.94), "walnut65")
        knob(mb, x1 - 0.25 if x0 < 0 else x0 + 0.25, -1.2, 6.8)
    mb.boxr((-1.25, -1.33, 4.0), (-0.45, -1.3, 5.0), "paper65")                           # the kid's drawing under a magnet
    mb.decal(G65 + "kid_rocket", (0, -1, 0), (-0.85, -1.33, 4.5), 0.78, 0.98, col=None, op=1.0, kinds=["paper65"], depth=0.05)
    mb.lathe([(0, -1.37), (0.08, -1.37), (0.08, -1.33), (0, -1.33)], 8, "phone_olive", M=T(-0.85, 0, 4.9) @ ROT(-90))
    stain(mb, "fx_blot", (0, -1, 0), (0.4, -1.3, 1.2), 1.4, 1.4, ["enamel_white"], op=0.7)
    return finish(mb)


def toaster():
    """KT_Micro becomes a toaster + bread bin (same 1.9 x 1.1 x 1.36 dressing footprint)"""
    mb = MB("H_Microwave", "Appliances", 1.1)
    rbox(mb, (-0.95, -0.65, 0), (-0.05, 0.65, 0.95), "enamel_cream", r=0.2, segs=2)      # bread bin
    mb.boxr((-0.9, -0.71, 0.2), (-0.1, -0.64, 0.7), "chrome65")
    rbox(mb, (0.1, -0.45, 0), (0.95, 0.45, 0.8), "chrome65", r=0.15, segs=2)             # toaster
    for x in (0.35, 0.7):
        mb.boxr((x - 0.05, -0.3, 0.78), (x + 0.05, 0.3, 0.82), "iron_black")
    mb.boxr((0.88, -0.1, 0.4), (0.98, 0.1, 0.5), "bakelite")
    mb.boxr((0.5, 0.6, 0.0), (0.6, 0.65, 1.1), "chrome65") if False else None
    mb.boxr((-0.01, 0.64, 1.09), (0.01, 0.65, 1.1), "enamel_cream")                     # height / depth marker inside v1 box
    return finish(mb)


def percolator():
    mb = MB("H_CoffeeMachine", "Appliances", 1.3)
    mb.lathe([(0, 0), (0.32, 0), (0.36, 0.08), (0.28, 0.7), (0.3, 1.0), (0.22, 1.12), (0.08, 1.15), (0.06, 1.3), (0, 1.3)], 16, "chrome65")
    mb.tube([(0, 0.3, 0.9), (0, 0.55, 0.85), (0, 0.6, 0.4), (0, 0.32, 0.3)], 0.05, "bakelite", segs=6)
    mb.tube([(0, -0.3, 0.55), (0, -0.55, 0.95)], 0.05, "chrome65", segs=6)
    mb.boxr((-0.45, -0.9, 0.0), (0.45, -0.6, 0.01), "chrome65")       # trivet plate (v1 depth -0.9)
    return finish(mb)


def kettle():
    """whistling kettle, cream enamel, bakelite handle"""
    mb = MB("H_Kettle", "Appliances", 0.93)
    mb.lathe([(0, 0), (0.38, 0), (0.4, 0.06), (0.36, 0.5), (0.22, 0.66), (0.08, 0.7), (0, 0.7)], 16, "enamel_cream")
    mb.tube([(0.0, -0.26, 0.6), (0.0, -0.05, 0.86), (0.0, 0.2, 0.86), (0.0, 0.32, 0.6)], 0.04, "bakelite", segs=6)
    mb.tube([(0.0, -0.32, 0.25), (0.0, -0.5, 0.55)], 0.06, "enamel_cream", segs=6)
    mb.lathe([(0, 0.53), (0.04, 0.53), (0.05, 0.6), (0, 0.6)], 6, "chrome65", M=T(0, -0.5, 0))
    return finish(mb)


def washer():
    """top-loading washer in white enamel, chrome lid hinge, a dial panel at the back"""
    mb = MB("H_WashingMachine", "Appliances", 3.0)
    rbox(mb, (-1.3, -1.2, 0), (1.3, 1.2, 2.5), "enamel_white", r=0.12, segs=2)
    mb.boxr((-1.2, -1.1, 2.49), (1.2, 0.5, 2.55), "enamel_white")              # lid
    mb.boxr((-0.3, -1.12, 2.48), (0.3, -1.05, 2.58), "chrome65")
    mb.boxr((-1.3, 0.55, 2.4), (1.3, 1.2, 3.0), "enamel_cream")                  # dial panel
    for x in (-0.7, 0.0, 0.7):
        knob(mb, x, 0.55, 2.72, kind="chrome65", r=0.1)
    mb.boxr((-1.0, -1.32, 0.3), (1.0, -1.2, 0.36), "chrome65")                  # kick strip (v1 depth -1.32)
    stain(mb, "fx_blot", (0, -1, 0), (0.5, -1.2, 0.8), 1.2, 1.2, ["enamel_white"])
    return finish(mb)


# --- bathroom
def bathtub(name="H_Bathtub", tile="tile_mint65", porcelain="ceramic_mint", atlas="Bath"):
    """built-in tub: tiled apron + ledge to 3.4 (low cover), porcelain basin inside, chrome taps (to 4.1 as v1)"""
    mb = MB(name, atlas, 3.4)
    mb.boxr((-3.5, -1.8, 0), (3.5, 1.8, 2.9), tile)                               # tiled apron (closed base)
    for (a, b) in (((-3.5, -1.8), (3.5, -1.3)), ((-3.5, 1.3), (3.5, 1.8)), ((-3.5, -1.3), (-2.9, 1.3)), ((2.9, -1.3), (3.5, 1.3))):
        mb.boxr((a[0], a[1], 2.88), (b[0], b[1], 3.4), tile)                      # ledge to 3.4
    sq_lathe(mb, [(0, 2.1), (0.8, 2.1), (0.95, 3.0), (1.0, 3.39), (0.97, 3.39), (0.9, 3.0), (0.78, 2.18), (0, 2.18)], 2.95, 1.35, porcelain, n=4.0, segs=40)
    mb.tube([(-3.25, 0.0, 3.4), (-3.25, 0.0, 3.85), (-3.15, 0.0, 4.05), (-2.95, 0.0, 4.05), (-2.85, 0.0, 3.9)], 0.07, "chrome65", segs=8)
    for sy in (-1, 1):
        mb.lathe([(0, 3.4), (0.06, 3.4), (0.06, 3.62), (0, 3.62)], 6, "chrome65", M=T(-3.2, sy * 0.55, 0))
        for k in range(2):
            a = k * math.pi / 2
            mb.tube([(-3.2 - 0.18 * math.cos(a), sy * 0.55 - 0.18 * math.sin(a), 3.62), (-3.2 + 0.18 * math.cos(a), sy * 0.55 + 0.18 * math.sin(a), 3.62)], 0.035, "chrome65", segs=5)
    mb.lathe([(0, 4.05), (0.06, 4.05), (0.069, 4.119), (0, 4.119)], 6, "chrome65", M=T(-3.05, 0, 0))   # v1 tap top 4.119
    stain(mb, "fx_blot", (0, 0, 1), (0.8, 0.0, 2.18), 2.0, 1.3, [porcelain], op=0.8)
    return finish(mb)


def toilet(name="H_Toilet", porcelain="ceramic_mint"):
    mb = MB(name, "Bath", 2.64)
    sq_lathe(mb, [(0, 0), (0.62, 0), (0.7, 0.9), (0.96, 1.25), (1.0, 1.42), (0.86, 1.42), (0.6, 1.0), (0, 1.0)], 0.75, 1.0, porcelain, n=2.6, segs=28,
             M=T(0, -0.2, 0))
    rbox(mb, (-0.85, -1.25, 1.4), (0.85, 0.85, 1.52), porcelain, r=0.05)
    rbox(mb, (-0.95, 0.65, 0.9), (0.95, 1.25, 2.64), porcelain, r=0.08)
    mb.boxr((0.4, 0.6, 2.2), (0.75, 0.66, 2.3), "chrome65")
    return finish(mb)


def vanity(name="H_Vanity", lam="enamel_mint", porcelain="ceramic_mint"):
    """small 1960s vanity (laminate doors, chrome legs at the front), basin set in, cross taps; hangs at +Y 0.9 as v1"""
    mb = MB(name, "Bath", 4.04)
    mb.boxr((-2.0, -0.9, 1.0), (2.0, 0.9, 2.62), lam)
    counter_top(mb, -2.05, 2.05, -1.02, 0.9, z0=2.6, z1=2.82, hole=(-0.8, 0.8, -0.6, 0.4))
    mb.lathe([(0, 2.3), (0.7, 2.3), (0.78, 2.82), (0.74, 2.82), (0.66, 2.36), (0, 2.36)], 18, porcelain, M=T(0, -0.1, 0))
    for x0, x1 in ((-1.98, -0.01), (0.01, 1.98)):
        mb.boxr((x0 + 0.02, -0.97, 1.04), (x1 - 0.02, -0.9, 2.56), lam)
        knob(mb, x1 - 0.25 if x0 < 0 else x0 + 0.25, -0.97, 2.2, kind="chrome65", depth=0.05)
    for sx in (-1, 1):
        mb.tube([(sx * 1.8, -0.7, 1.0), (sx * 1.8, -0.7, 1.02)], 0.05, "chrome65", segs=6) if False else None
        mb.lathe([(0, 2.82), (0.05, 2.82), (0.05, 3.1), (0, 3.1)], 6, "chrome65", M=T(sx * 0.6, 0.65, 0))
    mb.tube([(0, 0.65, 2.82), (0, 0.65, 3.3), (0, 0.3, 3.4), (0, 0.15, 3.2)], 0.05, "chrome65", segs=6)
    mb.boxr((-0.01, 0.89, 4.03), (0.01, 0.9, 4.043), "chrome65")       # v1 height marker (its tap rose to 4.04)
    return finish(mb)


def medicine_cabinet():
    """H_Mirror becomes a chrome-framed medicine cabinet (3 x 4 x 0.19, back on y = 0)"""
    mb = MB("H_Mirror", "Bath", 4.0)
    mb.boxr((-1.5, -0.14, 0.0), (1.5, 0.0, 4.0), "chrome65")
    mb.boxr((-1.38, -0.19, 0.12), (1.38, -0.13, 3.88), "glass65")
    mb.boxr((-1.5, -0.19, 0.0), (1.5, -0.13, 0.12), "chrome65")
    mb.boxr((-1.5, -0.19, 3.88), (1.5, -0.13, 4.0), "chrome65")
    stain(mb, "fx_blot", (0, -1, 0), (0.6, -0.19, 1.2), 1.4, 1.4, ["glass65"], op=0.5)
    return finish(mb)


def shower_set():
    mb = MB("H_ShowerSet", "Bath", 6.66)
    mb.tube([(0, 0.0, 6.6), (0, -0.9, 6.5)], 0.05, "chrome65", segs=8)
    mb.lathe([(0, 0), (0.3, 0), (0.42, 0.1), (0.35, 0.16), (0, 0.18)], 16, "chrome65", M=T(0, -1.05, 6.3))
    for x in (-0.35, 0.35):
        mb.lathe([(0, 0), (0.06, 0), (0.06, 0.2), (0, 0.2)], 6, "chrome65", M=T(x, 0.0, 3.6) @ ROT(90))
        for k in range(2):
            a = k * math.pi / 2
            mb.tube([(x - 0.17 * math.cos(a), -0.2, 3.6 - 0.17 * math.sin(a)), (x + 0.17 * math.cos(a), -0.2, 3.6 + 0.17 * math.sin(a))], 0.03, "chrome65", segs=5)
    mb.boxr((-0.55, -1.6, 3.35), (-0.54, -1.59, 3.36), "chrome65"); mb.boxr((0.54, -1.6, 6.65), (0.55, -1.59, 6.66), "chrome65")
    return finish(mb)


def shower_curtain():
    """H_ShowerGlass becomes a pale-yellow vinyl shower curtain on a chrome rod (same 3.12 x 6.6 x 0.2 box); the
    H_ShowerGlassProfile part is the rod's wall flange"""
    mb = MB("H_ShowerGlass", "Bath", 6.6)
    n = 16
    pts = []
    for i in range(n + 1):
        x = -1.5 + 3.0 * i / n
        pts.append((x, 0.055 * math.sin(i * math.pi / 2)))
    prof_b = [(x, y - 0.025) for x, y in pts]
    prof_f = [(x, y + 0.025) for x, y in reversed(pts)]
    poly = prof_b + prof_f
    mb.prism(poly, "Z", 0.35, 6.25, "spread")
    mb.decal(FX + "fab_curtain", (0, -1, 0), (0, -0.1, 3.3), 3.0, 5.9, col=None, op=1.0, kinds=["spread"], depth=0.3)
    mb.decal(FX + "fab_curtain", (0, 1, 0), (0, 0.1, 3.3), 3.0, 5.9, col=None, op=1.0, kinds=["spread"], depth=0.3)
    mb.tube([(-1.5, 0.0, 6.42), (1.5, 0.0, 6.42)], 0.05, "chrome65", segs=8)
    for i in range(9):
        x = -1.45 + 2.9 * i / 8
        mb.revolve([(0.06, -0.012), (0.08, -0.012), (0.08, 0.012), (0.06, 0.012)], 8, "chrome65", M=T(x, 0, 6.42) @ ROT(90, "Y"))
    mb.tube([(-1.45, 0.0, 6.3), (-1.45, 0.0, 6.36)], 0.02, "chrome65", segs=4) if False else None
    mb.boxr((-1.5, -0.1, 0.0), (-1.49, 0.1, 0.01), "chrome65"); mb.boxr((1.49, -0.01, 6.59), (1.5, 0.01, 6.6), "chrome65")
    return finish(mb)


def shower_flange():
    mb = MB("H_ShowerGlassProfile", "Bath", 6.6)
    mb.lathe([(0, 0), (0.12, 0), (0.12, 0.12), (0, 0.12)], 10, "chrome65", M=T(1.5, 0, 6.42) @ ROT(90, "Y"))
    mb.boxr((1.6, -0.1, 0.0), (1.62, 0.1, 0.02), "chrome65")
    return finish(mb)


def towel_rail():
    mb = MB("H_TowelRail", "Bath", 2.72)
    for x in (-1.0, 1.0):
        mb.tube([(x, 0.0, 2.6), (x, -0.35, 2.6)], 0.05, "chrome65", segs=6)
    mb.tube([(-1.1, -0.35, 2.6), (1.1, -0.35, 2.6)], 0.06, "chrome65", segs=6)
    mb.boxr((-0.8, -0.48, 1.4), (0.8, -0.38, 2.68), "linen_old")
    mb.boxr((-0.8, -0.32, 1.6), (0.8, -0.22, 2.68), "linen_old")
    mb.boxr((-0.8, -0.49, 2.6), (0.8, -0.21, 2.72), "linen_old")
    stain(mb, "fx_blot", (0, -1, 0), (0.2, -0.49, 1.9), 1.0, 1.0, ["linen_old"])
    return finish(mb)


# =========================================================================================================== TALL COVER
BK = ["book65_olive", "book65_brown", "book65_cream", "book65_mustard", "book65_grey", "book65_rust", "book65_green"]


def books_row(mb, x0, x1, z0, zmax, yback, depth, rng, facing=-1, lean_end=True):
    x = x0
    while x < x1 - 0.2:
        w = rng.uniform(0.16, 0.32)
        if x + w > x1 - 0.02:
            break
        h = min(rng.uniform(0.95, 1.45), zmax - z0 - 0.08)
        d = rng.uniform(0.85, 1.0) * depth
        ya, yb = (yback - d, yback) if facing < 0 else (yback, yback + d)
        mb.boxr((x + 0.005, ya, z0 - 0.03), (x + w - 0.005, yb, z0 + h), rng.choice(BK))
        x += w


def bookcase(name="H_Bookcase", wood="walnut65", style="glass", atlas="Storage"):
    """6 x 1.6 x 8 tall cover: closed cupboard base to 2.6, shelves above. styles: glass (glass-front doors: frames here,
    the panes as a separate Plain glass part), hutch (china hutch: plates on display), open (maple, BR2)"""
    mb = MB(name, atlas, 8.0)
    mb.boxr((-3.0, -0.8, 0.0), (-2.78, 0.8, 8.0), wood)
    mb.boxr((2.78, -0.8, 0.0), (3.0, 0.8, 8.0), wood)
    mb.boxr((-2.82, -0.8, 7.7), (2.82, 0.8, 8.0), wood)
    mb.boxr((-2.82, -0.72, 0.0), (2.82, 0.75, 2.6), wood)                           # closed base
    mb.boxr((-2.82, 0.6, 2.55), (2.82, 0.8, 7.75), wood)                             # solid back
    mb.prism([(-2.82, 0), (2.82, 0), (2.82, 0.3), (2.5, 0.3), (2.3, 0.12), (-2.3, 0.12), (-2.5, 0.3), (-2.82, 0.3)], "Y", -0.8, -0.72, wood)
    for x0, x1 in ((-2.78, -0.01), (0.01, 2.78)):
        mb.boxr((x0, -0.78, 0.32), (x1, -0.72, 2.5), wood)
        knob(mb, x1 - 0.3 if x0 < 0 else x0 + 0.3, -0.8, 1.9) if False else None
        mb.boxr((x1 - 0.32 if x0 < 0 else x0 + 0.22, -0.8, 1.6), (x1 - 0.22 if x0 < 0 else x0 + 0.32, -0.77, 2.2), "brass")
    mb.boxr((-2.82, -0.8, 2.5), (2.82, 0.6, 2.62), wood)
    zs = [2.62, 4.35, 6.05, 7.7]
    for z in zs[1:-1]:
        mb.boxr((-2.82, -0.7, z - 0.12), (2.82, 0.6, z), wood)
    rng = random.Random(sum(map(ord, name)))
    for si, (z0, z1) in enumerate(zip(zs, zs[1:])):
        if style == "hutch":
            for i in range(4):     # plates standing on their rim against the back, a cup in front
                x = -2.1 + i * 1.4
                mb.lathe([(0, -0.03), (0.6, -0.03), (0.68, 0.04), (0.64, 0.05), (0.44, 0.0), (0, 0.0)], 18, "china",
                         M=T(x, 0.45, z0 + 0.7) @ ROT(-80))
                mb.lathe([(0, 0), (0.16, 0), (0.2, 0.3), (0.18, 0.3), (0.14, 0.03), (0, 0.03)], 10, "china", M=T(x + 0.3, -0.25, z0))
        else:
            books_row(mb, -2.76, 2.76 if si != 1 else 0.4, z0, z1 - 0.12, 0.6, 1.1, rng)
            if si == 1:
                mb.lathe([(0, z0), (0.3, z0), (0.3, z0 + 0.1), (0.08, z0 + 0.12), (0.08, z0 + 0.4), (0.36, z0 + 0.4), (0.36, z0 + 0.9), (0, z0 + 0.9)], 10,
                         "bakelite", M=T(1.5, 0.1, 0))                         # a clock radio / mantel clock block
    if style in ("glass", "hutch"):
        for x0, x1 in ((-2.78, -0.01), (0.01, 2.78)):    # glazed door frames (panes in the _Glass part)
            for (a, b, c, d) in ((x0, x0 + 0.14, 2.62, 7.7), (x1 - 0.14, x1, 2.62, 7.7), (x0, x1, 2.62, 2.76), (x0, x1, 7.56, 7.7)):
                mb.boxr((a, -0.78, c), (b, -0.72, d), wood)
            mb.boxr((x0 + 0.14, -0.77, 5.12), (x1 - 0.14, -0.73, 5.22), wood)
            mb.boxr((x1 - 0.3 if x0 < 0 else x0 + 0.22, -0.8, 4.6), (x1 - 0.22 if x0 < 0 else x0 + 0.3, -0.77, 5.0), "brass")
    stain(mb, "fx_rings", (0, 0, 1), (1.0, 0.0, 2.62), 0.8, 0.8, [wood])
    obs = [finish(mb)]
    if style in ("glass", "hutch"):
        gl = MB(name + "_Glass", "Plain:Glass", 8.0)
        for x0, x1 in ((-2.78, -0.01), (0.01, 2.78)):
            gl.boxr((x0 + 0.1, -0.76, 2.72), (x1 - 0.1, -0.73, 7.6), "glass65")
        g = finish(gl); g["atlas"] = "Plain:H_Glass"
        obs.append(g)
    return obs


def wardrobe(name="H_Wardrobe", wood="walnut65", style="walnut", atlas="Storage"):
    """6 x 2.5 x 8 tall cover. styles: walnut (brass pulls, shaped plinth), lockers (painted green coat lockers, slatted
    vents, chalked numbers), cream (painted kid's wardrobe)"""
    mb = MB(name, atlas, 8.0)
    mb.boxr((-3.0, -1.1, 0.35), (3.0, 1.2, 8.0), wood)
    mb.prism([(-3.0, 0), (3.0, 0), (3.0, 0.4), (2.7, 0.4), (2.5, 0.16), (-2.5, 0.16), (-2.7, 0.4), (-3.0, 0.4)], "Y", -1.1, 1.2, wood)
    if style == "lockers":
        xs = [-2.98, -1.0, 1.0, 2.98]
        for i, (x0, x1) in enumerate(zip(xs, xs[1:])):
            mb.boxr((x0 + 0.03, -1.17, 0.45), (x1 - 0.03, -1.1, 7.9), wood)
            for k in range(5):
                z = 6.6 + k * 0.2
                mb.boxr((x0 + 0.4, -1.2, z), (x1 - 0.4, -1.15, z + 0.08), "iron_black")
            mb.boxr((x1 - 0.32, -1.3, 3.6), (x1 - 0.2, -1.15, 4.4), "chrome65")
            mb.decal(FX + f"dummy_num_{i + 1}", (0, -1, 0), ((x0 + x1) / 2, -1.17, 5.6), 0.9, 0.9, col=(232, 230, 220), op=0.8, kinds=[wood], depth=0.1)
    else:
        xs = [-2.98, -1.0, 1.0, 2.98]
        for i, (x0, x1) in enumerate(zip(xs, xs[1:])):
            mb.boxr((x0 + 0.03, -1.17, 0.45), (x1 - 0.03, -1.1, 7.9), wood)
            mb.boxr((x0 + 0.25, -1.19, 0.75), (x1 - 0.25, -1.16, 7.6), wood)          # raised panel
            hx = x1 - 0.25 if i != 2 else x0 + 0.25
            mb.boxr((hx - 0.05, -1.3, 3.5), (hx + 0.05, -1.17, 4.6), "brass" if style == "walnut" else "chrome65")
    stain(mb, "fx_blot", (0, -1, 0), (-1.8, -1.19, 1.4), 1.2, 1.2, [wood], op=0.6)
    return finish(mb)


def tall_cabinet(name="H_TallCabinet", wood="paint_cream", style="linen", atlas="Storage"):
    """3 x 2.12 x 8 tall cover. linen = painted linen press (cream); halltree = walnut coat cupboard with a mirror panel,
    a coat and a hat on hooks"""
    mb = MB(name, atlas, 8.0)
    mb.boxr((-1.5, -0.95, 0.35), (1.5, 1.0, 8.0), wood)
    mb.prism([(-1.5, 0), (1.5, 0), (1.5, 0.4), (1.2, 0.4), (1.0, 0.16), (-1.0, 0.16), (-1.2, 0.4), (-1.5, 0.4)], "Y", -0.95, 1.0, wood)
    if style == "halltree":
        mb.boxr((-1.45, -1.0, 0.45), (1.45, -0.95, 3.4), wood)
        mb.boxr((-1.1, -1.03, 3.7), (1.1, -0.98, 6.3), "glass65")                   # mirror panel
        for x in (-1.0, 0.0, 1.0):
            mb.tube([(x, -1.0, 7.0), (x, -1.06, 7.1)], 0.04, "brass", segs=6)
        mb.prism([(-0.9, 0), (0.1, 0), (0.25, -2.8), (-1.05, -2.8)], "Y", -1.06, -0.98, "cloth_suit", grain=None) if False else None
        mb.boxr((-1.3, -1.06, 4.1), (-0.3, -1.0, 7.05), "cloth_suit")                # coat hanging on the hook
        mb.boxr((0.4, -1.08, 5.2), (0.8, -1.0, 7.05), "cloth_cardigan")              # a scarf on the second hook
        knob(mb, 1.1, -1.0, 2.0, depth=0.12)
    else:
        for z0, z1 in ((0.45, 3.9), (3.95, 7.9)):
            mb.boxr((-1.45, -1.01, z0), (1.45, -0.95, z1), wood)
            mb.boxr((-1.2, -1.03, z0 + 0.3), (1.2, -1.0, z1 - 0.3), wood)
        knob(mb, 1.1, -1.01, 3.6, kind="chrome65", depth=0.11)
        knob(mb, 1.1, -1.01, 4.3, kind="chrome65", depth=0.11)
    return finish(mb)


def shelf_wall():
    """12 x 2 x 8 walnut built-in room divider dressed on both faces (team A's spawn wall): books, records, a globe, a
    ceramic horse; solid spine"""
    mb = MB("H_ShelfWall", "ShelfWall", 8.0)
    bk = MB("H_ShelfWall_Books", "ShelfBooks", 8.0)
    H = 8.0
    for (a, b) in ((-6.0, -5.78), (-2.21, -1.99), (1.99, 2.21), (5.78, 6.0)):
        mb.boxr((a, -1.0, 0.0), (b, 1.0, H), "walnut65")
    mb.boxr((-5.8, -1.0, 7.78), (5.8, 1.0, 8.0), "walnut65")
    mb.boxr((-5.8, -1.0, 0.0), (5.8, 1.0, 2.3), "walnut65")                       # closed cupboard base both faces
    for face in (-1, 1):
        for bx0, bx1 in ((-5.78, -2.21), (-1.99, 1.99), (2.21, 5.78)):
            for x0, x1 in ((bx0, (bx0 + bx1) / 2 - 0.01), ((bx0 + bx1) / 2 + 0.01, bx1)):
                y0, y1 = (-1.0, -0.96) if face < 0 else (0.96, 1.0)
                mb.boxr((x0 + 0.02, y0, 0.3), (x1 - 0.02, y1, 2.2), "walnut_slat65", grain=2)
    mb.boxr((-5.82, -0.1, 2.25), (5.82, 0.1, 7.8), "walnut_trim")                # the spine
    rng = random.Random(21)
    zs = [2.3, 4.15, 6.0, 7.78]
    for z in zs[1:-1]:
        mb.boxr((-5.8, -1.0, z - 0.14), (5.8, 1.0, z), "walnut65")
    bays = [(-5.78, -2.21), (-1.99, 1.99), (2.21, 5.78)]
    for zi, (z0, z1) in enumerate(zip(zs, zs[1:])):
        for bi, (x0, x1) in enumerate(bays):
            for face in (-1, 1):
                k = (zi * 3 + bi + (face > 0)) % 4
                cy = 0.5 * face
                if k == 1:       # a globe on a stand + a lying stack
                    cx = (x0 + x1) / 2 + 0.7
                    bk.lathe([(0, z0), (0.3, z0), (0.3, z0 + 0.08), (0.05, z0 + 0.12), (0.05, z0 + 0.35), (0, z0 + 0.35)], 10, "brass", M=T(cx, cy, 0))
                    ellipsoid(bk, (cx, cy, z0 + 0.8), (0.45, 0.45, 0.45), "book65_cream", segs=14, rings=8)
                    for j, kk in enumerate(rng.sample(BK, 2)):
                        bk.boxr((x0 + 0.1, cy - 0.38, z0 - 0.03 + j * 0.17), (x0 + 1.2, cy + 0.38, z0 + 0.14 + j * 0.17), kk)
                elif k == 2:     # records standing in a row + a ceramic horse
                    for j in range(14):
                        x = x0 + 0.15 + j * 0.09
                        bk.boxr((x, cy - 0.4, z0), (x + 0.06, cy + 0.4, z0 + 1.0), rng.choice(["record_black", "book65_cream", "book65_mustard"]))
                    hx = x1 - 0.9
                    ellipsoid(bk, (hx, cy, z0 + 0.62), (0.45, 0.16, 0.2), "ceramic65", segs=10, rings=6)
                    bk.tube([(hx + 0.35, cy, z0 + 0.7), (hx + 0.55, cy, z0 + 1.05)], 0.09, "ceramic65", segs=6)
                    for dx in (-0.3, 0.3):
                        bk.tube([(hx + dx, cy, z0 + 0.5), (hx + dx, cy, z0)], 0.05, "ceramic65", segs=5)
                else:
                    books_row(bk, x0 + 0.02, (x1 - 0.02) if k != 3 else (x0 + x1) / 2, z0, z1 - 0.14, 0.12 * face, 0.85, rng, facing=face)
    return [finish(mb), finish(bk)]


def oven_wall():
    """12 x 2 x 8 kitchen bank (team B's spawn wall): built-in twin wall ovens in brushed steel set in gold enamel on -Y,
    gold cupboard doors on +Y"""
    mb = MB("H_OvenWall", "Storage3", 8.0)
    mb.boxr((-6.0, -0.83, 0.38), (6.0, 0.83, 8.0), EN)
    mb.boxr((-5.85, -0.7, 0.0), (5.85, 0.7, 0.42), "plinth65")
    cols = [-6.0, -3.0, 0.0, 3.0, 6.0]
    for face in (-1, 1):
        yf0, yf1 = (-0.9, -0.83) if face < 0 else (0.83, 0.9)
        for i, (x0, x1) in enumerate(zip(cols, cols[1:])):
            if face < 0 and i == 1:
                mb.boxr((x0 + 0.02, yf0, 0.44), (x1 - 0.02, yf1, 1.6), EN)
                for (z0, z1) in ((1.65, 3.55), (3.6, 5.5)):
                    mb.boxr((x0 + 0.04, -0.9, z0), (x1 - 0.04, -0.83, z1), "steel65")
                    mb.boxr((x0 + 0.35, -0.93, z0 + 0.35), (x1 - 0.35, -0.88, z1 - 0.6), "glass65")
                    mb.tube([(x0 + 0.35, -0.95 - 0.0, z1 - 0.28), (x1 - 0.35, -0.95, z1 - 0.28)], 0.045, "chrome65", segs=8)
                    for xx in (x0 + 0.37, x1 - 0.37):
                        mb.boxr((xx - 0.04, -0.96, z1 - 0.33), (xx + 0.04, -0.88, z1 - 0.23), "chrome65")
                mb.boxr((x0 + 0.02, yf0, 5.55), (x1 - 0.02, yf1, 7.96), EN)
                stain(mb, "fx_burn", (0, -1, 0), ((x0 + x1) / 2, -0.9, 5.2), 1.6, 1.0, ["steel65"], op=0.7)
                continue
            for (z0, z1) in ((0.44, 4.7), (4.74, 7.96)):
                mb.boxr((x0 + 0.02, yf0, z0), (x1 - 0.02, yf1, z1), EN)
            hx = x1 - 0.3 if i % 2 == 0 else x0 + 0.3
            pull(mb, hx, yf0 if face < 0 else yf1, 4.2, kind="chrome65", w=0.6, facing=face) if False else None
            yh0, yh1 = (-0.993, -0.9) if face < 0 else (0.9, 0.993)
            mb.boxr((hx - 0.05, yh0, 3.8), (hx + 0.05, yh1, 5.4), "chrome65")
    return finish(mb)


def spindle_screen():
    """H_SlatScreen becomes a spindle room divider: turned walnut spindles both faces over a solid core panel, on a low
    walnut cupboard base (tall cover); v1 extents y -1.02..1.02"""
    mb = MB("H_SlatScreen", "Storage3", 8.0)
    mb.boxr((-3.0, -0.96, 0.3), (3.0, 0.96, 2.4), "walnut65")
    mb.boxr((-2.9, -0.85, 0.0), (2.9, 0.85, 0.35), "plinth65")
    mb.boxr((-3.0, -1.0, 2.38), (3.0, 1.0, 2.55), "walnut65")
    mb.boxr((-2.9, -0.15, 2.5), (2.9, 0.15, 7.9), "paint_cream")                     # solid core panel
    n = 9
    for i in range(n):
        x = -2.75 + 5.5 * i / (n - 1)
        for face in (-1, 1):
            y = 0.55 * face
            mb.lathe([(0, 2.55), (0.16, 2.55), (0.16, 2.8), (0.1, 3.0), (0.18, 3.6), (0.08, 4.4), (0.17, 5.2), (0.08, 6.0), (0.18, 6.8),
                      (0.1, 7.5), (0.16, 7.65), (0.16, 7.85), (0, 7.85)], 8, "walnut65", M=T(x, y, 0))
    mb.boxr((-3.0, -1.0, 7.85), (3.0, 1.0, 8.0), "walnut65")
    for x0 in (-2.95, 0.02):
        for y0, y1 in ((-1.02, -0.96), (0.96, 1.02)):
            mb.boxr((x0, y0, 0.36), (x0 + 2.93, y1, 2.34), "walnut65")
    return finish(mb)


def headboard_wall():
    """14 x 1.5 x 8: walnut panelled bed wall, a padded mustard headboard section on -Y, two built-in reading lamps"""
    mb = MB("H_HeadboardWall", "Storage4", 8.0)
    mb.boxr((-7.0, -0.45, 0.0), (7.0, 0.75, 8.0), "walnut65")
    for i in range(7):
        x0 = -7.0 + 2.0 * i
        mb.boxr((x0 + 0.05, -0.5, 4.2), (x0 + 1.95, -0.45, 7.9), "walnut_slat65", grain=2)
    for i in range(6):
        x0 = -4.5 + 1.5 * i
        rbox(mb, (x0 + 0.03, -0.75, 1.3), (x0 + 1.47, -0.4, 4.0), "tweed_mustard", r=0.15, segs=2)
        mb.lathe([(0, 0), (0.06, 0), (0.05, 0.05), (0, 0.06)], 6, "walnut65", M=T(x0 + 0.75, -0.69, 2.65) @ ROT(90))
    mb.boxr((-4.6, -0.6, 0.0), (4.6, -0.45, 1.35), "walnut65")
    for sx in (-1, 1):   # reading lamps: brass cans on short arms
        mb.tube([(sx * 5.8, -0.45, 4.8), (sx * 5.8, -0.55, 4.8)], 0.04, "brass", segs=6)
        mb.lathe([(0, 0), (0.18, 0), (0.15, 0.4), (0.0, 0.42)], 10, "brass", M=T(sx * 5.8, -0.56, 4.85) @ ROT(180))
    stain(mb, "fx_blot", (0, -1, 0), (-2.0, -0.75, 3.2), 1.4, 1.4, ["tweed_mustard"], op=0.6)
    return finish(mb)


def kitchen_bench():
    """diner booth: mustard-and-cream vinyl, chrome trim, closed base; boxes back y 0.5..1.75 to 3.4, seat 1.95"""
    mb = MB("H_KitchenBench", "Storage2", 3.4)
    mb.boxr((-5.0, -1.6, 0.0), (5.0, 1.75, 1.55), "vinyl_cream")                    # closed base
    mb.boxr((-5.0, -1.65, 1.45), (5.0, 1.75, 1.55), "chrome65")
    rbox(mb, (-4.98, -1.75, 1.5), (4.98, 0.55, 1.95), "vinyl_mustard", r=0.15)
    mb.boxr((-5.0, 1.1, 1.5), (5.0, 1.75, 3.4), "vinyl_cream")
    for i in range(6):     # channel-tufted back
        x0 = -4.95 + i * 1.65
        rbox(mb, (x0 + 0.02, 0.55, 1.9), (x0 + 1.63, 1.15, 3.3), "vinyl_mustard", r=0.2, segs=2)
    mb.boxr((-5.0, 1.05, 3.3), (5.0, 1.75, 3.4), "chrome65")
    stain(mb, "fx_tear", (0, 0, 1), (1.8, -0.6, 1.95), 1.0, 0.8, ["vinyl_mustard"])
    return finish(mb)


def hall_bench(name, W, style):
    """W x 2 x 3.4, seat faces -Y; boxes back y 0.65..1 to 3.4, seat 1.65. style phone = gossip / telephone bench (walnut
    frame, olive vinyl seat, closed front); slat = slatted pine mudroom bench, closed board-and-batten front (fix65)"""
    mb = MB(name, "Storage2", 3.4)
    if style == "phone":
        mb.boxr((-W / 2, -1.0, 0.0), (W / 2, 0.95, 1.3), "walnut65")
        rbox(mb, (-W / 2 + 0.05, -1.0, 1.25), (W / 2 - 0.05, 0.65, 1.65), "vinyl_olive", r=0.12)
        mb.boxr((-W / 2, 0.65, 1.25), (W / 2, 1.0, 3.4), "walnut65")
        rbox(mb, (-W / 2 + 0.15, 0.6, 1.7), (W / 2 - 0.15, 0.72, 3.1), "vinyl_olive", r=0.06, segs=1)
        mb.boxr((-W / 2 + 0.1, -1.0, 0.25), (W / 2 - 0.1, -0.96, 1.15), "walnut_slat65", grain=2)
    else:
        mb.boxr((-W / 2, -1.0, 1.45), (W / 2, 0.65, 1.65), "pine65")
        for sx in (-1, 1):
            mb.boxr((sx * (W / 2 - 0.15) - 0.15, -1.0, 0.0), (sx * (W / 2 - 0.15) + 0.15, 1.0, 1.5), "pine65")
        mb.boxr((-W / 2 + 0.3, 0.75, 0.0), (W / 2 - 0.3, 1.0, 1.5), "pine65")      # kick board at the back (closed base)
        mb.boxr((-W / 2 + 0.25, -0.95, 0.0), (W / 2 - 0.25, -0.85, 1.5), "pine65")  # front panel (fix65: closed base)
        for x in (-W / 6, W / 6):                                                     # battens on the front panel
            mb.boxr((x - 0.12, -0.99, 0.05), (x + 0.12, -0.9, 1.4), "pine65")
        n = 6
        for i in range(n):
            z0 = 1.7 + i * 0.28
            mb.boxr((-W / 2 + 0.1, 0.7, z0), (W / 2 - 0.1, 1.0, z0 + 0.22), "pine65")
        mb.boxr((-W / 2 + 0.1, 0.92, 1.6), (W / 2 - 0.1, 1.0, 3.4), "pine65")     # solid backer
        mb.boxr((-W / 2, 0.65, 3.25), (W / 2, 1.0, 3.4), "pine65")
    return finish(mb)


def planter():
    """3 x 3 x 3.4 brick planter box with a concrete cap course (low cover) + a rubber plant above (art)"""
    mb = MB("H_Planter", "Plants", 3.4)
    mb.boxr((-1.45, -1.45, 0.0), (1.45, 1.45, 3.15), "brick", grain=0)
    for z in np.arange(0.0, 3.1, 0.33) if False else []:
        pass
    mb.boxr((-1.5, -1.5, 3.1), (1.5, 1.5, 3.4), "stone65")
    mb.boxr((-1.3, -1.3, 3.38), (1.3, 1.3, 3.4), "soil65") if False else None
    tr = MB("H_Planter_Tree", "Plants", 8.954)
    rng = random.Random(8)
    tr.tube([(0, 0, 3.2), (0.1, 0.05, 6.0), (0.05, 0.1, 8.6)], 0.09, "stem", segs=6)
    for i in range(30):
        t = 0.3 + 0.7 * i / 29
        p = Vector((0.08 * t, 0.07 * t, 3.4 + 5.2 * t))
        ang = rng.uniform(0, 2 * math.pi)
        dirv = Vector((math.cos(ang), math.sin(ang), rng.uniform(0.0, 0.5)))
        leaf(tr, p, dirv, rng.uniform(0.9, 1.2), rng.uniform(0.45, 0.6), rng.choice(["leaf65", "leaf65", "leaf65_dry"]), droop=0.2, thick=0.025)
    tr.boxr((-0.01, -0.01, 8.944), (0.01, 0.01, 8.954), "stem")
    return [finish(mb), finish(tr)]


def display_column():
    """3 x 3 x 8 fieldstone-clad column with a walnut-lined niche on -Y and +Y (a vase, a mantel clock)"""
    mb = MB("H_DisplayColumn", "Storage4", 8.0)
    mb.boxr((-1.5, -1.5, 0.0), (1.5, 1.5, 3.4), "stone65")
    mb.boxr((-1.5, -1.5, 6.0), (1.5, 1.5, 8.0), "stone65")
    mb.boxr((-1.5, -1.5, 3.35), (-1.0, 1.5, 6.05), "stone65")
    mb.boxr((1.0, -1.5, 3.35), (1.5, 1.5, 6.05), "stone65")
    mb.boxr((-1.02, -0.5, 3.35), (1.02, 0.5, 6.05), "walnut65")
    mb.lathe([(0, 3.4), (0.18, 3.4), (0.3, 3.8), (0.22, 4.4), (0.1, 4.6), (0.0, 4.55)], 14, "ceramic_olive", M=T(0.2, -1.0, 0))
    mb.boxr((-0.5, 0.7, 3.4), (0.5, 1.3, 4.3), "walnut65")
    mb.lathe([(0, 0), (0.3, 0), (0.3, 0.04), (0, 0.05)], 14, "brass", M=T(0, 0.68, 3.95) @ ROT(90))
    return finish(mb)


# =========================================================================================================== DRESSING
def floor_lamp():
    """tripod floor lamp with a drum shade (PointLight at z 5.3 as v1)"""
    body = MB("H_FloorLamp", "Decor", 6.0)
    for i in range(3):
        a = 2 * math.pi * i / 3
        body.tube([(0.1 * math.cos(a), 0.1 * math.sin(a), 3.0), (0.9 * math.cos(a), 0.9 * math.sin(a), 0.0)], 0.05, "walnut65", segs=6)
    body.lathe([(0, 2.9), (0.08, 2.9), (0.04, 3.1), (0.035, 4.9), (0, 4.9)], 8, "brass")
    shade = MB("H_FloorLamp_Shade", "Decor", 6.0)
    shade.lathe([(0, 4.75), (0.95, 4.75), (0.95, 6.0), (0, 6.0)], 24, "shade65")
    return [finish(body), finish(shade)]


def table_lamp():
    """ceramic ginger-jar table lamp with a pleated shade"""
    body = MB("H_TableLamp", "Decor", 2.0)
    body.lathe([(0, 0), (0.3, 0), (0.42, 0.3), (0.44, 0.65), (0.3, 0.95), (0.08, 1.05), (0.04, 1.3), (0, 1.3)], 16, "ceramic_olive")
    shade = MB("H_TableLamp_Shade", "Decor", 2.0)
    pts = [(0, 1.2)]
    for i in range(25):
        a = 2 * math.pi * i / 24
    shade.lathe([(0, 1.2), (0.62, 1.2), (0.5, 2.0), (0, 2.0)], 24, "shade65",
                deform=lambda v: Vector((v.x * (1 + 0.04 * math.cos(12 * math.atan2(v.y, v.x))), v.y * (1 + 0.04 * math.cos(12 * math.atan2(v.y, v.x))), v.z)))
    return [finish(body), finish(shade)]


def pendant_globe():
    """opal glass globe pendant on a brass chain (origin = ceiling point, 4.0 drop as v1); the globe glows"""
    body = MB("H_PendantLamp", "Decor", 4.0)
    body.lathe([(0, -0.05), (0.3, -0.05), (0.3, 0.05), (0, 0.05)], 12, "brass")
    for i in range(14):
        z = -0.15 - i * 0.2
        body.revolve([(0.04, -0.08), (0.06, -0.08), (0.06, 0.08), (0.04, 0.08)], 6, "brass", M=T(0, 0, z) @ ROT(90 * (i % 2), "Z") @ ROT(90, "X"))
    body.lathe([(0, -3.05), (0.25, -3.05), (0.25, -2.95), (0.05, -2.9), (0, -2.9)], 12, "brass")
    body.lathe([(0, -4.0), (0.9, -4.0), (0.9, -3.99), (0, -3.99)], 4, "brass") if False else None
    bulb = MB("H_PendantLamp_Bulb", "Decor", 4.0)
    bulb.lathe([(0, -4.0), (0.35, -3.97), (0.7, -3.75), (0.9, -3.5), (0.85, -3.3), (0.6, -3.12), (0.25, -3.05), (0, -3.05)], 20, "opal")
    return [finish(body), finish(bulb)]


def pendant_sputnik():
    """foyer chandelier: a brass sputnik with 6 arms and bulb tips (same 1.8 x 4.05 x 1.8 as the pendant)"""
    body = MB("H_PendantSputnik", "Decor", 4.0)
    body.lathe([(0, -0.05), (0.3, -0.05), (0.3, 0.05), (0, 0.05)], 12, "brass")
    body.tube([(0, 0, -0.05), (0, 0, -3.0)], 0.04, "brass", segs=6)
    ellipsoid(body, (0, 0, -3.3), (0.3, 0.3, 0.3), "brass", segs=12, rings=8)
    bulb = MB("H_PendantSputnik_Bulbs", "Decor", 4.0)
    for i in range(6):
        a = 2 * math.pi * i / 6
        el = 0.6 if i % 2 else -0.4
        d = Vector((math.cos(a), math.sin(a), el)).normalized()
        tip = Vector((0, 0, -3.3)) + d * 0.78
        body.tube([(0, 0, -3.3), tuple(tip)], 0.03, "brass", segs=5)
        ellipsoid(bulb, tuple(Vector((0, 0, -3.3)) + d * 0.84), (0.09, 0.09, 0.09), "bulb65", segs=8, rings=5)
    body.boxr((-0.9, -0.9, -4.0), (-0.89, -0.89, -3.99), "brass"); body.boxr((0.89, 0.89, -0.06), (0.9, 0.9, -0.05), "brass")
    return [finish(body), finish(bulb)]


def portable_tv():
    """H_TV becomes a 1960s portable TV on a wire stand (the screen is its own mesh as v1)"""
    body = MB("H_TV", "Decor", 4.0)
    rbox(body, (-1.4, -0.35, 1.6), (1.4, 0.35, 3.8), "enamel_cream", r=0.25, segs=2)
    body.tube([(0, 0.1, 3.8), (-0.9, 0.2, 4.0)], 0.02, "chrome65", segs=4)
    body.tube([(0, 0.1, 3.8), (0.9, 0.2, 4.0)], 0.02, "chrome65", segs=4)
    for sx in (-1, 1):
        body.tube([(sx * 1.0, 0.0, 1.6), (sx * 1.2, 0.3, 0.0)], 0.03, "iron_black", segs=4)
        body.tube([(sx * 1.0, 0.0, 1.6), (sx * 1.2, -0.38, 0.0)], 0.03, "iron_black", segs=4)
    body.boxr((-3.2, -0.4, -0.04), (-3.19, -0.39, -0.03), "iron_black"); body.boxr((3.19, 0.34, 3.99), (3.2, 0.35, 4.0), "iron_black")
    screen = MB("H_TV_Screen", "Decor", 4.0)
    rbox(screen, (-1.05, -0.4, 1.8), (0.75, -0.3, 3.55), "screen_crt", r=0.2, segs=2)
    return [finish(body), finish(screen)]


def typewriter():
    """H_Laptop becomes a portable typewriter with a sheet in it"""
    mb = MB("H_Laptop", "Decor", 0.985)
    rbox(mb, (-0.75, -0.5, 0), (0.75, 0.45, 0.32), "phone_olive", r=0.06, segs=2)
    for r_ in range(3):
        for i in range(10):
            mb.boxr((-0.55 + i * 0.11, -0.45 + r_ * 0.1, 0.3 + r_ * 0.03), (-0.49 + i * 0.11, -0.39 + r_ * 0.1, 0.36 + r_ * 0.03), "iron_black")
    mb.tube([(-0.7, 0.35, 0.42), (0.7, 0.35, 0.42)], 0.08, "iron_black", segs=10)
    mb.boxr((-0.4, 0.3, 0.45), (0.4, 0.33, 0.985), "paper65")
    mb.boxr((-0.75, 0.78, 0.0), (-0.74, 0.786, 0.01), "phone_olive")
    return finish(mb)


def frame(name, w, h, img, frame_kind="frame_gold", depth=0.15, tilt=0.0):
    """picture frame w x h, back on y = 0, bottom at z = 0, art on canvas; a gold frame has a moulded step"""
    mb = MB(name, "Art", h)
    t = 0.2 if frame_kind == "frame_gold" else 0.12
    for (a, b) in (((-w / 2, 0), (w / 2, t)), ((-w / 2, h - t), (w / 2, h)), ((-w / 2, t - 0.02), (-w / 2 + t, h - t + 0.02)), ((w / 2 - t, t - 0.02), (w / 2, h - t + 0.02))):
        mb.boxr((a[0], -depth, a[1]), (b[0], 0.0, b[1]), frame_kind)
    if frame_kind == "frame_gold":
        mb.boxr((-w / 2 + t - 0.04, -depth + 0.02, t - 0.04), (w / 2 - t + 0.04, -depth + 0.06, t), frame_kind)
    mb.boxr((-w / 2 + t - 0.02, -0.08, t - 0.02), (w / 2 - t + 0.02, -0.01, h - t + 0.02), "canvas65")
    mb.decal(img, (0, -1, 0), (0, -0.08, h / 2), w - 2 * t - 0.02, h - 2 * t - 0.02, col=None, op=1.0, kinds=["canvas65"], depth=0.05)
    return finish(mb)


def rug(name, w, d, img, oval=False):
    mb = MB(name, "Art", 0.06)
    if oval:
        pts = [(w / 2 * math.cos(2 * math.pi * i / 32), d / 2 * math.sin(2 * math.pi * i / 32)) for i in range(32)]
        mb.prism(pts, "Z", 0.0, 0.06, "rug65")
        mb.boxr((-w / 2, -d / 2, 0.0), (-w / 2 + 0.01, -d / 2 + 0.01, 0.01), "rug65")
        mb.boxr((w / 2 - 0.01, d / 2 - 0.01, 0.0), (w / 2, d / 2, 0.01), "rug65")
    else:
        rbox(mb, (-w / 2, -d / 2, 0.0), (w / 2, d / 2, 0.06), "rug65", r=0.03, segs=1)
    mb.decal(img, (0, 0, 1), (0, 0, 0.06), w, d, col=None, op=1.0, kinds=["rug65"], depth=0.1)
    mb.decal(FX + "fx_blot", (0, 0, 1), (w * 0.2, -d * 0.15, 0.06), 2.0, 2.0, col=None, op=0.6, kinds=["rug65"], depth=0.1)
    return finish(mb)


def plant_rubber():
    """H_PlantFiddle becomes a rubber plant (dark glossy leaves, a few dry ones) in a brass pot; v1 extents kept"""
    mb = MB("H_PlantFiddle", "Plants", 5.475)
    mb.lathe([(0, 0), (0.6, 0), (0.78, 1.4), (0.72, 1.45), (0.6, 1.3), (0, 1.3)], 20, "brass")
    mb.lathe([(0, 1.25), (0.68, 1.25), (0.68, 1.35), (0, 1.35)], 20, "soil65")
    rng = random.Random(3)
    stems = [((0, 0, 1.35), (0.1, 0.05, 5.1)), ((0, 0, 1.35), (-0.5, 0.2, 4.3)), ((0, 0, 1.35), (0.45, -0.3, 3.8))]
    for a, b in stems:
        mb.tube([a, b], 0.05, "stem", segs=5)
        A, B = Vector(a), Vector(b)
        for i in range(8):
            t = 0.35 + 0.65 * i / 7
            p = A.lerp(B, t)
            ang = rng.uniform(0, 2 * math.pi)
            dirv = Vector((math.cos(ang), math.sin(ang), rng.uniform(0.1, 0.6)))
            leaf(mb, p, dirv, rng.uniform(0.7, 0.95), rng.uniform(0.38, 0.48), rng.choice(["leaf65", "leaf65", "leaf65_dry"]), droop=0.2, thick=0.025)
    mb.boxr((-1.258, -0.933, 0.0), (-1.248, -0.923, 0.01), "brass"); mb.boxr((1.337, 1.088, 5.465), (1.347, 1.098, 5.475), "stem")
    return finish(mb)


def plant_snake():
    mb = MB("H_PlantSnake", "Plants", 2.833)
    mb.lathe([(0, 0), (0.45, 0), (0.5, 1.0), (0.44, 1.0), (0.4, 0.9), (0, 0.9)], 16, "terracotta65")
    mb.lathe([(0, 0.85), (0.43, 0.85), (0.43, 0.94), (0, 0.94)], 16, "soil65")
    rng = random.Random(5)
    for i in range(10):
        ang = 2 * math.pi * i / 10 + rng.uniform(-0.2, 0.2)
        r = rng.uniform(0.05, 0.25)
        base = (r * math.cos(ang), r * math.sin(ang), 0.9)
        dirv = Vector((0.18 * math.cos(ang), 0.18 * math.sin(ang), 1.0))
        leaf(mb, base, dirv, rng.uniform(1.1, 1.8), rng.uniform(0.2, 0.28), rng.choice(["leaf65", "leaf65_dry"]), droop=0.03, thick=0.03)
    mb.boxr((-0.5, -0.55, 0.0), (-0.49, -0.54, 0.01), "terracotta65"); mb.boxr((0.597, 0.49, 2.823), (0.607, 0.5, 2.833), "stem")
    return finish(mb)


def toys():
    blocks = MB("H_ToyBlocks", "Toys", 1.11)
    rng = random.Random(11)
    spots = [(0, 0, 0), (0.62, 0.05, 0), (0.3, 0.02, 0.55), (-0.5, 0.6, 0), (1.1, -0.6, 0)]
    for i, (x, y, z) in enumerate(spots):
        k = ["toy_olive", "toy_mustard", "toy_cream", "toy_olive", "toy_cream"][i]
        xf(blocks.boxr((-0.28, -0.28, 0), (0.28, 0.28, 0.56), k), T(x, y, z) @ ROT(rng.uniform(-30, 30), "Z"))
    blocks.boxr((-0.79, -0.882, 0.0), (-0.78, -0.872, 0.01), "toy_cream"); blocks.boxr((1.372, 0.88, 1.1), (1.382, 0.89, 1.11), "toy_cream")
    ball = MB("H_ToyBall", "Toys", 1.2)
    ellipsoid(ball, (0, 0, 0.6), (0.6, 0.6, 0.6), "toy_mustard", segs=16, rings=10)
    car = MB("H_ToyCar", "Toys", 0.78)     # tin toy car
    rbox(car, (-0.4, -0.75, 0.12), (0.4, 0.75, 0.45), "tin", r=0.12)
    rbox(car, (-0.34, -0.3, 0.42), (0.34, 0.35, 0.78), "tin", r=0.12)
    for sx in (-1, 1):
        for sy in (-1, 1):
            car.lathe([(0, -0.06), (0.15, -0.06), (0.15, 0.06), (0, 0.06)], 10, "rubber65", M=T(sx * 0.42, sy * 0.48, 0.15) @ ROT(90, "Y"))
    teddy = MB("H_Teddy", "Toys", 1.57)
    ellipsoid(teddy, (0, 0, 0.5), (0.42, 0.36, 0.5), "tweed_brown", segs=8, rings=4)
    ellipsoid(teddy, (0, 0, 1.18), (0.34, 0.32, 0.32), "tweed_brown", segs=8, rings=4)
    for sx in (-1, 1):
        ellipsoid(teddy, (sx * 0.24, 0.0, 1.45), (0.12, 0.08, 0.12), "tweed_brown", segs=8, rings=4)
        ellipsoid(teddy, (sx * 0.42, -0.12, 0.6), (0.14, 0.14, 0.3), "tweed_brown", segs=8, rings=4, M=ROT(sx * 25, "Y"))
        ellipsoid(teddy, (sx * 0.24, -0.3, 0.14), (0.16, 0.3, 0.14), "tweed_brown", segs=8, rings=4)
    ellipsoid(teddy, (0.1, -0.28, 0.6), (0.14, 0.08, 0.14), "foam", segs=8, rings=4)      # stuffing out of a split seam
    ellipsoid(teddy, (0, -0.28, 1.12), (0.13, 0.1, 0.1), "linen_old", segs=8, rings=4)
    return [finish(blocks), finish(ball), finish(car), finish(teddy)]


# =========================================================================================================== loose 1965 dressing (D65_*)
def dummy(name, pose, cloth_top, cloth_low, skirt=False, num=1, seat_h=1.93, knee_dz=0.05):
    """faceless chalk-grey test dummy: lofted torso, egg head, tapered limbs with ball joints, period clothes as colour
    zones (top over torso + upper arms, low over pelvis + thighs, or a skirt), a stencilled number on the chest. Taller and
    thinner than an R15 avatar (standing ~6.3). pose sit: pelvis at the origin, thighs toward -Y, feet on the floor
    seat_h below; pose lean: origin at the feet, leaning forward onto the hands at counter height 3.4, facing -Y"""
    mb = MB(name, "Dummies", 6.3)
    S, J = "dummy_skin", "dummy_joint"
    def limb(a, b, r0, r1, kind, segs=8):
        a, b = Vector(a), Vector(b)
        d = (b - a).length
        M = Matrix.Translation(a) @ (b - a).to_track_quat("Z", "Y").to_matrix().to_4x4()
        mb.lathe([(0, -0.02), (r0, -0.02), (r1, d + 0.02), (0, d + 0.02)], segs, kind, M=M)
    def joint(p, r=0.12):
        ellipsoid(mb, tuple(p), (r, r, r), J, segs=8, rings=5)
    # torso sections (z above the pelvis, half width, half depth)
    secs = [(-0.1, 0.5, 0.32), (0.25, 0.52, 0.33), (0.6, 0.42, 0.27), (1.2, 0.56, 0.32), (1.65, 0.6, 0.3), (1.85, 0.5, 0.24), (1.95, 0.16, 0.14)]
    def torso_at(z):
        for (za, xa, ya), (zb, xb, yb) in zip(secs, secs[1:]):
            if za <= z <= zb + 1e-6:
                t = (z - za) / (zb - za)
                return xa + (xb - xa) * t, ya + (yb - ya) * t
        return secs[-1][1], secs[-1][2]
    prof = [(0, secs[0][0])] + [(1.0, z) for z, _, _ in secs] + [(0, secs[-1][0])]
    def deform(v):
        hx, hy = torso_at(v.z)
        return Vector((v.x * hx, v.y * hy, v.z))
    if pose == "sit":
        T0 = Matrix.Translation((0, 0.12, 0.0)) @ Matrix.Rotation(math.radians(-5), 4, "X")
    else:
        T0 = Matrix.Translation((0, 0.35, 3.3)) @ Matrix.Rotation(math.radians(18), 4, "X")
    split = 0.6     # waist: the top's colour above, the low's colour below
    lo_prof = [(0, secs[0][0])] + [(1.0, z) for z, _, _ in secs if z <= split] + [(0, split)]
    hi_prof = [(0, split)] + [(1.0, z) for z, _, _ in secs if z >= split] + [(0, secs[-1][0])]
    mb.lathe(lo_prof, 14, cloth_low if not skirt else cloth_top, M=T0, deform=deform)
    mb.lathe(hi_prof, 14, cloth_top, M=T0, deform=deform)
    W = lambda p: T0 @ Vector(p)
    neck_a, neck_b = W((0, 0, 1.9)), W((0, 0, 2.2))
    limb(neck_a, neck_b, 0.13, 0.12, S)
    head = W((0, -0.04, 2.58))
    ellipsoid(mb, tuple(head), (0.3, 0.33, 0.42), S, segs=14, rings=9)       # faceless egg head
    sh = [W((sx * 0.64, 0, 1.62)) for sx in (-1, 1)]
    hipj = [Vector((sx * 0.3, 0.05, -0.02)) if pose == "sit" else Vector((sx * 0.3, 0.35, 3.25)) for sx in (-1, 1)]
    if pose == "sit":
        knees = [Vector((sx * 0.33, -1.6, knee_dz)) for sx in (-1, 1)]
        feet = [Vector((sx * 0.35, -1.7, -seat_h + 0.12)) for sx in (-1, 1)]
        elbows = [W((sx * 0.74, -0.15, 0.8)) for sx in (-1, 1)]
        hands = [Vector((sx * 0.48, -0.95, 0.32)) for sx in (-1, 1)]
    else:
        knees = [Vector((sx * 0.32, 0.25, 1.72)) for sx in (-1, 1)]
        feet = [Vector((sx * 0.34, 0.32, 0.12)) for sx in (-1, 1)]
        elbows = [Vector((sx * 0.74, -0.45, 4.15)) for sx in (-1, 1)]
        hands = [Vector((sx * 0.6, -1.12, 3.47)) for sx in (-1, 1)]
    for s_, e_, h_ in zip(sh, elbows, hands):
        joint(s_, 0.17)
        limb(s_, e_, 0.15, 0.12, cloth_top); joint(e_, 0.11)
        limb(e_, h_, 0.11, 0.08, S)
        ellipsoid(mb, tuple(h_), (0.09, 0.15, 0.05), S, segs=8, rings=4)
    for hp, kn, ft in zip(hipj, knees, feet):
        limb(hp, kn, 0.21, 0.15, cloth_low if not skirt else S); joint(kn, 0.13)
        limb(kn, ft, 0.14, 0.09, S if skirt else cloth_low)
        mb.boxr((ft.x - 0.13, ft.y - 0.5, ft.z - 0.12), (ft.x + 0.13, ft.y + 0.12, ft.z + 0.08), "shoe")
    if skirt:      # a skirt from the waist to just past the knees
        if pose == "sit":
            xf(rbox(mb, (-0.62, -1.78, -0.12), (0.62, 0.3, 0.32), cloth_low, r=0.14, segs=2), about((0, 0.3, 0.1), ROT(-4)))
        else:
            mb.lathe([(0, 1.6), (0.68, 1.6), (0.5, 3.75), (0, 3.75)], 12, cloth_low, M=Matrix.Translation((0, 0.35, 0)), deform=lambda v: Vector((v.x, v.y * 0.75, v.z)))
    chest = W((0, -0.34, 1.25))
    mb.decal(FX + f"dummy_num_{num}", (0, -1, 0), tuple(chest), 0.5, 0.5, col=(40, 36, 30), op=0.9, kinds=[cloth_top], depth=0.5)
    return finish(mb)


def rotary_phone():
    mb = MB("D65_Phone", "Dress65", 0.6)
    rbox(mb, (-0.38, -0.42, 0), (0.38, 0.42, 0.34), "phone_olive", r=0.12, segs=2)
    mb.lathe([(0, 0), (0.22, 0), (0.22, 0.03), (0, 0.03)], 16, "bakelite_cream", M=T(0, -0.12, 0.3) @ ROT(-20))
    mb.tube([(-0.38, 0.15, 0.48), (0.38, 0.15, 0.48)], 0.07, "phone_olive", segs=8)
    for sx in (-1, 1):
        ellipsoid(mb, (sx * 0.38, 0.15, 0.48), (0.1, 0.12, 0.1), "phone_olive", segs=8, rings=5)
    mb.tube([(0.4, 0.2, 0.1), (0.7, 0.4, 0.0), (1.0, 0.2, 0.0)], 0.02, "bakelite", segs=4)
    mb.boxr((-1.0, -0.5, 0.0), (-0.4, 0.3, 0.03), "paper65")          # notepad
    return finish(mb)


def radio():
    """table radio: walnut case, cloth grille, dial strip with our own numbers, two knobs"""
    mb = MB("D65_Radio", "Dress65", 0.9)
    rbox(mb, (-0.8, -0.35, 0), (0.8, 0.35, 0.9), "walnut65", r=0.1, segs=2)
    mb.boxr((-0.7, -0.37, 0.25), (0.15, -0.33, 0.8), "speaker_cloth")
    mb.boxr((0.2, -0.37, 0.5), (0.7, -0.33, 0.78), "paper65")
    mb.decal(FX + "radio_dial", (0, -1, 0), (0.45, -0.37, 0.64), 0.5, 0.25, col=None, op=1.0, kinds=["paper65"], depth=0.05)
    for x in (0.3, 0.6):
        knob(mb, x, -0.35, 0.32, kind="bakelite_cream", r=0.08)
    return finish(mb)


def record_player():
    mb = MB("D65_RecordPlayer", "Dress65", 0.5)
    mb.boxr((-0.9, -0.75, 0), (0.9, 0.75, 0.32), "enamel_cream")
    mb.lathe([(0, 0.32), (0.6, 0.32), (0.6, 0.36), (0, 0.36)], 24, "record_black", M=T(-0.15, 0, 0))
    mb.tube([(0.65, 0.5, 0.42), (0.6, -0.1, 0.4)], 0.025, "chrome65", segs=5)
    mb.boxr((-0.9, 0.7, 0.32), (0.9, 0.75, 1.2), "enamel_cream") if False else None
    return finish(mb)


def papers():
    """scattered papers + a newspaper on the floor (flat, 0.02 thick, a few curled)"""
    mb = MB("D65_Papers", "Dress65", 0.1)
    rng = random.Random(77)
    for i in range(9):
        x, y, a = rng.uniform(-1.6, 1.6), rng.uniform(-1.2, 1.2), rng.uniform(0, 180)
        fs = mb.boxr((-0.32, -0.42, 0.0), (0.32, 0.42, 0.015), "paper65")
        xf(fs, T(x, y, 0.0 + i * 0.002) @ ROT(a, "Z") @ ROT(rng.uniform(-6, 6), "X"))
    fs = mb.boxr((-0.75, -0.55, 0.0), (0.75, 0.55, 0.02), "paper65")
    xf(fs, T(0.6, 0.2, 0.03) @ ROT(25, "Z"))
    mb.decal(FX + "newspaper", (0, 0, 1), (0.6, 0.2, 0.05), 1.3, 1.3, col=None, op=1.0, kinds=["paper65"], depth=0.1)
    return finish(mb)


def broken_plates():
    """shards of a dropped plate and a cup on the floor"""
    mb = MB("D65_BrokenPlates", "Dress65", 0.2)
    rng = random.Random(9)
    for i in range(9):
        a0 = rng.uniform(0, 2 * math.pi); da = rng.uniform(0.5, 1.1)
        r0, r1 = rng.uniform(0.0, 0.15), rng.uniform(0.35, 0.5)
        pts = [(r0 * math.cos(a0), r0 * math.sin(a0)), (r1 * math.cos(a0), r1 * math.sin(a0)), (r1 * math.cos(a0 + da), r1 * math.sin(a0 + da))]
        cx, cy = rng.uniform(-0.9, 0.9), rng.uniform(-0.7, 0.7)
        mb.prism([(cx + p[0], cy + p[1]) for p in pts], "Z", 0.0, 0.04, "china")
    mb.lathe([(0, 0), (0.16, 0), (0.2, 0.3), (0.18, 0.3), (0.14, 0.03), (0, 0.03)], 10, "china", M=T(0.6, 0.4, 0.2) @ ROT(90))
    return finish(mb)


def knocked_lamp():
    """a tripod floor lamp lying on its side (art only, 5 long)"""
    mb = MB("D65_LampKnocked", "Dress65", 1.2)
    M = T(0, 0, 0.5) @ ROT(90, "Y") @ ROT(15, "X")
    for i in range(3):
        a = 2 * math.pi * i / 3
        p0 = M @ Vector((0.1 * math.cos(a), 0.1 * math.sin(a), 3.0)); p1 = M @ Vector((0.9 * math.cos(a), 0.9 * math.sin(a), 0.0))
        mb.tube([tuple(p0), tuple(p1)], 0.05, "walnut65", segs=6)
    mb.lathe([(0, 2.9), (0.04, 2.9), (0.035, 4.7), (0, 4.7)], 8, "brass", M=M)
    mb.lathe([(0, 4.6), (0.95, 4.75), (0.95, 5.9), (0, 5.9)], 20, "shade65", M=M @ T(0, 0, 0) )
    lo = min(v.co.z for v in mb.bm.verts)
    for v in mb.bm.verts:
        v.co.z -= lo
    return finish(mb)


def knocked_chair():
    """a dinette chair knocked over onto its back"""
    mb = MB("D65_ChairKnocked", "Dress65", 2.0)
    M = ROT(-90)
    def tb(pts, r):
        mb.tube([tuple(M @ Vector(p)) for p in pts], r, "chrome65", segs=8)
    for sx in (-1, 1):
        tb([(sx * 0.82, -0.82, 0.0), (sx * 0.82, -0.82, 1.38), (sx * 0.82, 0.78, 1.38), (sx * 0.86, 0.86, 0.0)], 0.06)
        tb([(sx * 0.8, 0.78, 1.38), (sx * 0.8, 0.86, 3.25)], 0.055)
    fs = rbox(mb, (-0.95, -0.95, 1.36), (0.95, 0.9, 1.72), "vinyl_mustard", r=0.12); xf(fs, M)
    fs = rbox(mb, (-0.92, 0.72, 2.1), (0.92, 0.987, 3.39), "vinyl_mustard", r=0.14); xf(fs, M)
    lo = min(v.co.z for v in mb.bm.verts)
    for v in mb.bm.verts:
        v.co.z -= lo
    return finish(mb)


def sand_drift(name="D65_SandDrift", w=4.0, d=2.0):
    """low wind-blown sand drift (<= 0.15 tall), art only"""
    mb = MB(name, "Dress65", 0.15)
    n = 10
    verts, faces = [], []
    for j in range(n + 1):
        for i in range(n + 1):
            u, v = i / n, j / n
            x, y = (u - 0.5) * w, (v - 0.5) * d
            h = 0.15 * max(0.0, 1 - ((u - 0.5) * 2) ** 2) * max(0.0, 1 - v) ** 1.4 * (0.8 + 0.2 * math.sin(u * 9))
            if j == 0 or i == 0 or i == n or j == n:
                h = 0.0
            verts.append((x, y, h + 0.005))
    for j in range(n):
        for i in range(n):
            a = j * (n + 1) + i
            faces.append((a, a + 1, a + n + 2, a + n + 1))
    mb.raw(verts, faces, "sand")
    o = finish(mb)
    o["open_shell"] = True      # a heightfield lying on the floor: its underside is never seen
    return o


def cobweb():
    """a cobweb card across a ceiling corner (double-sided: two faces 0.03 apart, each with its own normal)"""
    mb = MB("D65_Cobweb", "Dress65", 1.5)
    pts = [(0, 0, 0), (1.5, 0, 0), (0, 1.5, 0), (0, 0, -1.5)]
    # one triangle spanning the three walls/ceiling at 1.5 from the corner, plus its reversed twin 0.03 behind
    a, b, c = Vector((1.5, 0, 0)), Vector((0, 1.5, 0)), Vector((0, 0, -1.5))
    n = (b - a).cross(c - a).normalized()
    mb.raw([tuple(a), tuple(b), tuple(c)], [(0, 1, 2)], "web")
    off = -n * 0.03
    mb.raw([tuple(a + off), tuple(c + off), tuple(b + off)], [(0, 1, 2)], "web")
    o = finish(mb)
    o["open_shell"] = True      # a double-sided card (two faces 0.03 apart, each with its own normal)
    return o


def tin_rocket():
    mb = MB("D65_TinRocket", "Dress65", 1.4)
    mb.lathe([(0, 0.2), (0.18, 0.2), (0.2, 0.8), (0.14, 1.15), (0, 1.4)], 12, "tin")
    for i in range(3):
        a = 2 * math.pi * i / 3
        mb.prism([(0.0, 0.0), (0.38, -0.05), (0.2, 0.45), (0.0, 0.5)], "Y", -0.02, 0.02, "toy_olive") if False else None
        fin = [(0.15 * math.cos(a), 0.15 * math.sin(a), 0.2), (0.4 * math.cos(a), 0.4 * math.sin(a), 0.0), (0.18 * math.cos(a), 0.18 * math.sin(a), 0.6)]
        mb.raw(fin + [tuple(Vector(p) + Vector((-math.sin(a), math.cos(a), 0)) * 0.03) for p in fin], [(0, 1, 2), (5, 4, 3), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)], "toy_olive")
    return finish(mb)


def wall_paper(name, w, h, img, kind="paper65", curl=0.0):
    """a poster / calendar / notice mounted on a 0.12 board: back on y = 0 (flush on the wall), bottom at z = 0"""
    mb = MB(name, "Posters", h)
    fs = mb.boxr((-w / 2, -0.12, 0.0), (w / 2, 0.0, h), kind)
    if curl:
        for v in {v for f in fs for v in f.verts}:
            if v.co.z < 0.3 and v.co.x > w / 2 - 0.4:
                v.co.y -= curl
    mb.decal(FX + img, (0, -1, 0), (0, -0.12, h / 2), w, h, col=None, op=1.0, kinds=[kind], depth=0.05)
    return finish(mb)


def clipboard():
    mb = MB("D65_Clipboard", "Dress65", 1.2)
    mb.boxr((-0.45, -0.04, 0), (0.45, 0.0, 1.2), "pine65")
    mb.boxr((-0.38, -0.06, 0.05), (0.38, -0.04, 1.0), "paper65")
    mb.boxr((-0.2, -0.1, 1.0), (0.2, -0.04, 1.15), "chrome65")
    return finish(mb)


def canisters_cake():
    """counter dressing: a canister set with our own labels and a cake under a glass dome"""
    mb = MB("D65_Canisters", "Dress65", 1.2)
    for i, (r, h) in enumerate(((0.32, 1.0), (0.28, 0.85), (0.25, 0.7), (0.22, 0.58))):
        mb.lathe([(0, 0), (r, 0), (r, h), (r * 0.7, h + 0.06), (0.06, h + 0.1), (0.06, h + 0.16), (0, h + 0.16)], 14, "enamel_cream", M=T(-1.0 + i * 0.68, 0, 0))
    ck = MB("D65_CakeDome", "Dress65", 1.1)
    ck.lathe([(0, 0), (0.7, 0), (0.75, 0.08), (0, 0.08)], 18, "china")
    ck.lathe([(0, 0.08), (0.5, 0.08), (0.5, 0.45), (0, 0.45)], 16, "food_cake")
    ck.lathe([(0, 0.08), (0.65, 0.08), (0.62, 0.6), (0.4, 0.95), (0.08, 1.02), (0.08, 1.1), (0, 1.1)], 18, "glass65")
    return [finish(mb), finish(ck)]


def drape(name, kind, h):
    """one drape panel pulled to the side: gathered folds, 1.0 wide, 0.4 deep, h tall; back on y = 0, bottom z = 0"""
    mb = MB(name, "Drapes", h)
    n = 12
    pts = []
    for i in range(n + 1):
        x = -0.5 + i / n
        pts.append((x, -0.2 - 0.12 * math.cos(i * math.pi * 0.9)))
    poly = [(x, y - 0.03) for x, y in pts] + [(x, y + 0.13) for x, y in reversed(pts)]
    mb.prism(poly, "Z", 0.0, h, kind)
    mb.tube([(-0.52, -0.28, h * 0.45), (0.52, -0.28, h * 0.45)], 0.05, kind, segs=6)    # tie-back
    return finish(mb)


def drape_rod(name, L):
    mb = MB(name, "Drapes", 0.3)
    mb.tube([(-L / 2, -0.35, 0.15), (L / 2, -0.35, 0.15)], 0.05, "brass", segs=8)
    for x in (-L / 2 + 0.2, L / 2 - 0.2):
        mb.tube([(x, 0.0, 0.15), (x, -0.35, 0.15)], 0.03, "brass", segs=5)
    for x in (-L / 2, L / 2):
        ellipsoid(mb, (x, -0.35, 0.15), (0.08, 0.08, 0.08), "brass", segs=8, rings=5)
    return finish(mb)


def human():
    mb = MB("R15_Human_5stud", "None", 5.0)
    mb.boxr((-0.5, -0.25, 0.0), (-0.05, 0.25, 2.0), "cloth_suit"); mb.boxr((0.05, -0.25, 0.0), (0.5, 0.25, 2.0), "cloth_suit")
    mb.boxr((-0.75, -0.3, 2.0), (0.75, 0.3, 3.8), "cloth_shirt")
    mb.boxr((-1.2, -0.25, 2.1), (-0.78, 0.25, 3.8), "cloth_shirt"); mb.boxr((0.78, -0.25, 2.1), (1.2, 0.25, 3.8), "cloth_shirt")
    mb.boxr((-0.4, -0.38, 3.82), (0.4, 0.38, 5.0), "dummy_skin")
    return mb


# =========================================================================================================== assemblies
LOW, TALL, NONE = "LOW 3.4", "TALL 8.0", "none (dressing)"
B_SOFA = [((-6, 0.15, 0), (6, 1.8, 3.4)), ((-6, -1.8, 0), (-5.05, 0.15, 2.6)), ((5.05, -5.4, 0), (6, 0.15, 2.6)),
          ((-5.05, -1.8, 0), (5.05, 0.15, 1.8)), ((2.2, -5.4, 0), (5.05, -1.8, 1.8))]
B_ARM = [((-2.1, 0.35, 0), (2.1, 2.0, 3.4)), ((-2.1, -2.0, 0), (-1.35, 0.35, 2.5)), ((1.35, -2.0, 0), (2.1, 0.35, 2.5)), ((-1.35, -2.0, 0), (1.35, 0.35, 1.8))]
B_DINE = [((-4.0, -2.0, 0), (4.0, 2.0, 2.6)), ((-3.05, -3.35, 0), (3.05, -3.0, 3.4)), ((-3.05, 3.0, 0), (3.05, 3.35, 3.4)),
          ((-3.05, -3.0, 0), (3.05, -2.0, 1.75)), ((-3.05, 2.0, 0), (3.05, 3.0, 1.75))]
B_BED2 = [((-3.85, 4.4, 0), (3.85, 5.0, 3.4)), ((-3.7, -5.0, 0), (3.7, 4.45, 2.4))]
B_BED1 = [((-2.35, 3.75, 0), (2.35, 4.3, 3.4)), ((-2.2, -4.3, 0), (2.2, 3.8, 2.4))]
B_KB = [((-5, 0.5, 0), (5, 1.75, 3.4)), ((-5, -1.75, 0), (5, 0.5, 1.95))]
B_HB3 = [((-1.75, 0.65, 0), (1.75, 1, 3.4)), ((-1.75, -1, 0), (1.75, 0.65, 1.65))]
B_HB8 = [((-4, 0.65, 0), (4, 1, 3.4)), ((-4, -1, 0), (4, 0.65, 1.65))]
CH = [("H_DiningChair", (x, sy * 2.35, 0), 0 if sy > 0 else 180) for x in (-2.1, 0, 2.1) for sy in (-1, 1)]
ASM = [
    ("H_Sofa_Sectional", [("H_Sofa_Sectional", (0, 0, 0), 0)], "skirted L-sectional, cream vinyl; boxes: back 3.4, arms 2.6, seats 1.8", LOW, B_SOFA),
    ("H_Armchair", [("H_Armchair", (0, 0, 0), 0)], "club armchair, olive tweed; boxes: back 3.4, arms 2.5, seat 1.8", LOW, B_ARM),
    ("H_KitchenIsland", [("H_KitchenIsland", (0, 0, 0), 0)], "gold enamel island, laminate top, seating side +Y", LOW, [((-5, -2.3, 0), (5, 2.3, 3.4))]),
    ("H_DiningSet", [("H_DiningTable", (0, 0, 0), 0)] + CH + [("H_TableSetting", (0, 0, 0), 0)],
     "walnut table set for six + 6 dinette chairs; boxes: table 2.6 + a 3.4 box per chair row", LOW, B_DINE),
    ("H_DiningTable", [("H_DiningTable", (0, 0, 0), 0)], "dining table alone (top 2.6)", "low obstacle 2.6", [((-4, -2, 0), (4, 2, 2.6))]),
    ("H_DiningChair", [("H_DiningChair", (0, 0, 0), 0)], "dinette chair alone", NONE, []),
    ("H_Bed_Double", [("H_Bed_Double", (0, 0, 0), 0)], "walnut bed, chenille spread to the floor, head at +Y", LOW, B_BED2),
    ("H_Bed_Single", [("H_Bed_Single", (0, 0, 0), 0)], "maple spindle bed, cowboy-print spread, head at +Y", LOW, B_BED1),
    ("H_Dresser", [("H_Dresser", (0, 0, 0), 0)], "walnut lowboy dresser", LOW, [((-3, -1.1, 0), (3, 1.1, 3.4))]),
    ("H_Bathtub", [("H_Bathtub", (0, 0, 0), 0)], "built-in tub, mint tiled apron and ledge to 3.4", LOW, [((-3.5, -1.8, 0), (3.5, 1.8, 3.4))]),
    ("H_TVConsole", [("H_TVConsole", (0, 0, 0), 0)], "console TV + radiogram, walnut", LOW, [((-4, -1.0, 0), (4, 1.0, 3.4))]),
    ("H_TVConsole_WithTV", [("H_TVConsole", (0, 0, 0), 0), ("H_TV", (0, 0.2, 3.4), 0), ("H_TV_Screen", (0, 0.2, 3.4), 0)],
     "console with a portable TV on it", LOW, [((-4, -1.0, 0), (4, 1.0, 3.4))]),
    ("H_KitchenBase", [("H_KitchenBase", (0, 0, 0), 0)], "gold enamel base module 4 wide", LOW, [((-2, -1.25, 0), (2, 1.2, 3.4))]),
    ("H_KitchenSink", [("H_KitchenSink", (0, 0, 0), 0)], "base with a steel sink and a chrome tap", LOW, [((-2, -1.25, 0), (2, 1.2, 3.4))]),
    ("H_KitchenHob", [("H_KitchenHob", (0, 0, 0), 0)], "cream enamel range, coil burners, oven", LOW, [((-2, -1.25, 0), (2, 1.2, 3.4))]),
    ("H_Bookcase", [("H_Bookcase", (0, 0, 0), 0), ("H_Bookcase_Glass", (0, 0, 0), 0)], "walnut glass-front bookcase on a closed base", TALL, [((-3, -0.8, 0), (3, 0.8, 8.0))]),
    ("H_Fridge", [("H_Fridge", (0, 0, 0), 0)], "rounded-top fridge + walnut cabinet over it to 8", TALL, [((-1.8, -1.3, 0), (1.8, 1.3, 8.0))]),
    ("H_Wardrobe", [("H_Wardrobe", (0, 0, 0), 0)], "walnut wardrobe", TALL, [((-3, -1.2, 0), (3, 1.2, 8.0))]),
    ("H_TallCabinet", [("H_TallCabinet", (0, 0, 0), 0)], "painted linen press (cream)", TALL, [((-1.5, -1.0, 0), (1.5, 1.0, 8.0))]),
    ("H_Pantry", [("H_Pantry", (0, 0, 0), 0)], "gold enamel pantry", TALL, [((-2, -1.2, 0), (2, 1.2, 8.0))]),
    ("H_ShelfWall", [("H_ShelfWall", (0, 0, 0), 0), ("H_ShelfWall_Books", (0, 0, 0), 0)], "walnut room divider dressed on both faces (team A spawn wall)", TALL, [((-6, -1, 0), (6, 1, 8))]),
    ("H_OvenWall", [("H_OvenWall", (0, 0, 0), 0)], "twin steel wall ovens in gold enamel (team B spawn wall); ovens on -Y", TALL, [((-6, -1, 0), (6, 1, 8))]),
    ("H_SlatScreen", [("H_SlatScreen", (0, 0, 0), 0)], "spindle room divider on a walnut base", TALL, [((-3, -1, 0), (3, 1, 8))]),
    ("H_HeadboardWall", [("H_HeadboardWall", (0, 0, 0), 0)], "walnut panelled bed wall with a padded mustard headboard (-Y)", TALL, [((-7, -0.75, 0), (7, 0.75, 8))]),
    ("H_KitchenBench", [("H_KitchenBench", (0, 0, 0), 0)], "diner booth, seat faces -Y; boxes: back 3.4, seat 1.95", LOW, B_KB),
    ("H_HallBench_3", [("H_HallBench_3", (0, 0, 0), 0)], "telephone / gossip bench; boxes: back 3.4, seat 1.65", LOW, B_HB3),
    ("H_HallBench_8", [("H_HallBench_8", (0, 0, 0), 0)], "slatted pine mudroom bench; boxes: back 3.4, seat 1.65", LOW, B_HB8),
    ("H_Planter", [("H_Planter", (0, 0, 0), 0), ("H_Planter_Tree", (0, 0, 0), 0)], "brick planter (cover 3.4) + rubber plant as art", LOW, [((-1.5, -1.5, 0), (1.5, 1.5, 3.4))]),
    ("H_DisplayColumn", [("H_DisplayColumn", (0, 0, 0), 0)], "fieldstone column with walnut niches on -Y and +Y", TALL, [((-1.5, -1.5, 0), (1.5, 1.5, 8))]),
    # dressing
    ("H_KitchenUpper", [("H_KitchenUpper", (0, 0, 0), 0)], "gold enamel wall cabinet, bottom 5.8 above the floor", NONE, []),
    ("H_RangeHood", [("H_RangeHood", (0, 0, 0), 0)], "gold enamel hood, bottom 5.8 above the floor", NONE, []),
    ("H_BarStool", [("H_BarStool", (0, 0, 0), 0)], "chrome stool, olive vinyl top", NONE, []),
    ("H_Nightstand", [("H_Nightstand", (0, 0, 0), 0)], "walnut nightstand", NONE, []),
    ("H_CoffeeTable", [("H_CoffeeTable", (0, 0, 0), 0)], "kidney coffee table, magazines, ashtray", NONE, []),
    ("H_SideTable", [("H_SideTable", (0, 0, 0), 0)], "round walnut side table", NONE, []),
    ("H_Desk", [("H_Desk", (0, 0, 0), 0)], "steel tanker desk", NONE, []),
    ("H_DeskChair", [("H_DeskChair", (0, 0, 0), 0)], "wooden spindle-back chair", NONE, []),
    ("H_WashingMachine", [("H_WashingMachine", (0, 0, 0), 0)], "top-loading washer", NONE, []),
    ("H_FruitBowl", [("H_FruitBowl", (0, 0, 0), 0)], "olive bowl of wax fruit", NONE, []),
    ("H_Microwave", [("H_Microwave", (0, 0, 0), 0)], "toaster + bread bin (no microwaves in 1965)", NONE, []),
    ("H_CoffeeMachine", [("H_CoffeeMachine", (0, 0, 0), 0)], "percolator", NONE, []),
    ("H_Kettle", [("H_Kettle", (0, 0, 0), 0)], "whistling kettle", NONE, []),
    ("H_TV", [("H_TV", (0, 0, 0), 0), ("H_TV_Screen", (0, 0, 0), 0)], "portable TV on a wire stand; screen is its own mesh", NONE, []),
    ("H_Laptop", [("H_Laptop", (0, 0, 0), 0)], "portable typewriter", NONE, []),
    ("H_FloorLamp", [("H_FloorLamp", (0, 0, 0), 0), ("H_FloorLamp_Shade", (0, 0, 0), 0)], "tripod lamp, drum shade; PointLight in the shade at z 5.3", NONE, []),
    ("H_TableLamp", [("H_TableLamp", (0, 0, 0), 0), ("H_TableLamp_Shade", (0, 0, 0), 0)], "ceramic lamp, pleated shade; PointLight at z 1.6", NONE, []),
    ("H_PendantLamp", [("H_PendantLamp", (0, 0, 0), 0), ("H_PendantLamp_Bulb", (0, 0, 0), 0)], "opal globe pendant on a brass chain: origin = ceiling point (_Bulb glows)", NONE, []),
    ("H_Frame_Abstract", [("H_Frame_Abstract", (0, 0, 0), 0)], "mid-century print, thin walnut frame 4 x 4", NONE, []),
    ("H_Frame_Landscape", [("H_Frame_Landscape", (0, 0, 0), 0)], "desert oil in a gold frame 5.4 x 3.6", NONE, []),
    ("H_Frame_Botanical", [("H_Frame_Botanical", (0, 0, 0), 0)], "cactus-flower oil in a gold frame 2.6 x 3.4", NONE, []),
    ("H_Frame_Geometric", [("H_Frame_Geometric", (0, 0, 0), 0)], "kid's rocket drawing, framed 3 x 3", NONE, []),
    ("H_Rug_Living", [("H_Rug_Living", (0, 0, 0), 0)], "olive shag rug 12 x 8", NONE, []),
    ("H_Rug_Runner", [("H_Rug_Runner", (0, 0, 0), 0)], "braided runner 4 x 10", NONE, []),
    ("H_PlantFiddle", [("H_PlantFiddle", (0, 0, 0), 0)], "rubber plant in a brass pot", NONE, []),
    ("H_PlantSnake", [("H_PlantSnake", (0, 0, 0), 0)], "snake plant, terracotta", NONE, []),
    ("H_Toilet", [("H_Toilet", (0, 0, 0), 0)], "mint toilet, back to the wall (+Y)", NONE, []),
    ("H_Vanity", [("H_Vanity", (0, 0, 0), 0)], "mint vanity: back on the wall at +Y 0.9", NONE, []),
    ("H_Mirror", [("H_Mirror", (0, 0, 0), 0)], "chrome medicine cabinet, back on y = 0, hang bottom at 3.9", NONE, []),
    ("H_ShowerSet", [("H_ShowerSet", (0, 0, 0), 0)], "chrome shower head + cross taps, back on y = 0", NONE, []),
    ("H_ShowerGlass", [("H_ShowerGlass", (0, 0, 0), 0), ("H_ShowerGlassProfile", (0, 0, 0), 0)], "vinyl shower curtain on a chrome rod (opaque, baked) + rod flange", "player blocker box 3 x 6.6 x 0.1 (as v1)", []),
    ("H_TowelRail", [("H_TowelRail", (0, 0, 0), 0)], "chrome rail, faded towels, back on y = 0", NONE, []),
    ("H_ToyBlocks", [("H_ToyBlocks", (0, 0, 0), 0)], "wooden blocks", NONE, []),
    ("H_ToyBall", [("H_ToyBall", (0, 0, 0), 0)], "rubber ball", NONE, []),
    ("H_ToyCar", [("H_ToyCar", (0, 0, 0), 0)], "tin toy car", NONE, []),
    ("H_Teddy", [("H_Teddy", (0, 0, 0), 0)], "worn teddy (a split seam)", NONE, []),
]
# room variants: same boxes / size as their base piece (optional swaps by layout id: house_1965_variants.json)
VARIANTS = [
    ("H_Armchair_Mustard", "H_Armchair", [("H_Armchair_Mustard", (0, 0, 0), 0)], "slipper chair, mustard tweed (MB)", LOW, B_ARM),
    ("H_Bed_Double_Maple", "H_Bed_Double", [("H_Bed_Double_Maple", (0, 0, 0), 0)], "maple spindle bed, plaid spread (BR2)", LOW, B_BED2),
    ("H_Dresser_Credenza", "H_Dresser", [("H_Dresser_Credenza", (0, 0, 0), 0)], "walnut credenza, sliding louvred doors (LR)", LOW, [((-3, -1.1, 0), (3, 1.1, 3.4))]),
    ("H_Dresser_Phone", "H_Dresser", [("H_Dresser_Phone", (0, 0, 0), 0)], "walnut telephone table, skirted cupboard (FY)", LOW, [((-3, -1.1, 0), (3, 1.1, 3.4))]),
    ("H_Dresser_Maple", "H_Dresser", [("H_Dresser_Maple", (0, 0, 0), 0)], "maple dresser (BR2)", LOW, [((-3, -1.1, 0), (3, 1.1, 3.4))]),
    ("H_Dresser_Cream", "H_Dresser", [("H_Dresser_Cream", (0, 0, 0), 0)], "painted cream chest of drawers (BR3)", LOW, [((-3, -1.1, 0), (3, 1.1, 3.4))]),
    ("H_TVConsole_Buffet", "H_TVConsole", [("H_TVConsole_Buffet", (0, 0, 0), 0)], "walnut buffet, louvred doors (DR)", LOW, [((-4, -1.0, 0), (4, 1.0, 3.4))]),
    ("H_Bathtub_Butter", "H_Bathtub", [("H_Bathtub_Butter", (0, 0, 0), 0)], "built-in tub, butter-yellow tiles (UB)", LOW, [((-3.5, -1.8, 0), (3.5, 1.8, 3.4))]),
    ("H_Bookcase_Hutch", "H_Bookcase", [("H_Bookcase_Hutch", (0, 0, 0), 0), ("H_Bookcase_Hutch_Glass", (0, 0, 0), 0)], "walnut china hutch, plates on display (DR)", TALL, [((-3, -0.8, 0), (3, 0.8, 8.0))]),
    ("H_Bookcase_Maple", "H_Bookcase", [("H_Bookcase_Maple", (0, 0, 0), 0)], "open maple bookcase (BR2)", TALL, [((-3, -0.8, 0), (3, 0.8, 8.0))]),
    ("H_Wardrobe_Lockers", "H_Wardrobe", [("H_Wardrobe_Lockers", (0, 0, 0), 0)], "painted green coat lockers, chalked numbers (MR)", TALL, [((-3, -1.2, 0), (3, 1.2, 8.0))]),
    ("H_Wardrobe_Maple", "H_Wardrobe", [("H_Wardrobe_Maple", (0, 0, 0), 0)], "maple wardrobe (BR2)", TALL, [((-3, -1.2, 0), (3, 1.2, 8.0))]),
    ("H_Wardrobe_Cream", "H_Wardrobe", [("H_Wardrobe_Cream", (0, 0, 0), 0)], "painted cream wardrobe (BR3)", TALL, [((-3, -1.2, 0), (3, 1.2, 8.0))]),
    ("H_TallCabinet_HallTree", "H_TallCabinet", [("H_TallCabinet_HallTree", (0, 0, 0), 0)], "walnut hall tree with mirror, coat and hat (BH)", TALL, [((-1.5, -1.0, 0), (1.5, 1.0, 8.0))]),
    ("H_Desk_School", "H_Desk", [("H_Desk_School", (0, 0, 0), 0)], "maple school desk (BR3)", NONE, []),
    ("H_Toilet_Butter", "H_Toilet", [("H_Toilet_Butter", (0, 0, 0), 0)], "butter toilet (UB)", NONE, []),
    ("H_Vanity_Butter", "H_Vanity", [("H_Vanity_Butter", (0, 0, 0), 0)], "butter vanity (UB)", NONE, []),
    ("H_PendantLamp_Sputnik", "H_PendantLamp", [("H_PendantSputnik", (0, 0, 0), 0), ("H_PendantSputnik_Bulbs", (0, 0, 0), 0)], "brass sputnik chandelier (FY)", NONE, []),
    ("H_Frame_Notice", "H_Frame_Geometric", [("H_Frame_Notice", (0, 0, 0), 0)], "household drill notice board (MR)", NONE, []),
    ("H_Frame_Pennant", "H_Frame_Botanical", [("H_Frame_Pennant", (0, 0, 0), 0)], "framed pennant (BR2)", NONE, []),
    ("H_Frame_Mesa", "H_Frame_Landscape", [("H_Frame_Mesa", (0, 0, 0), 0)], "ranch-and-mesas oil in a gold frame (MB)", NONE, []),
    ("H_Rug_Oval", "H_Rug_Living", [("H_Rug_Oval", (0, 0, 0), 0)], "braided oval rug (MB)", NONE, []),
]
# layout id -> variant (the builder swaps the model name in its installer; base names keep working without it)
VARIANT_MAP = {"MB_Chair": "H_Armchair_Mustard", "BR2_Bed": "H_Bed_Double_Maple", "LR_Sideboard": "H_Dresser_Credenza",
               "FY_Console": "H_Dresser_Phone", "BR2_Dresser": "H_Dresser_Maple", "BR3_Dresser": "H_Dresser_Cream",
               "DR_Sideboard": "H_TVConsole_Buffet", "UB_Tub": "H_Bathtub_Butter", "DR_Cabinet": "H_Bookcase_Hutch",
               "BR2_Bookcase": "H_Bookcase_Maple", "MR_Lockers": "H_Wardrobe_Lockers", "BR2_Wardrobe": "H_Wardrobe_Maple",
               "BR3_Wardrobe": "H_Wardrobe_Cream", "BH_CoatTree": "H_TallCabinet_HallTree", "BR3_Desk": "H_Desk_School",
               "UB_Toilet": "H_Toilet_Butter", "UB_Vanity": "H_Vanity_Butter", "FY_Pend": "H_PendantLamp_Sputnik",
               "MR_Art": "H_Frame_Notice", "BR2_Art": "H_Frame_Pennant", "MB_Art": "H_Frame_Mesa", "MB_Rug": "H_Rug_Oval"}
D65 = ["D65_Phone", "D65_Radio", "D65_RecordPlayer", "D65_Papers", "D65_BrokenPlates", "D65_LampKnocked", "D65_ChairKnocked",
       "D65_SandDrift", "D65_SandDriftSmall", "D65_Cobweb", "D65_TinRocket", "D65_Clipboard", "D65_Canisters", "D65_CakeDome",
       "D65_Dummy_SitA", "D65_Dummy_SitB", "D65_Dummy_SitC", "D65_Dummy_SitD", "D65_Dummy_SitE", "D65_Dummy_Lean",
       "D65_Poster_Travel", "D65_Poster_Kitchen", "D65_Calendar", "D65_Notice", "D65_Pennant",
       "D65_Drape_Gold", "D65_Drape_Mustard", "D65_Drape_Green", "D65_DrapeRod"]


def layout(by_name, asm):
    kitc = coll("Kit")
    placed, pivots, used = {}, {}, set()
    x = 0.0
    rowy = 0.0
    for name, parts, *_ in asm:
        objs = []
        for (m, (dx, dy, dz), rz) in parts:
            src = by_name[m]
            if m not in used:
                o = src; used.add(m)
                for c in o.users_collection:
                    c.objects.unlink(o)
            else:
                o = src.copy()
            o.name = f"{name}__{m}" if (name != m or len(parts) > 1) else name
            kitc.objects.link(o)
            o.rotation_euler = (0, 0, math.radians(rz))
            o.location = (dx, dy, dz)
            objs.append(o)
        bpy.context.view_layer.update()
        lo, hi = bbox(objs)
        if x - lo.x > 120:
            x = 0.0; rowy -= 16.0
        off = Vector((x - lo.x, rowy, 0))
        for o in objs:
            o.location += off
        bpy.context.view_layer.update()
        pivots[name] = off.copy()
        x = bbox(objs)[1].x + 4.0
        placed[name] = objs
    return placed, pivots


def build_all():
    obs = [sofa_sectional(), armchair(), armchair("H_Armchair_Mustard", "tweed_mustard", "Variants1")]
    obs.append(bed("H_Bed_Double", 7.4, 10.0, "Beds", "walnut65", "chenille", "fab_chenille", ["linen_old", "linen_old"]))
    obs.append(bed("H_Bed_Single", 4.4, 8.6, "Beds", "maple", "spread", "fab_cowboy", ["linen_old"], maple=True))
    obs.append(bed("H_Bed_Double_Maple", 7.4, 10.0, "Variants1", "maple", "spread", "fab_plaid", ["linen_old", "linen_old"], maple=True))
    obs += [dresser(), dresser("H_Dresser_Credenza", "walnut65", "Variants2", "credenza"), dresser("H_Dresser_Phone", "walnut65", "Variants2", "phone"),
            dresser("H_Dresser_Maple", "maple", "Variants2", "lowboy"), dresser("H_Dresser_Cream", "paint_cream", "Variants2", "cream")]
    obs += [nightstand(), tv_console(), tv_console("H_TVConsole_Buffet", "buffet"), coffee_table(), side_table(), desk(), desk("H_Desk_School", "school"), desk_chair()]
    obs += [dining_table(), dining_chair(), table_setting(), bar_stool(), island(), fruit_bowl(), kitchen_base("plain"), kitchen_base("sink"),
            kitchen_base("hob"), kitchen_upper(), range_hood(), pantry()]
    obs += [fridge(), toaster(), percolator(), kettle(), washer()]
    obs += [bathtub(), bathtub("H_Bathtub_Butter", "tile_butter65", "ceramic_butter", "Variants3"), toilet(), toilet("H_Toilet_Butter", "ceramic_butter"),
            vanity(), vanity("H_Vanity_Butter", "enamel_butter", "ceramic_butter"), medicine_cabinet(), shower_set(), shower_curtain(), shower_flange(), towel_rail()]
    obs += bookcase() + bookcase("H_Bookcase_Hutch", "walnut65", "hutch", "Variants3") + bookcase("H_Bookcase_Maple", "maple", "open", "Variants3")
    obs += [wardrobe(), wardrobe("H_Wardrobe_Lockers", "paint_green", "lockers", "Variants4"), wardrobe("H_Wardrobe_Maple", "maple", "walnut", "Variants4"),
            wardrobe("H_Wardrobe_Cream", "paint_cream", "cream", "Variants4"), tall_cabinet(), tall_cabinet("H_TallCabinet_HallTree", "walnut65", "halltree", "Variants4")]
    obs += floor_lamp() + table_lamp() + pendant_globe() + pendant_sputnik() + portable_tv() + [typewriter()]
    obs += [frame("H_Frame_Abstract", 4.0, 4.0, G65 + "print_abstract", "walnut_trim"), frame("H_Frame_Landscape", 5.4, 3.6, G65 + "oil_desert"),
            frame("H_Frame_Botanical", 2.6, 3.4, G65 + "oil_flower"), frame("H_Frame_Geometric", 3.0, 3.0, G65 + "kid_rocket", "maple"),
            frame("H_Frame_Notice", 3.0, 3.0, FX + "notice_drill", "pine65"), frame("H_Frame_Pennant", 2.6, 3.4, FX + "pennant", "maple"),
            frame("H_Frame_Mesa", 5.4, 3.6, G65 + "oil_mesa")]
    obs += [rug("H_Rug_Living", 12.0, 8.0, FX + "fab_shag"), rug("H_Rug_Runner", 4.0, 10.0, FX + "fab_braid", oval=True),
            rug("H_Rug_Oval", 12.0, 8.0, FX + "fab_braid", oval=True)]
    obs += [plant_rubber(), plant_snake()] + toys()
    obs += shelf_wall() + [oven_wall(), spindle_screen(), headboard_wall(), kitchen_bench(), hall_bench("H_HallBench_3", 3.5, "phone"),
            hall_bench("H_HallBench_8", 8.0, "slat"), display_column()] + planter()
    # loose 1965 dressing (placed by build_house.py in plan coordinates)
    obs += [rotary_phone(), radio(), record_player(), papers(), broken_plates(), knocked_lamp(), knocked_chair(), sand_drift(),
            sand_drift("D65_SandDriftSmall", 2.4, 1.4), cobweb(), tin_rocket(), clipboard()] + canisters_cake()
    obs += [dummy("D65_Dummy_SitA", "sit", "cloth_cardigan", "cloth_skirt", skirt=True, num=1, seat_h=1.93, knee_dz=0.05),
            dummy("D65_Dummy_SitB", "sit", "cloth_suit", "cloth_suit", num=2, seat_h=1.87, knee_dz=-0.2),
            dummy("D65_Dummy_SitC", "sit", "cloth_shirt", "cloth_suit", num=3, seat_h=1.87, knee_dz=-0.2),
            dummy("D65_Dummy_SitD", "sit", "cloth_cardigan", "cloth_skirt", skirt=True, num=4, seat_h=2.1, knee_dz=0.0),
            dummy("D65_Dummy_SitE", "sit", "cloth_shirt", "cloth_skirt", skirt=True, num=6, seat_h=2.4, knee_dz=-0.4),
            dummy("D65_Dummy_Lean", "lean", "cloth_shirt", "cloth_suit", num=5)]
    obs += [wall_paper("D65_Poster_Travel", 2.4, 3.2, "poster_travel", curl=0.15), wall_paper("D65_Poster_Kitchen", 2.4, 3.2, "poster_kitchen"),
            wall_paper("D65_Calendar", 1.4, 2.1, "calendar_1965", curl=0.1), wall_paper("D65_Notice", 1.8, 1.8, "notice_drill"),
            wall_paper("D65_Pennant", 3.0, 1.5, "pennant")]
    obs += [drape("D65_Drape_Gold", "drape_gold", 8.0), drape("D65_Drape_Mustard", "drape_mustard", 8.0), drape("D65_Drape_Green", "drape_green", 8.0),
            drape_rod("D65_DrapeRod", 1.0)]
    return obs


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for d in (TEX, FBXD):
        os.makedirs(d, exist_ok=True)
    obs = build_all()
    by_name = {o.name: o for o in obs}
    x = 0.0
    for o in obs:
        lo, hi = bbox([o])
        o.location.x += x - lo.x
        o.location.y = 200.0
        bpy.context.view_layer.update()
        x = bbox([o])[1].x + 6.0
    log("built", len(obs), "masters", sum(tris(o) for o in obs), "tris")
    atl_files = {}
    if not NOBAKE:
        setup_cycles()
        groups = {}
        for o in obs:
            if str(o["atlas"]).startswith("Plain:"):
                continue
            groups.setdefault(o["atlas"], []).append(o)
        for atl, objs in groups.items():
            imgs = bake_atlas(atl, objs)
            finalize(objs, atlas_material(atl, imgs))
            atl_files[atl] = {p: f"tex/{PREFIX}{atl}_{p}.png" for p in imgs}
            bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    for o in obs:
        if str(o["atlas"]).startswith("Plain:"):
            me = o.data
            me.materials.clear()
            m = bpy.data.materials.get("H_Glass") or bpy.data.materials.new("H_Glass")
            m.diffuse_color = srgb((150, 170, 180))
            me.materials.append(m)
            for nm in [l.name for l in me.uv_layers if l.name != "UVMap"]:
                me.uv_layers.remove(me.uv_layers[nm])
    for o in obs:
        o.location = (0, 0, 0)
    asm = ASM + [(n, p, r, c, b) for (n, base, p, r, c, b) in VARIANTS] + [(d, [(d, (0, 0, 0), 0)], "1965 loose dressing (placed by build_house.py)", NONE, []) for d in D65]
    placed, pivots = layout(by_name, asm)
    cube, mk = scale_cube_marker()
    cube.location = (0, 40, 5); mk.location = (8, 40, 0)
    hm = human(); hu = hcore.finish(hm)
    for c in hu.users_collection:
        c.objects.unlink(hu)
    coll("Reference").objects.link(hu); hu.location = (-6, 40, 0); hu.hide_render = True
    for c in list(bpy.data.collections):
        if c.name == "Masters" and not c.objects:
            bpy.data.collections.remove(c)
    bpy.context.view_layer.update()
    base_of = {n: b for (n, b, *_r) in VARIANTS}
    manifest = []
    for name, parts, role, cover, boxes in asm:
        objs = placed[name]
        piv = pivots[name]
        lo, hi = bbox(objs)
        e = dict(assembly=name, role=role, cover=cover, objects=[o.name for o in objs], fbx=f"fbx/{name}.fbx")
        if name in base_of:
            e["variant_of"] = base_of[name]
        if name.startswith("D65_"):
            e["dressing_1965"] = True
        if len(boxes) == 1 and name not in ("H_DiningSet",):
            (bl, bh) = boxes[0]
            boxes = [((lo.x - piv.x, lo.y - piv.y, bl[2]), (hi.x - piv.x, hi.y - piv.y, bh[2]))]
            if name in ("H_KitchenSink", "H_Bathtub", "H_Bathtub_Butter", "H_TVConsole_WithTV", "H_Planter"):
                e["above_box"] = "thin tap / the TV / the plant stands above the 3.4 box: no collision needed"
        if boxes:
            ul = Vector([min(Vector(b[0])[i] for b in boxes) for i in range(3)]); uh = Vector([max(Vector(b[1])[i] for b in boxes) for i in range(3)])
            c = Vector(((ul.x + uh.x) / 2, (ul.y + uh.y) / 2, 0.0))
            if c.length > 1e-4:
                piv = piv + c
                pivots[name] = piv
                o0 = objs[0]
                if o0.data.users > 1:
                    o0.data = o0.data.copy()
                local = o0.matrix_world.inverted().to_3x3() @ c
                o0.data.transform(Matrix.Translation(-local))
                o0.location += c
                bpy.context.view_layer.update()
                boxes = [(tuple(Vector(b0) - c), tuple(Vector(b1) - c)) for (b0, b1) in boxes]
        e["size_studio"] = studio_size(hi - lo)
        a_, b_ = studio(lo - piv), studio(hi - piv)
        e["bbox_min_rel_pivot_studio"] = [min(p, q) for p, q in zip(a_, b_)]
        e["bbox_max_rel_pivot_studio"] = [max(p, q) for p, q in zip(a_, b_)]
        e["pivot_blender_in_kit"] = [round(v, 3) for v in piv]
        e["collision_boxes_studio"] = []
        for (bl, bh) in boxes:
            bl, bh = Vector(bl), Vector(bh)
            e["collision_boxes_studio"].append(dict(size=studio_size(bh - bl), centre_rel_pivot=studio((bl + bh) / 2)))
        e["parts"] = []
        for o in objs:
            l2, h2 = bbox([o])
            e["parts"].append(dict(object=o.name, mesh=o.data.name, atlas=o.get("atlas"), tris=tris(o),
                                   centre_studio_rel_pivot=studio((l2 + h2) / 2 - piv), size_studio=studio_size(h2 - l2),
                                   rot_z_deg=round(math.degrees(o.rotation_euler.z), 1)))
        e["tris"] = sum(p["tris"] for p in e["parts"])
        e["textures"] = sorted({f for o in objs for f in atl_files.get(o.get("atlas"), {}).values()})
        if boxes:
            ul = Vector([min(Vector(b[0])[i] for b in boxes) for i in range(3)]); uh = Vector([max(Vector(b[1])[i] for b in boxes) for i in range(3)])
            over = max(max((ul - (lo - piv))[i], ((hi - piv) - uh)[i]) for i in range(3 if "above_box" not in e else 2))
            e["art_outside_box"] = round(max(0.0, over), 3)
        manifest.append(e)
    allobjs = [o for objs in placed.values() for o in objs]
    if not NOBAKE:
        kit_objs = [o for n, objs in placed.items() if not n.startswith("D65_") for o in objs]
        export_fbx(os.path.join(FBXD, "H_Furniture_kit.fbx"), kit_objs + [cube, mk])
        for e in manifest:
            if e["assembly"].startswith("D65_"):
                continue
            objs = placed[e["assembly"]]
            off = pivots[e["assembly"]]
            for o in objs:
                o.location -= off
            bpy.context.view_layer.update()
            export_fbx(os.path.join(FBXD, e["assembly"] + ".fbx"), objs)
            for o in objs:
                o.location += off
        bpy.context.view_layer.update()
    man = dict(note="1965 test-site restyle. Blender (x, y, z) -> Studio (-x, z, y). 1 unit = 1 stud. Pivot = bottom centre of the "
                    "collision box. Kit FBX has K_ScaleCube (10 studs) and K_Marker. Every visual mesh: CanCollide/CanQuery/CanTouch off; "
                    "collision = the listed boxes (v1's, unchanged). Variants share their base's box; D65_* are placed by build_house.py.",
               cover_heights=dict(low=3.4, tall="8.0", source="notes/warehouse_study/movement_configs.txt CoverConfig"),
               variant_map=VARIANT_MAP, atlases=atl_files, assemblies=manifest, unique_tris=sum(tris(o) for o in obs))
    json.dump(man, open(os.path.join(ROOT, "house_furniture.json"), "w"), indent=1)
    json.dump(dict(note="Optional room looks: layout furniture/dressing id -> 1965 variant asset (same box and size as the base "
                        "name). Without this map every base name still works.", map=VARIANT_MAP),
              open(os.path.join(ROOT, "house_1965_variants.json"), "w"), indent=1)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    bpy.ops.file.make_paths_relative(); bpy.ops.wm.save_mainfile()
    log("DONE", len(allobjs), "objects;", man["unique_tris"], "unique tris")


if __name__ == "__main__":
    main()

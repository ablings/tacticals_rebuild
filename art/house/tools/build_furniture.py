"""House map, PART A: modern furniture (cover at the game's cover heights) and dressing. One run rebuilds everything:
  "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup --python art/house/tools/build_furniture.py -- [--nobake] [--res 1024] [--samples 16] [--device CUDA]

Cover heights (notes/warehouse_study/movement_configs.txt, CoverConfig + Warehouse 2 cover boxes): LOW cover = 3.4 tall
(the waist ray at root-0.5 hits, the head ray at root+1.5 passes over), TALL cover = 7+ (both rays hit).
Every cover piece's art stays inside its collision box; the box's bottom centre is the pivot (Blender origin).
1 unit = 1 stud, Z up, front = Blender -Y. Blender (x, y, z) -> Studio (-x, z, y).
Writes art/house/house_furniture.blend, tex/H_<atlas>_{color,normal,rough,metal}.png, fbx/H_Furniture_kit.fbx (+ one FBX
per assembly, pivot at the origin), house_furniture.json (sizes, pivots, parts, tris, collision boxes)."""
import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hcore import *          # noqa: F401,F403
import hcore

BLEND = os.path.join(ROOT, "house_furniture.blend")

# extra kinds used only here
for k_, v_ in {
    "oak_slat": dict(under=(178, 144, 104), wood=True, groove=True, stain=0.12, rough=0.55, mottle=0.08),
    "walnut_slat": dict(under=(104, 72, 50), wood=True, groove=True, stain=0.15, rough=0.5, mottle=0.1),
    "book_navy": dict(paint=(46, 58, 82), rough=0.7), "book_cream": dict(paint=(214, 206, 186), rough=0.75),
    "book_rust": dict(paint=(128, 66, 48), rough=0.7), "book_slate": dict(paint=(96, 108, 116), rough=0.7),
    "book_char": dict(paint=(48, 48, 50), rough=0.7), "book_sage": dict(paint=(124, 132, 110), rough=0.7),
    "book_wine": dict(paint=(98, 40, 46), rough=0.7),
}.items():
    d_ = dict(DEF); d_.update(v_); K[k_] = d_

ROT = lambda deg, ax="X": Matrix.Rotation(math.radians(deg), 4, ax)


def xf(fs, M):
    """transform the verts of the faces a primitive returned (lean a cushion, tilt a pillow)"""
    vs = {v for f in fs for v in f.verts}
    for v in vs:
        v.co = M @ v.co
    for f in fs:
        f.normal_update()
    return fs


def about(p, M):
    p = Vector(p)
    return Matrix.Translation(p) @ M @ Matrix.Translation(-p)


# =========================================================================================================== LOW COVER
def sofa_sectional():
    """L sectional: 12 wide, back 3.4 (low cover), chaise on the right reaching 5.4 forward. Recessed black plinth, no gap
    under it (solid cover)."""
    mb = MB("H_Sofa_Sectional", "Sofa", 3.4)
    F = "fabric_grey"
    mb.boxr((-5.7, -1.55, 0), (5.7, 1.6, 0.42), "plinth")
    mb.boxr((2.45, -5.15, 0), (5.7, -1.4, 0.42), "plinth")
    rbox(mb, (-5.2, -1.8, 0.35), (5.2, 0.9, 1.3), F, r=0.12)
    rbox(mb, (2.2, -5.4, 0.35), (5.2, -1.6, 1.3), F, r=0.12)
    rbox(mb, (-6.0, 0.75, 0.35), (6.0, 1.8, 3.4), F, r=0.25, segs=3)
    rbox(mb, (-6.0, -1.8, 0.35), (-5.05, 1.8, 2.6), F, r=0.25, segs=3)
    rbox(mb, (5.05, -5.4, 0.35), (6.0, 1.8, 2.6), F, r=0.25, segs=3)
    rbox(mb, (-5.1, -1.75, 1.22), (-1.5, 0.85, 1.8), F, r=0.2, segs=3)
    rbox(mb, (-1.55, -1.75, 1.22), (2.25, 0.85, 1.8), F, r=0.2, segs=3)
    rbox(mb, (2.2, -5.35, 1.22), (5.1, 0.85, 1.8), F, r=0.2, segs=3)
    for x0, x1 in ((-5.05, -1.65), (-1.7, 1.7), (1.65, 5.05)):
        xf(rbox(mb, (x0, 0.15, 1.7), (x1, 0.95, 3.15), F, r=0.25, segs=3), about((0, 0.55, 1.7), ROT(10)))
    xf(rbox(mb, (-0.75, -0.22, 0), (0.75, 0.22, 1.5), "fabric_sage", r=0.2, segs=3), Matrix.Translation((-4.4, 0.05, 1.75)) @ ROT(12) @ ROT(18, "Z"))
    xf(rbox(mb, (-0.75, -0.22, 0), (0.75, 0.22, 1.5), "fabric_cream", r=0.2, segs=3), Matrix.Translation((4.3, 0.05, 1.75)) @ ROT(12) @ ROT(-16, "Z"))
    return finish(mb)


def armchair():
    mb = MB("H_Armchair", "Sofa", 3.4)
    L = "leather_brown"
    mb.boxr((-1.8, -1.7, 0), (1.8, 1.75, 0.38), "walnut")
    rbox(mb, (-1.45, -2.0, 0.3), (1.45, 1.2, 1.3), L, r=0.12)
    rbox(mb, (-2.1, -2.0, 0.3), (-1.35, 2.0, 2.5), L, r=0.25, segs=3)
    rbox(mb, (1.35, -2.0, 0.3), (2.1, 2.0, 2.5), L, r=0.25, segs=3)
    rbox(mb, (-2.1, 1.0, 0.3), (2.1, 2.0, 3.4), L, r=0.3, segs=3)
    rbox(mb, (-1.42, -1.95, 1.22), (1.42, 1.1, 1.78), L, r=0.2, segs=3)
    xf(rbox(mb, (-1.4, 0.35, 1.7), (1.4, 1.1, 3.15), L, r=0.25, segs=3), about((0, 0.7, 1.7), ROT(9)))
    return finish(mb)


def bed(name, W, L, frame, head, duvet, throw, pillows, atlas="Beds"):
    """platform bed, foot at -Y, head at +Y: solid upholstered base (no gap under it), headboard 3.4 (low cover)."""
    mb = MB(name, atlas, 3.4)
    y0, y1 = -L / 2, L / 2
    rbox(mb, (-W / 2, y0, 0), (W / 2, y1 - 0.45, 1.3), frame, r=0.12)
    if head in ("oak", "walnut"):
        mb.boxr((-W / 2 - 0.15, y1 - 0.55, 0), (W / 2 + 0.15, y1, 3.4), head)
    else:
        rbox(mb, (-W / 2 - 0.15, y1 - 0.6, 0), (W / 2 + 0.15, y1, 3.4), head, r=0.22, segs=3)
    rbox(mb, (-W / 2 + 0.12, y0 + 0.12, 1.22), (W / 2 - 0.12, y1 - 0.5, 2.15), "linen_white", r=0.2, segs=2)
    rbox(mb, (-W / 2 + 0.02, y0 + 0.02, 1.62), (W / 2 - 0.02, y1 - 2.5, 2.3), duvet, r=0.18, segs=3)
    rbox(mb, (-W / 2 + 0.0, y1 - 2.85, 1.7), (W / 2 - 0.0, y1 - 2.2, 2.46), duvet, r=0.2, segs=3)   # folded-back edge
    rbox(mb, (-W / 2 - 0.04, y0 + 0.35, 1.5), (W / 2 + 0.04, y0 + 1.75, 2.38), throw, r=0.12, segs=2)  # throw over the foot
    n = len(pillows)
    pw = (W - 0.6) / n
    for i, k in enumerate(pillows):
        cx = -W / 2 + 0.3 + pw * (i + 0.5)
        xf(rbox(mb, (-pw / 2 + 0.06, -0.55, 0), (pw / 2 - 0.06, 0.55, 0.7), k, r=0.28, segs=3),
           Matrix.Translation((cx, y1 - 1.25, 2.02)) @ ROT(-14))
    return finish(mb)


def dresser():
    mb = MB("H_Dresser", "WoodA", 3.4)
    mb.boxr((-3.0, -1.05, 0.3), (3.0, 1.1, 3.4), "walnut")
    mb.boxr((-2.85, -0.9, 0), (2.85, 1.0, 0.36), "plinth")
    for (x0, x1) in ((-2.95, -0.02), (0.02, 2.95)):
        for (z0, z1) in ((0.36, 1.36), (1.38, 2.38), (2.4, 3.36)):
            mb.boxr((x0 + 0.03, -1.12, z0 + 0.03), (x1 - 0.03, -1.0, z1 - 0.03), "walnut")
            cx = (x0 + x1) / 2
            mb.boxr((cx - 0.55, -1.2, z1 - 0.34), (cx + 0.55, -1.1, z1 - 0.24), "black_metal")
    return finish(mb)


def nightstand():
    mb = MB("H_Nightstand", "WoodA", 2.0)
    mb.boxr((-1.1, -0.95, 0.3), (1.1, 0.95, 2.0), "walnut")
    mb.boxr((-0.95, -0.8, 0), (0.95, 0.85, 0.36), "plinth")
    for (z0, z1) in ((0.34, 1.16), (1.18, 1.97)):
        mb.boxr((-1.06, -1.02, z0 + 0.03), (1.06, -0.9, z1 - 0.03), "walnut")
        mb.boxr((-0.4, -1.1, z1 - 0.3), (0.4, -1.0, z1 - 0.22), "black_metal")
    return finish(mb)


def tv_console():
    """media sideboard 8 x 3.4 x 2 (low cover), slatted oak doors, the TV stands on it"""
    mb = MB("H_TVConsole", "WoodA", 3.4)
    mb.boxr((-4.0, -0.95, 0.35), (4.0, 1.0, 3.4), "walnut")
    mb.boxr((-3.85, -0.8, 0), (3.85, 0.9, 0.4), "plinth")
    xs = [-3.97, -1.99, 0.0, 1.99, 3.97]
    for x0, x1 in zip(xs, xs[1:]):
        mb.boxr((x0 + 0.02, -1.02, 0.42), (x1 - 0.02, -0.9, 3.0), "oak_slat", grain=2)
    mb.boxr((-3.97, -1.02, 3.04), (3.97, -0.9, 3.36), "walnut")      # top drawer band
    return finish(mb)


def coffee_table():
    mb = MB("H_CoffeeTable", "WoodA", 1.4)
    rbox(mb, (-2.5, -1.4, 1.2), (2.5, 1.4, 1.42), "oak", r=0.08)
    for sx in (-1, 1):
        for sy in (-1, 1):
            mb.boxr((sx * 2.2 - 0.09, sy * 1.1 - 0.09, 0), (sx * 2.2 + 0.09, sy * 1.1 + 0.09, 1.25), "black_metal")
    mb.boxr((-2.3, -1.2, 0.35), (2.3, 1.2, 0.47), "walnut")
    # a stack of 2 books and a bowl on top
    mb.boxr((-1.6, -0.6, 1.4), (-0.4, 0.3, 1.55), "book_slate"); mb.boxr((-1.5, -0.5, 1.53), (-0.5, 0.2, 1.66), "book_cream")
    mb.lathe([(0, 1.4), (0.35, 1.4), (0.6, 1.62), (0.55, 1.64), (0.3, 1.47), (0, 1.47)], 16, "ceramic", M=Matrix.Translation((1.2, 0.1, 0)))
    return finish(mb)


def side_table():
    mb = MB("H_SideTable", "WoodA", 2.2)
    mb.lathe([(0, 0), (0.6, 0), (0.6, 0.08), (0.14, 0.12), (0.12, 2.0), (0.9, 2.02), (0.9, 2.14), (0, 2.14)], 20, "walnut")
    return finish(mb)


def desk():
    mb = MB("H_Desk", "WoodA", 2.6)
    mb.boxr((-2.5, -1.2, 2.45), (2.5, 1.2, 2.62), "oak")
    mb.boxr((0.9, -1.1, 0), (2.4, 1.1, 2.48), "lacquer_white")
    for z0, z1 in ((0.05, 1.2), (1.24, 1.82), (1.86, 2.42)):
        mb.boxr((0.94, -1.17, z0), (2.36, -1.05, z1), "lacquer_white")
        mb.boxr((1.35, -1.24, z1 - 0.2), (1.95, -1.12, z1 - 0.12), "oak")
    mb.boxr((-2.4, -1.05, 0), (-2.25, 1.05, 2.48), "black_metal")
    mb.boxr((-2.4, 0.9, 1.9), (1.0, 1.05, 2.48), "black_metal")      # modesty rail at the back
    return finish(mb)


def desk_chair():
    mb = MB("H_DeskChair", "WoodA", 3.6)
    for i in range(5):
        a = 2 * math.pi * i / 5 + math.pi / 2
        d = Vector((math.cos(a), math.sin(a), 0))
        mb.tube([(0, 0, 0.32), (d.x * 1.0, d.y * 1.0, 0.24)], 0.08, "black_metal", segs=6)
        mb.lathe([(0, 0.0), (0.12, 0.0), (0.14, 0.08), (0.12, 0.16), (0, 0.16)], 8, "rubber", M=Matrix.Translation((d.x * 1.0, d.y * 1.0, 0)))
    mb.lathe([(0, 0.24), (0.12, 0.24), (0.1, 1.35), (0, 1.35)], 10, "steel")
    rbox(mb, (-0.95, -0.95, 1.3), (0.95, 0.85, 1.65), "fabric_charcoal", r=0.15)
    mb.boxr((-0.12, 0.6, 1.4), (0.12, 0.95, 2.2), "black_metal")
    xf(rbox(mb, (-0.85, 0.8, 2.0), (0.85, 1.05, 3.6), "fabric_charcoal", r=0.12), about((0, 0.9, 2.0), ROT(8)))
    return finish(mb)


# --- dining
def dining_table():
    """oak top on two solid slab legs; 2.6 tall (the chairs' backs reach 3.4)"""
    mb = MB("H_DiningTable", "Dining", 2.6)
    rbox(mb, (-4.0, -2.0, 2.32), (4.0, 2.0, 2.6), "oak", r=0.06)
    for sx in (-1, 1):
        mb.boxr((sx * 3.15 - 0.17, -1.5, 0), (sx * 3.15 + 0.17, 1.5, 2.35), "oak")
    mb.boxr((-3.0, -0.12, 1.85), (3.0, 0.12, 2.35), "oak")             # stretcher under the top
    return finish(mb)


def dining_chair():
    """upholstered dining chair, back 3.4; front = -Y (the seat faces the table at +Y when turned 180)"""
    mb = MB("H_DiningChair", "Dining", 3.4)
    for sx in (-1, 1):
        for sy in (-1, 1):
            mb.boxr((sx * 0.78 - 0.07, sy * 0.78 - 0.07, 0), (sx * 0.78 + 0.07, sy * 0.78 + 0.07, 1.42), "walnut")
    rbox(mb, (-0.95, -0.95, 1.35), (0.95, 0.95, 1.72), "fabric_cream", r=0.12)
    xf(rbox(mb, (-0.95, 0.72, 1.62), (0.95, 1.0, 3.4), "fabric_cream", r=0.12), about((0, 0.86, 1.62), ROT(6)))
    for sx in (-1, 1):   # rear legs run up into the back
        mb.boxr((sx * 0.78 - 0.07, 0.78 - 0.07, 1.4), (sx * 0.78 + 0.07, 0.78 + 0.07, 1.7), "walnut")
    return finish(mb)


def bar_stool():
    mb = MB("H_BarStool", "Kitchen", 2.6)
    mb.lathe([(0, 2.28), (0.7, 2.28), (0.74, 2.42), (0.68, 2.6), (0, 2.6)], 20, "leather_black")
    for i in range(4):
        a = math.pi / 4 + i * math.pi / 2
        mb.tube([(0.42 * math.cos(a), 0.42 * math.sin(a), 2.3), (0.62 * math.cos(a), 0.62 * math.sin(a), 0.0)], 0.06, "black_metal", segs=6)
    mb.revolve([(0.56, 0.8), (0.6, 0.8), (0.6, 0.86), (0.56, 0.86)], 16, "black_metal")
    return finish(mb)


# --- kitchen
def island():
    """10 x 3.4 x 4.6 island (low cover): slate-blue drawers, quartz top with waterfall ends, seating overhang at +Y"""
    mb = MB("H_KitchenIsland", "Kitchen", 3.4)
    mb.boxr((-4.72, -2.22, 0.35), (4.72, 1.3, 3.12), "lacquer_slate")
    mb.boxr((-4.6, -2.0, 0), (4.6, 1.15, 0.4), "plinth")
    mb.boxr((-5.0, -2.3, 3.08), (5.0, 2.3, 3.4), "quartz")
    for sx in (-1, 1):
        mb.boxr((sx * 4.84 - 0.16, -2.3, 0), (sx * 4.84 + 0.16, 2.3, 3.12), "quartz")
    xs = [-4.68, -1.56, 1.56, 4.68]
    for x0, x1 in zip(xs, xs[1:]):
        for z0, z1 in ((0.42, 2.12), (2.14, 3.06)):
            mb.boxr((x0 + 0.03, -2.3, z0 + 0.02), (x1 - 0.03, -2.18, z1 - 0.02), "lacquer_slate")
            cx = (x0 + x1) / 2
            mb.boxr((cx - 0.7, -2.38, z1 - 0.3), (cx + 0.7, -2.26, z1 - 0.2), "black_metal")
    return finish(mb)


def fruit_bowl():
    mb = MB("H_FruitBowl", "Kitchen", 0.6)
    mb.lathe([(0, 0), (0.45, 0), (0.75, 0.32), (0.7, 0.34), (0.4, 0.07), (0, 0.07)], 18, "ceramic")
    for (dx, dy, dz) in ((0.2, 0.1, 0.24), (-0.2, 0.15, 0.24), (0.0, -0.22, 0.26), (0.05, 0.05, 0.47)):
        ellipsoid(mb, (dx, dy, dz), (0.2, 0.2, 0.19), "fruit", segs=7, rings=4)
    return finish(mb)


def counter_with_hole(mb, hx, hy, cx=0.0, cy=0.0):
    """4 x 2.4 counter top 3.1-3.4 with a rectangular hole (sink / hob cut-out) centred at (cx, cy)"""
    X0, X1, Y0, Y1, z0, z1 = -2.0, 2.0, -1.25, 1.2, 3.1, 3.4
    mb.boxr((X0, Y0, z0), (X1, cy - hy, z1), "quartz")
    mb.boxr((X0, cy + hy, z0), (X1, Y1, z1), "quartz")
    mb.boxr((X0, cy - hy - 0.02, z0), (cx - hx, cy + hy + 0.02, z1), "quartz")
    mb.boxr((cx + hx, cy - hy - 0.02, z0), (X1, cy + hy + 0.02, z1), "quartz")


def kitchen_base(kind):
    """4 x 3.4 x 2.4 wall-run module (low cover against a wall). kind: plain / sink / hob. Front = -Y, wall at +Y."""
    name = {"plain": "H_KitchenBase", "sink": "H_KitchenSink", "hob": "H_KitchenHob"}[kind]
    mb = MB(name, "Kitchen", 3.4)
    mb.boxr((-2.0, -1.1, 0.35), (2.0, 1.2, 3.12), "lacquer_white")
    mb.boxr((-2.0, -0.9, 0), (2.0, 1.2, 0.4), "plinth")
    if kind == "sink":
        counter_with_hole(mb, 1.3, 0.78, 0.0, -0.05)
        A, B = 1.45, 0.86
        sq_lathe(mb, [(0, 2.73), (0.86, 2.73), (0.88, 3.39), (1.0, 3.39), (1.0, 3.43), (0.92, 3.43), (0.86, 2.79), (0, 2.79)],
                 A, B, "steel", n=6, segs=32, M=Matrix.Translation((0, -0.05, 0)))
        mb.tube([(0, 0.95, 3.38), (0, 0.95, 4.6), (0, 0.75, 4.95), (0, 0.45, 4.95), (0, 0.3, 4.6)], 0.07, "chrome", segs=8)
        mb.lathe([(0, 3.38), (0.17, 3.38), (0.15, 3.6), (0, 3.6)], 10, "chrome", M=Matrix.Translation((0, 0.95, 0)))
        mb.boxr((0.35, 0.9, 3.95), (0.65, 1.0, 4.05), "chrome")
        fronts = [((-1.98, 0.42), (-0.01, 3.06)), ((0.01, 0.42), (1.98, 3.06))]
    elif kind == "hob":   # hob glass fills a cut-out flush with the counter (stays inside the 3.4 cover)
        counter_with_hole(mb, 1.5, 0.95, 0.0, 0.0)
        mb.boxr((-1.5, -0.95, 3.12), (1.5, 0.95, 3.4), "glass_dark")
        fronts = [((-1.98, 2.5), (1.98, 3.06)), ((-1.98, 0.42), (-0.01, 2.46)), ((0.01, 0.42), (1.98, 2.46))]
    else:
        mb.boxr((-2.0, -1.25, 3.1), (2.0, 1.2, 3.4), "quartz")
        fronts = [((-1.98, 2.5), (1.98, 3.06)), ((-1.98, 0.42), (-0.01, 2.46)), ((0.01, 0.42), (1.98, 2.46))]
    if kind == "hob":
        fronts = [((-1.98, 2.5), (1.98, 3.06)), ((-1.98, 0.42), (1.98, 2.46))]
    for (x0, z0), (x1, z1) in fronts:
        door = (x1 - x0) < 2.5 and (z1 - z0) > 1.0
        if kind == "hob" and z1 < 2.5:   # oven: dark glass door, steel handle
            mb.boxr((x0 + 0.02, -1.18, z0 + 0.02), (x1 - 0.02, -1.06, z1 - 0.02), "steel")
            mb.boxr((x0 + 0.3, -1.22, z0 + 0.3), (x1 - 0.3, -1.12, z1 - 0.5), "glass_dark")
            mb.tube([(x0 + 0.4, -1.32, z1 - 0.25), (x1 - 0.4, -1.32, z1 - 0.25)], 0.06, "steel", segs=8)
            mb.boxr((x0 + 0.38, -1.3, z1 - 0.3), (x0 + 0.46, -1.12, z1 - 0.2), "steel")
            mb.boxr((x1 - 0.46, -1.3, z1 - 0.3), (x1 - 0.38, -1.12, z1 - 0.2), "steel")
            continue
        mb.boxr((x0 + 0.02, -1.18, z0 + 0.02), (x1 - 0.02, -1.06, z1 - 0.02), "lacquer_white")
        if door:   # vertical bar by the inner edge
            hx = x1 - 0.3 if x0 < -0.5 else x0 + 0.3
            mb.boxr((hx - 0.05, -1.26, z1 - 1.0), (hx + 0.05, -1.14, z1 - 0.2), "black_metal")
        else:
            cx = (x0 + x1) / 2
            mb.boxr((cx - 0.6, -1.26, z1 - 0.28), (cx + 0.6, -1.14, z1 - 0.18), "black_metal")
    return finish(mb)


def kitchen_upper():
    """4 x 2.6 x 1.3 wall cabinet: hang its bottom 5.8 above the floor (2.4 above the counter)"""
    mb = MB("H_KitchenUpper", "Kitchen", 2.6)
    mb.boxr((-2.0, -0.55, 0.0), (2.0, 0.75, 2.6), "lacquer_white")
    for x0, x1 in ((-1.98, -0.01), (0.01, 1.98)):
        mb.boxr((x0 + 0.02, -0.62, 0.02), (x1 - 0.02, -0.5, 2.58), "lacquer_white")
        hx = x1 - 0.3 if x0 < -0.5 else x0 + 0.3
        mb.boxr((hx - 0.05, -0.7, 0.15), (hx + 0.05, -0.58, 0.85), "black_metal")
    return finish(mb)


def range_hood():
    mb = MB("H_RangeHood", "Kitchen", 3.4)
    mb.prism([(-1.6, 0.0), (1.6, 0.0), (1.6, 0.25), (0.6, 1.0), (-0.6, 1.0), (-1.6, 0.25)], "Y", -0.9, 0.75, "steel")
    mb.boxr((-0.55, -0.4, 0.95), (0.55, 0.75, 3.4), "steel")
    mb.boxr((-1.5, -0.8, -0.04), (1.5, 0.65, 0.02), "black_metal")
    return finish(mb)


def pantry():
    """tall pantry 4 x 7.6 x 2.4 (tall cover) matching the white wall runs"""
    mb = MB("H_Pantry", "Kitchen", 7.6)
    mb.boxr((-2.0, -1.1, 0.35), (2.0, 1.2, 7.6), "lacquer_white")
    mb.boxr((-2.0, -0.9, 0), (2.0, 1.2, 0.4), "plinth")
    for x0, x1 in ((-1.98, -0.01), (0.01, 1.98)):
        for z0, z1 in ((0.42, 4.6), (4.64, 7.56)):
            mb.boxr((x0 + 0.02, -1.18, z0 + 0.02), (x1 - 0.02, -1.06, z1 - 0.02), "lacquer_white")
        hx = x1 - 0.3 if x0 < -0.5 else x0 + 0.3
        mb.boxr((hx - 0.05, -1.26, 3.2), (hx + 0.05, -1.14, 5.8), "black_metal")
    zstretch(mb, 7.6, 8.0)
    return finish(mb)


# --- appliances
def fridge():
    """French-door fridge 3.6 x 7.2 x 2.6 (tall cover), a kid's drawing under a magnet on the left door"""
    mb = MB("H_Fridge", "Appliances", 7.2)
    rbox(mb, (-1.8, -1.15, 0.0), (1.8, 1.3, 7.2), "steel", r=0.08)
    mb.boxr((-1.75, -1.2, 0.0), (1.75, -1.1, 0.35), "plastic_black")
    for x0, x1 in ((-1.78, -0.02), (0.02, 1.78)):
        rbox(mb, (x0, -1.3, 2.62), (x1, -1.1, 7.15), "steel", r=0.05)
    rbox(mb, (-1.78, -1.3, 0.38), (1.78, -1.1, 2.58), "steel", r=0.05)
    for hx in (-0.18, 0.18):
        mb.tube([(hx, -1.28, 3.6), (hx, -1.5, 3.7), (hx, -1.5, 6.1), (hx, -1.28, 6.2)], 0.055, "chrome", segs=8)
    mb.tube([(-1.0, -1.28, 2.25), (-1.0, -1.5, 2.2), (1.0, -1.5, 2.2), (1.0, -1.28, 2.25)], 0.055, "chrome", segs=8)
    mb.boxr((-1.35, -1.33, 4.0), (-0.5, -1.29, 5.1), "paper")                     # the drawing (decal below)
    mb.decal("gen/kid_drawing", (0, -1, 0), (-0.925, -1.33, 4.55), 0.85, 0.85, col=None, op=1.0, kinds=["paper"], depth=0.05)
    mb.lathe([(0, -1.37), (0.08, -1.37), (0.08, -1.31), (0, -1.31)], 8, "toy_red", M=Matrix.Translation((-0.925, 0, 5.0)) @ ROT(-90))
    zstretch(mb, 7.2, 8.0)
    return finish(mb)


def microwave():
    mb = MB("H_Microwave", "Appliances", 1.1)
    rbox(mb, (-0.95, -0.65, 0), (0.95, 0.65, 1.1), "steel", r=0.05)
    mb.boxr((-0.9, -0.71, 0.08), (0.45, -0.62, 1.02), "glass_dark")
    mb.boxr((0.5, -0.69, 0.1), (0.9, -0.62, 1.0), "plastic_black")
    return finish(mb)


def coffee_machine():
    mb = MB("H_CoffeeMachine", "Appliances", 1.3)
    rbox(mb, (-0.45, -0.55, 0), (0.45, 0.6, 1.3), "plastic_black", r=0.06)
    mb.boxr((-0.38, -0.85, 0.0), (0.38, -0.5, 0.1), "steel")
    mb.boxr((-0.3, -0.9, 0.9), (0.3, -0.5, 1.1), "steel")
    mb.lathe([(0, 0.1), (0.13, 0.1), (0.15, 0.32), (0, 0.32)], 12, "ceramic", M=Matrix.Translation((0, -0.68, 0)))
    return finish(mb)


def kettle():
    mb = MB("H_Kettle", "Appliances", 1.0)
    mb.lathe([(0, 0), (0.3, 0), (0.36, 0.06), (0.37, 0.05), (0.32, 0.7), (0.2, 0.8), (0, 0.82)], 16, "steel", M=Matrix.Translation((0, 0, 0.08)))
    mb.lathe([(0, 0), (0.4, 0), (0.4, 0.09), (0, 0.09)], 16, "plastic_black")
    mb.tube([(0.0, 0.27, 0.78), (0.0, 0.45, 0.9), (0.0, 0.48, 0.55), (0.0, 0.33, 0.28)], 0.05, "plastic_black", segs=6)
    mb.tube([(0.0, -0.3, 0.35), (0.0, -0.48, 0.7)], 0.06, "steel", segs=6)
    return finish(mb)


def washing_machine():
    mb = MB("H_WashingMachine", "Appliances", 3.0)
    rbox(mb, (-1.3, -1.2, 0), (1.3, 1.2, 3.0), "plastic_white", r=0.08)
    mb.boxr((-1.25, -1.24, 2.45), (1.25, -1.15, 2.92), "plastic_grey")
    M = Matrix.Translation((0, -1.18, 1.35)) @ ROT(90)
    mb.revolve([(0.72, -0.05), (0.92, -0.05), (0.92, 0.1), (0.72, 0.1)], 24, "chrome", M=M)
    mb.lathe([(0, -0.02), (0.75, -0.02), (0.75, 0.04), (0, 0.04)], 24, "glass_dark", M=M)
    mb.lathe([(0, 0), (0.1, 0), (0.1, 0.1), (0, 0.1)], 12, "chrome", M=Matrix.Translation((0.8, -1.22, 2.68)) @ ROT(90))
    return finish(mb)


# --- bathroom
def bathtub():
    """oval soaking tub on a tiled plinth: rim at 3.4 (low cover), 7 x 3.4 x 3.6"""
    mb = MB("H_Bathtub", "Bath", 3.4)
    mb.boxr((-3.5, -1.8, 0), (3.5, 1.8, 0.82), "tile_grey")
    sq_lathe(mb, [(0, 0.78), (0.9, 0.78), (0.97, 2.4), (1.0, 3.32), (0.99, 3.4), (0.93, 3.4), (0.91, 3.3), (0.86, 1.6),
                  (0.6, 1.36), (0, 1.36)], 3.0, 1.5, "ceramic", n=3.2, segs=40)
    mb.tube([(-3.3, 0.0, 0.8), (-3.3, 0.0, 3.85), (-3.2, 0.0, 4.05), (-2.95, 0.0, 4.05), (-2.85, 0.0, 3.85)], 0.08, "chrome", segs=8)
    mb.lathe([(0, 0.8), (0.18, 0.8), (0.15, 0.95), (0, 0.95)], 10, "chrome", M=Matrix.Translation((-3.3, 0, 0)))
    return finish(mb)


def toilet():
    mb = MB("H_Toilet", "Bath", 2.6)
    sq_lathe(mb, [(0, 0), (0.62, 0), (0.7, 0.9), (0.96, 1.25), (1.0, 1.42), (0.86, 1.42), (0.6, 1.0), (0, 1.0)], 0.75, 1.0, "ceramic", n=2.6, segs=28,
             M=Matrix.Translation((0, -0.2, 0)))
    rbox(mb, (-0.85, -1.25, 1.4), (0.85, 0.85, 1.52), "ceramic", r=0.05)          # lid
    rbox(mb, (-0.95, 0.65, 0.9), (0.95, 1.25, 2.6), "ceramic", r=0.08)            # cistern
    mb.boxr((-0.18, 0.62, 2.58), (0.18, 1.0, 2.64), "chrome")
    return finish(mb)


def vanity():
    """floating oak vanity 4 x 1.8 (top 2.9) with a vessel basin and a wall tap: hang it with its back on the wall"""
    mb = MB("H_Vanity", "Bath", 3.6)
    mb.boxr((-2.0, -0.9, 1.0), (2.0, 0.9, 2.62), "oak")
    mb.boxr((-2.05, -0.95, 2.6), (2.05, 0.9, 2.82), "quartz")
    for x0, x1 in ((-1.98, -0.01), (0.01, 1.98)):
        mb.boxr((x0 + 0.02, -0.98, 1.04), (x1 - 0.02, -0.86, 2.56), "oak")
    mb.boxr((-1.4, -1.0, 2.4), (1.4, -0.92, 2.48), "black_metal")
    mb.lathe([(0, 2.78), (0.55, 2.78), (0.85, 3.05), (0.92, 3.3), (0.86, 3.3), (0.8, 3.1), (0.5, 2.9), (0, 2.9)], 24, "ceramic", M=Matrix.Translation((0, -0.1, 0)))
    mb.tube([(0, 0.85, 3.9), (0, 0.4, 3.9), (0, 0.25, 3.8)], 0.06, "chrome", segs=8)
    mb.lathe([(0, 0), (0.15, 0), (0.15, 0.1), (0, 0.1)], 10, "chrome", M=Matrix.Translation((0, 0.9, 3.9)) @ ROT(90))
    return finish(mb)


def mirror():
    """rounded mirror 3 x 4 in a thin black frame; back at y = 0 (wall face)"""
    mb = MB("H_Mirror", "Bath", 4.0)
    ring = sq_ring(1.5, 2.0, 5.0, 32)
    inner = [(x * 0.94, y * 0.955) for x, y in ring]
    # frame = outer slab, glass = slightly smaller slab proud of it
    pts = [(x, z + 2.0) for x, z in ring]
    mb.prism(pts, "Y", -0.14, 0.0, "black_metal")
    pts2 = [(x, z + 2.0) for x, z in inner]
    mb.prism(pts2, "Y", -0.19, -0.1, "mirror")
    return finish(mb)


def shower_set():
    mb = MB("H_ShowerSet", "Bath", 7.2)
    mb.tube([(0, 0.0, 6.6), (0, -0.9, 6.6)], 0.06, "chrome", segs=8)
    mb.lathe([(0, 0), (0.55, 0), (0.55, 0.08), (0, 0.1)], 24, "chrome", M=Matrix.Translation((0, -1.05, 6.45)))
    mb.lathe([(0, 0), (0.25, 0), (0.25, 0.08), (0, 0.08)], 16, "chrome", M=Matrix.Translation((0, -0.06, 3.6)) @ ROT(90))
    mb.lathe([(0, 0), (0.06, 0), (0.06, 0.25), (0, 0.25)], 8, "chrome", M=Matrix.Translation((0, -0.1, 3.6)) @ ROT(90))
    return finish(mb)


def shower_glass():
    """frameless glass screen 3 x 6.6 x 0.1 (set Transparency 0.7 in Studio), standing on y = 0, black edge profile"""
    mb = MB("H_ShowerGlass", "Bath", 6.6)
    mb.boxr((-1.5, -0.05, 0.0), (1.5, 0.05, 6.6), "glass_dark")
    return finish(mb)


def shower_glass_profile():
    mb = MB("H_ShowerGlassProfile", "Bath", 6.6)
    mb.boxr((1.48, -0.1, 0.0), (1.62, 0.1, 6.6), "black_metal")
    return finish(mb)


def towel_rail():
    mb = MB("H_TowelRail", "Bath", 3.0)
    for x in (-1.0, 1.0):
        mb.tube([(x, 0.0, 2.6), (x, -0.35, 2.6)], 0.05, "chrome", segs=6)
    mb.tube([(-1.1, -0.35, 2.6), (1.1, -0.35, 2.6)], 0.06, "chrome", segs=6)
    mb.boxr((-0.8, -0.48, 1.4), (0.8, -0.38, 2.68), "towel")
    mb.boxr((-0.8, -0.32, 1.6), (0.8, -0.22, 2.68), "towel")
    mb.boxr((-0.8, -0.49, 2.6), (0.8, -0.21, 2.72), "towel")
    return finish(mb)


# =========================================================================================================== TALL COVER
def bookcase():
    """6 x 7.5 x 1.6 oak bookcase (tall cover), charcoal back panel, books and a vase"""
    mb = MB("H_Bookcase", "Storage", 7.5)
    mb.boxr((-3.0, -0.8, 0.0), (-2.78, 0.8, 7.5), "oak")
    mb.boxr((2.78, -0.8, 0.0), (3.0, 0.8, 7.5), "oak")
    mb.boxr((-2.82, -0.8, 7.28), (2.82, 0.8, 7.5), "oak")
    mb.boxr((-2.82, -0.72, 0.0), (2.82, 0.8, 0.5), "oak")
    mb.boxr((-2.82, 0.6, 0.45), (2.82, 0.8, 7.32), "lacquer_charcoal")
    shelves = [(0.5, 2.2), (2.35, 3.9), (4.05, 5.6), (5.75, 7.28)]
    for (z0, z1) in shelves[:-1]:
        mb.boxr((-2.82, -0.78, z1), (2.82, 0.64, z1 + 0.15), "oak")
    bk = ["book_navy", "book_cream", "book_rust", "book_slate", "book_char", "book_sage", "book_wine"]
    rng = random.Random(7)
    for si, (z0, z1) in enumerate(shelves):
        x = -2.78
        xend = 2.78
        gap = {0: (0.6, 1.9), 1: (-2.78, -1.4), 2: (0.9, 2.78), 3: (-0.6, 0.5)}[si]
        while x < xend - 0.2:
            if gap[0] <= x < gap[1]:
                x = gap[1]
                continue
            w = rng.uniform(0.16, 0.32)
            h = min(rng.uniform(0.95, 1.4), z1 - z0 - 0.08)
            d = rng.uniform(0.95, 1.15)
            if x + w > xend - 0.02:
                break
            lean = 0.0
            mb.boxr((x + 0.005, 0.62 - d, z0 - 0.03), (x + w - 0.005, 0.62, z0 + h), rng.choice(bk))
            x += w
        # decor in the gap
        g0, g1 = gap
        cx = (g0 + g1) / 2
        if si in (0, 2):
            mb.lathe([(0, z0 - 0.02), (0.22, z0 - 0.02), (0.38, z0 + 0.4), (0.3, z0 + 0.95), (0.14, z0 + 1.1), (0.18, z0 + 1.2), (0.12, z0 + 1.2), (0.0, z0 + 1.0)],
                     16, "ceramic", M=Matrix.Translation((cx, 0.0, 0)))
        else:   # a lying stack
            for j, k in enumerate(("book_slate", "book_cream", "book_char")):
                mb.boxr((cx - 0.55 + j * 0.03, -0.45, z0 - 0.03 + j * 0.18), (cx + 0.55 - j * 0.04, 0.5, z0 + 0.15 + j * 0.18), k)
    zstretch(mb, 7.5, 8.0)
    return finish(mb)


def wardrobe():
    mb = MB("H_Wardrobe", "Storage", 7.5)
    mb.boxr((-3.0, -1.1, 0.35), (3.0, 1.2, 7.5), "lacquer_greige")
    mb.boxr((-2.85, -0.9, 0), (2.85, 1.05, 0.4), "plinth")
    xs = [-2.98, -0.99, 0.99, 2.98]
    for i, (x0, x1) in enumerate(zip(xs, xs[1:])):
        mb.boxr((x0 + 0.02, -1.18, 0.42), (x1 - 0.02, -1.06, 7.46), "lacquer_greige")
        hx = x1 - 0.2 if i != 2 else x0 + 0.2
        mb.boxr((hx - 0.05, -1.3, 3.0), (hx + 0.05, -1.14, 5.2), "black_metal")
    zstretch(mb, 7.5, 8.0)
    return finish(mb)


def tall_cabinet():
    mb = MB("H_TallCabinet", "Storage", 7.0)
    mb.boxr((-1.5, -0.95, 0.35), (1.5, 1.0, 7.0), "lacquer_white")
    mb.boxr((-1.4, -0.8, 0), (1.4, 0.9, 0.4), "plinth")
    for z0, z1 in ((0.42, 3.9), (3.94, 6.96)):
        mb.boxr((-1.48, -1.02, z0 + 0.02), (1.48, -0.9, z1 - 0.02), "lacquer_white")
    mb.boxr((1.08, -1.12, 3.0), (1.2, -0.98, 4.8), "oak")
    zstretch(mb, 7.0, 8.0)
    return finish(mb)


# =========================================================================================================== DRESSING
def floor_lamp():
    body = MB("H_FloorLamp", "Decor", 6.0)
    body.lathe([(0, 0), (0.75, 0), (0.75, 0.1), (0.1, 0.14), (0.06, 5.0), (0, 5.0)], 20, "black_metal")
    shade = MB("H_FloorLamp_Shade", "Decor", 6.0)
    shade.lathe([(0, 4.75), (0.95, 4.75), (0.9, 6.0), (0, 6.0)], 24, "shade")
    return [finish(body), finish(shade)]


def table_lamp():
    body = MB("H_TableLamp", "Decor", 2.0)
    body.lathe([(0, 0), (0.3, 0), (0.42, 0.35), (0.38, 0.8), (0.12, 1.05), (0.05, 1.1), (0.05, 1.3), (0, 1.3)], 18, "ceramic")
    shade = MB("H_TableLamp_Shade", "Decor", 2.0)
    shade.lathe([(0, 1.2), (0.62, 1.2), (0.5, 2.0), (0, 2.0)], 20, "shade")
    return [finish(body), finish(shade)]


def pendant_lamp():
    """dome pendant on a 3-stud cord: top of the cord = origin (hang it from the ceiling)"""
    body = MB("H_PendantLamp", "Decor", 4.0)
    body.lathe([(0, -0.05), (0.2, -0.05), (0.2, 0.05), (0, 0.05)], 12, "black_metal")
    body.lathe([(0, -3.0), (0.03, -3.0), (0.03, -0.04), (0, -0.04)], 6, "black_metal")
    body.lathe([(0, -3.05), (0.12, -3.05), (0.18, -3.15), (0.85, -3.85), (0.9, -4.0), (0.84, -4.0), (0.8, -3.88), (0.16, -3.22), (0, -3.22)], 24, "black_metal")
    bulb = MB("H_PendantLamp_Bulb", "Decor", 4.0)
    bulb.lathe([(0, -3.2), (0.12, -3.24), (0.2, -3.45), (0.16, -3.62), (0, -3.66)], 12, "bulb")
    return [finish(body), finish(bulb)]


def tv():
    """65-inch-style flat TV 6.4 x 3.7 on two feet; the screen is its own mesh (H_TV_Screen) for a SurfaceGui / image"""
    body = MB("H_TV", "Decor", 4.0)
    body.boxr((-3.2, -0.02, 0.3), (3.2, 0.1, 4.0), "plastic_black")                 # back shell
    body.boxr((-3.2, -0.09, 0.3), (3.2, 0.0, 0.42), "plastic_black")                # bezel ring around the screen
    body.boxr((-3.2, -0.09, 3.88), (3.2, 0.0, 4.0), "plastic_black")
    body.boxr((-3.2, -0.09, 0.4), (-3.08, 0.0, 3.9), "plastic_black")
    body.boxr((3.08, -0.09, 0.4), (3.2, 0.0, 3.9), "plastic_black")
    body.boxr((-0.9, 0.05, 0.9), (0.9, 0.3, 3.0), "plastic_black")
    for sx in (-1, 1):
        body.boxr((sx * 2.6 - 0.08, -0.4, -0.04), (sx * 2.6 + 0.08, 0.35, 0.06), "black_metal")
        body.boxr((sx * 2.6 - 0.06, -0.05, 0.02), (sx * 2.6 + 0.06, 0.05, 0.35), "black_metal")
    screen = MB("H_TV_Screen", "Decor", 4.0)
    screen.boxr((-3.1, -0.075, 0.4), (3.1, -0.0, 3.9), "screen")                    # sits in the bezel hole, edges buried 0.02
    return [finish(body), finish(screen)]


def laptop():
    mb = MB("H_Laptop", "Decor", 1.0)
    rbox(mb, (-0.75, -0.5, 0), (0.75, 0.5, 0.06), "steel", r=0.02)
    mb.boxr((-0.62, -0.38, 0.055), (0.62, 0.05, 0.075), "plastic_black")
    xf(rbox(mb, (-0.75, -0.03, 0.0), (0.75, 0.02, 1.0), "steel", r=0.02), about((0, 0.47, 0.05), ROT(-18)) @ Matrix.Translation((0, 0.47, 0.03)))
    xf(mb.boxr((-0.68, -0.055, 0.06), (0.68, -0.025, 0.94), "screen"), about((0, 0.47, 0.05), ROT(-18)) @ Matrix.Translation((0, 0.47, 0.03)))
    return finish(mb)


def frame(name, w, h, img, frame_kind="black_metal"):
    """picture frame w x h (studs), 0.15 deep, back on y = 0 (the wall face), bottom at z = 0, art printed on canvas"""
    mb = MB(name, "Art", h)
    t = 0.14
    mb.boxr((-w / 2, -0.15, 0), (w / 2, 0.0, t), frame_kind)
    mb.boxr((-w / 2, -0.15, h - t), (w / 2, 0.0, h), frame_kind)
    mb.boxr((-w / 2, -0.15, t - 0.02), (-w / 2 + t, 0.0, h - t + 0.02), frame_kind)
    mb.boxr((w / 2 - t, -0.15, t - 0.02), (w / 2, 0.0, h - t + 0.02), frame_kind)
    mb.boxr((-w / 2 + t - 0.02, -0.08, t - 0.02), (w / 2 - t + 0.02, -0.01, h - t + 0.02), "canvas")
    side = min(w, h) - 2 * t - 0.25
    mb.decal(img, (0, -1, 0), (0, -0.08, h / 2), w - 2 * t - 0.3, h - 2 * t - 0.3, col=None, op=1.0, kinds=["canvas"], depth=0.05)
    return finish(mb)


def rug(name, w, d, img):
    mb = MB(name, "Art", 0.06)
    rbox(mb, (-w / 2, -d / 2, 0.0), (w / 2, d / 2, 0.06), "rug", r=0.03, segs=1)
    mb.decal(img, (0, 0, 1), (0, 0, 0.06), w, d, col=None, op=1.0, kinds=["rug"], depth=0.1)
    return finish(mb)


def plant_fiddle():
    """fiddle-leaf fig in a concrete pot, ~5.6 tall"""
    mb = MB("H_PlantFiddle", "Plants", 5.6)
    mb.lathe([(0, 0), (0.65, 0), (0.8, 1.5), (0.72, 1.5), (0.6, 1.35), (0, 1.35)], 20, "concrete_pot")
    mb.lathe([(0, 1.3), (0.7, 1.3), (0.7, 1.4), (0, 1.4)], 20, "soil")
    rng = random.Random(3)
    stems = [((0, 0, 1.35), (0.1, 0.05, 5.2)), ((0, 0, 1.35), (-0.5, 0.2, 4.4)), ((0, 0, 1.35), (0.45, -0.3, 3.9))]
    for a, b in stems:
        mb.tube([a, b], 0.05, "stem", segs=5)
        A, B = Vector(a), Vector(b)
        for i in range(9):
            t = 0.35 + 0.65 * i / 8
            p = A.lerp(B, t)
            ang = rng.uniform(0, 2 * math.pi)
            dirv = Vector((math.cos(ang), math.sin(ang), rng.uniform(0.1, 0.6)))
            leaf(mb, p, dirv, rng.uniform(0.75, 1.05), rng.uniform(0.5, 0.65), rng.choice(["leaf", "leaf_dark"]), droop=0.25, thick=0.025)
    return finish(mb)


def plant_snake():
    mb = MB("H_PlantSnake", "Plants", 3.0)
    mb.lathe([(0, 0), (0.45, 0), (0.5, 1.0), (0.44, 1.0), (0.4, 0.9), (0, 0.9)], 16, "terracotta")
    mb.lathe([(0, 0.85), (0.43, 0.85), (0.43, 0.94), (0, 0.94)], 16, "soil")
    rng = random.Random(5)
    for i in range(11):
        ang = 2 * math.pi * i / 11 + rng.uniform(-0.2, 0.2)
        r = rng.uniform(0.05, 0.25)
        base = (r * math.cos(ang), r * math.sin(ang), 0.9)
        dirv = Vector((0.18 * math.cos(ang), 0.18 * math.sin(ang), 1.0))
        leaf(mb, base, dirv, rng.uniform(1.2, 2.0), rng.uniform(0.22, 0.3), rng.choice(["leaf", "leaf_dark"]), droop=0.03, thick=0.03)
    return finish(mb)


def toys():
    blocks = MB("H_ToyBlocks", "Toys", 1.0)
    rng = random.Random(11)
    spots = [(0, 0, 0), (0.62, 0.05, 0), (0.3, 0.02, 0.55), (-0.5, 0.6, 0), (1.1, -0.6, 0)]
    for i, (x, y, z) in enumerate(spots):
        k = ["toy_red", "toy_blue", "toy_green", "toy_white", "toy_blue"][i]
        xf(blocks.boxr((-0.28, -0.28, 0), (0.28, 0.28, 0.56), k), Matrix.Translation((x, y, z)) @ ROT(rng.uniform(-30, 30), "Z"))
    ball = MB("H_ToyBall", "Toys", 1.2)
    ellipsoid(ball, (0, 0, 0.6), (0.6, 0.6, 0.6), "toy_red", segs=16, rings=10)
    car = MB("H_ToyCar", "Toys", 0.8)
    rbox(car, (-0.4, -0.75, 0.15), (0.4, 0.75, 0.48), "toy_blue", r=0.08)
    rbox(car, (-0.34, -0.3, 0.45), (0.34, 0.35, 0.78), "toy_white", r=0.08)
    for sx in (-1, 1):
        for sy in (-1, 1):
            car.lathe([(0, -0.08), (0.17, -0.08), (0.17, 0.08), (0, 0.08)], 12, "rubber", M=Matrix.Translation((sx * 0.4, sy * 0.48, 0.17)) @ ROT(90, "Y"))
    teddy = MB("H_Teddy", "Toys", 1.6)
    ellipsoid(teddy, (0, 0, 0.5), (0.42, 0.36, 0.5), "plush", segs=8, rings=4)
    ellipsoid(teddy, (0, 0, 1.18), (0.34, 0.32, 0.32), "plush", segs=8, rings=4)
    for sx in (-1, 1):
        ellipsoid(teddy, (sx * 0.24, 0.0, 1.45), (0.12, 0.08, 0.12), "plush", segs=8, rings=4)
        ellipsoid(teddy, (sx * 0.42, -0.12, 0.6), (0.14, 0.14, 0.3), "plush", segs=8, rings=4, M=ROT(sx * 25, "Y"))
        ellipsoid(teddy, (sx * 0.24, -0.3, 0.14), (0.16, 0.3, 0.14), "plush", segs=8, rings=4)
    ellipsoid(teddy, (0, -0.28, 1.12), (0.13, 0.1, 0.1), "fabric_cream", segs=8, rings=4)
    return [finish(blocks), finish(ball), finish(car), finish(teddy)]


def human():
    mb = MB("R15_Human_5stud", "None", 5.0)
    mb.boxr((-0.5, -0.25, 0.0), (-0.05, 0.25, 2.0), "fabric_charcoal"); mb.boxr((0.05, -0.25, 0.0), (0.5, 0.25, 2.0), "fabric_charcoal")
    mb.boxr((-0.75, -0.3, 2.0), (0.75, 0.3, 3.8), "fabric_slate")
    mb.boxr((-1.2, -0.25, 2.1), (-0.78, 0.25, 3.8), "fabric_slate"); mb.boxr((0.78, -0.25, 2.1), (1.2, 0.25, 3.8), "fabric_slate")
    mb.boxr((-0.4, -0.38, 3.82), (0.4, 0.38, 5.0), "lacquer_greige")
    return mb


# =========================================================================================================== custom pieces (layout v1)
def zstretch(mb, H0, H1):
    """raise a tall piece from H0 to exactly H1 (layout tall cover = 8.0): scale z of every vertex"""
    k = H1 / H0
    for v in mb.bm.verts:
        v.co.z *= k
    mb.height = H1
    return mb


BOOKK = ["book_navy", "book_cream", "book_rust", "book_slate", "book_char", "book_sage", "book_wine"]


def books_row(mb, x0, x1, z0, zmax, yback, depth, rng, facing=-1):
    """a row of upright books standing on z0, spines toward `facing` (-1 = -Y), back of the books at yback"""
    x = x0
    while x < x1 - 0.2:
        w = rng.uniform(0.16, 0.32)
        if x + w > x1 - 0.02:
            break
        h = min(rng.uniform(0.95, 1.45), zmax - z0 - 0.08)
        d = rng.uniform(0.85, 1.0) * depth
        ya, yb = (yback - d, yback) if facing < 0 else (yback, yback + d)
        mb.boxr((x + 0.005, ya, z0 - 0.03), (x + w - 0.005, yb, z0 + h), rng.choice(BOOKK))
        x += w


def shelf_wall():
    """12 x 2 x 8 open bookshelf wall, dressed on BOTH faces (team A's spawn wall). A solid charcoal spine down the middle
    keeps it full tall cover."""
    mb = MB("H_ShelfWall", "Storage2", 8.0)
    H = 8.0
    for (a, b) in ((-6.0, -5.78), (-2.21, -1.99), (1.99, 2.21), (5.78, 6.0)):
        mb.boxr((a, -1.0, 0.0), (b, 1.0, H), "oak")
    mb.boxr((-5.8, -1.0, 7.78), (5.8, 1.0, 8.0), "oak")
    mb.boxr((-5.8, -0.95, 0.0), (5.8, 0.95, 0.45), "plinth")
    mb.boxr((-5.82, -0.1, 0.4), (5.82, 0.1, 7.8), "lacquer_charcoal")          # the spine
    rng = random.Random(21)
    zs = [0.45, 2.3, 4.15, 6.0, 7.78]
    for z in zs[1:-1]:
        mb.boxr((-5.8, -1.0, z - 0.14), (5.8, 1.0, z), "oak")
    bays = [(-5.78, -2.21), (-1.99, 1.99), (2.21, 5.78)]
    for zi, (z0, z1) in enumerate(zip(zs, zs[1:])):
        for bi, (x0, x1) in enumerate(bays):
            for face in (-1, 1):
                k = (zi * 3 + bi + (face > 0)) % 4
                if k == 1:        # a vase and a lying stack in this bay
                    cx = (x0 + x1) / 2 + 0.6
                    cy = 0.55 * face
                    mb.lathe([(0, z0 - 0.02), (0.2, z0 - 0.02), (0.34, z0 + 0.4), (0.26, z0 + 0.9), (0.13, z0 + 1.05), (0.0, z0 + 1.0)],
                             14, rng.choice(["ceramic", "concrete_pot"]), M=Matrix.Translation((cx, cy, 0)))
                    for j, kk in enumerate(rng.sample(BOOKK, 2)):
                        mb.boxr((x0 + 0.1, cy - 0.38, z0 - 0.03 + j * 0.17), (x0 + 1.2, cy + 0.38, z0 + 0.14 + j * 0.17), kk)
                else:
                    books_row(mb, x0 + 0.02, (x1 - 0.02) if k != 3 else (x0 + x1) / 2, z0, z1 - 0.14, 0.12 * face, 0.85, rng, facing=face)
    return finish(mb)


def oven_wall():
    """12 x 2 x 8 tall kitchen bank, both faces finished: -Y = two built-in ovens + pantry doors, +Y = cupboard doors"""
    mb = MB("H_OvenWall", "Storage2", 8.0)
    mb.boxr((-6.0, -0.83, 0.38), (6.0, 0.83, 8.0), "lacquer_white")
    mb.boxr((-5.85, -0.7, 0.0), (5.85, 0.7, 0.42), "plinth")
    cols = [-6.0, -3.0, 0.0, 3.0, 6.0]
    for face in (-1, 1):
        yf0, yf1 = (-0.9, -0.81) if face < 0 else (0.81, 0.9)
        for i, (x0, x1) in enumerate(zip(cols, cols[1:])):
            if face < 0 and i == 1:        # oven column: drawer, two ovens, top door
                mb.boxr((x0 + 0.02, yf0, 0.44), (x1 - 0.02, yf1, 1.6), "lacquer_white")
                for (z0, z1) in ((1.65, 3.55), (3.6, 5.5)):
                    mb.boxr((x0 + 0.04, -0.9, z0), (x1 - 0.04, -0.81, z1), "steel")
                    mb.boxr((x0 + 0.25, -0.93, z0 + 0.25), (x1 - 0.25, -0.88, z1 - 0.55), "glass_dark")
                    mb.tube([(x0 + 0.35, -0.95, z1 - 0.28), (x1 - 0.35, -0.95, z1 - 0.28)], 0.045, "steel", segs=8)
                    mb.boxr((x0 + 0.33, -0.96, z1 - 0.33), (x0 + 0.41, -0.88, z1 - 0.23), "steel")
                    mb.boxr((x1 - 0.41, -0.96, z1 - 0.33), (x1 - 0.33, -0.88, z1 - 0.23), "steel")
                mb.boxr((x0 + 0.02, yf0, 5.55), (x1 - 0.02, yf1, 7.96), "lacquer_white")
                continue
            for (z0, z1) in ((0.44, 4.7), (4.74, 7.96)):
                mb.boxr((x0 + 0.02, yf0, z0), (x1 - 0.02, yf1, z1), "lacquer_white")
            hx = x1 - 0.25 if i % 2 == 0 else x0 + 0.25
            yh0, yh1 = (-0.99, -0.88) if face < 0 else (0.88, 0.99)
            mb.boxr((hx - 0.05, yh0, 3.6), (hx + 0.05, yh1, 5.8), "black_metal")
    return finish(mb)


def slat_screen():
    """6 x 2 x 8 timber slat screen: a low white storage base, oak slats on both faces of a solid oak core (tall cover)"""
    mb = MB("H_SlatScreen", "Storage2", 8.0)
    mb.boxr((-3.0, -0.96, 0.3), (3.0, 0.96, 2.4), "lacquer_white")
    mb.boxr((-2.9, -0.85, 0.0), (2.9, 0.85, 0.35), "plinth")
    mb.boxr((-3.0, -1.0, 2.38), (3.0, 1.0, 2.55), "oak")
    mb.boxr((-2.9, -0.15, 2.5), (2.9, 0.15, 7.9), "oak")
    n = 9
    for i in range(n):
        x = -2.8 + 5.6 * i / (n - 1)
        for face in (-1, 1):
            ya, yb = (-0.95, -0.12) if face < 0 else (0.12, 0.95)
            mb.boxr((x - 0.16, ya, 2.5), (x + 0.16, yb, 7.88), "oak_slat")
    mb.boxr((-3.0, -1.0, 7.85), (3.0, 1.0, 8.0), "oak")
    for x0 in (-2.95, 0.02):
        mb.boxr((x0, -1.02, 0.36), (x0 + 2.93, -0.94, 2.34), "lacquer_white")
        mb.boxr((x0, 0.94, 0.36), (x0 + 2.93, 1.02, 2.34), "lacquer_white")
    return finish(mb)


def headboard_wall():
    """14 x 1.5 x 8 freestanding headboard wall: upholstered channels on the bed side (-Y), walnut behind"""
    mb = MB("H_HeadboardWall", "Storage2", 8.0)
    mb.boxr((-7.0, -0.45, 0.0), (7.0, 0.75, 8.0), "walnut")
    n = 12
    for i in range(n):
        x0 = -6.6 + 13.2 * i / n
        rbox(mb, (x0 + 0.02, -0.75, 0.6), (x0 + 13.2 / n - 0.02, -0.35, 6.4), "fabric_slate", r=0.18, segs=2)
    mb.boxr((-6.6, -0.72, 0.0), (6.6, -0.4, 0.64), "walnut")
    return finish(mb)


def kitchen_bench():
    """banquette 10 long x 3.5 deep x 3.4 (low cover): white base, oak seat, cushions, oak back panel to exactly 3.4;
    seat faces -Y"""
    mb = MB("H_KitchenBench", "Storage2", 3.4)
    mb.boxr((-5.0, -1.55, 0.35), (5.0, 1.75, 1.45), "lacquer_white")
    mb.boxr((-4.9, -1.35, 0.0), (4.9, 1.6, 0.4), "plinth")
    mb.boxr((-5.0, -1.75, 1.4), (5.0, 1.75, 1.6), "oak")
    mb.boxr((-5.0, 1.1, 1.55), (5.0, 1.75, 3.4), "oak")
    rbox(mb, (-4.95, -1.7, 1.55), (4.95, 1.15, 1.95), "fabric_slate", r=0.15)
    for x0, x1 in ((-4.95, -1.7), (-1.65, 1.65), (1.7, 4.95)):
        xf(rbox(mb, (x0, 0.55, 1.9), (x1, 1.15, 3.2), "fabric_cream", r=0.2, segs=2), about((0, 0.85, 1.9), ROT(8)))
    return finish(mb)


def hall_bench(name, W):
    """hall bench W x 2 x 3.4: oak seat, white cubby base with baskets, slatted oak back to exactly 3.4; seat faces -Y"""
    mb = MB(name, "Storage2", 3.4)
    mb.boxr((-W / 2, -0.9, 0.3), (W / 2, 1.0, 1.5), "lacquer_white")
    mb.boxr((-W / 2 + 0.1, -0.8, 0.0), (W / 2 - 0.1, 0.9, 0.35), "plinth")
    mb.boxr((-W / 2, -1.0, 1.45), (W / 2, 1.0, 1.65), "oak")
    n = max(2, int(W / 1.6))
    for i in range(n):
        x0 = -W / 2 + 0.12 + (W - 0.24) * i / n
        x1 = x0 + (W - 0.24) / n - 0.12
        mb.boxr((x0, -1.0, 0.45), (x1, -0.55, 1.3), "plush" if i % 2 else "rug")       # baskets
    ns = max(3, int(W / 0.55))
    for i in range(ns):
        x = -W / 2 + 0.32 + (W - 0.64) * i / (ns - 1)
        mb.boxr((x - 0.1, 0.7, 1.6), (x + 0.1, 0.95, 3.25), "oak_slat")
    mb.boxr((-W / 2 + 0.15, 0.9, 1.6), (W / 2 - 0.15, 1.0, 3.25), "walnut")       # solid back board behind the slats
    mb.boxr((-W / 2, 0.65, 3.22), (W / 2, 1.0, 3.4), "oak")
    mb.boxr((-W / 2, 0.66, 1.6), (-W / 2 + 0.2, 0.99, 3.3), "oak"); mb.boxr((W / 2 - 0.2, 0.66, 1.6), (W / 2, 0.99, 3.3), "oak")
    return finish(mb)


def planter():
    """3 x 3 x 3.4 concrete planter box (low cover) + a fiddle-leaf tree above it as a separate art mesh"""
    mb = MB("H_Planter", "Plants", 3.4)
    mb.boxr((-1.5, -1.5, 0.0), (1.5, 1.5, 3.4), "concrete_pot")
    mb.boxr((-1.32, -1.32, 3.25), (1.32, 1.32, 3.38), "soil")
    tr = MB("H_Planter_Tree", "Plants", 9.0)
    rng = random.Random(8)
    tr.tube([(0, 0, 3.2), (0.1, 0.05, 6.0), (0.05, 0.1, 8.8)], 0.09, "stem", segs=6)
    for i in range(34):
        t = 0.3 + 0.7 * i / 33
        p = Vector((0.08 * t, 0.07 * t, 3.3 + 5.5 * t))
        ang = rng.uniform(0, 2 * math.pi)
        dirv = Vector((math.cos(ang), math.sin(ang), rng.uniform(0.0, 0.5)))
        leaf(tr, p, dirv, rng.uniform(0.9, 1.25), rng.uniform(0.6, 0.78), rng.choice(["leaf", "leaf_dark"]), droop=0.25, thick=0.025)
    return [finish(mb), finish(tr)]


def display_column():
    """3 x 3 x 8 column wrapped in walnut with a display niche on the -Y and +Y faces (a vase in each); solid core"""
    mb = MB("H_DisplayColumn", "Storage2", 8.0)
    mb.boxr((-1.5, -1.5, 0.0), (1.5, 1.5, 3.4), "walnut")
    mb.boxr((-1.5, -1.5, 6.0), (1.5, 1.5, 8.0), "walnut")
    mb.boxr((-1.5, -1.5, 3.35), (-1.0, 1.5, 6.05), "walnut")
    mb.boxr((1.0, -1.5, 3.35), (1.5, 1.5, 6.05), "walnut")
    mb.boxr((-1.02, -0.5, 3.35), (1.02, 0.5, 6.05), "lacquer_charcoal")
    for face in (-1, 1):
        mb.lathe([(0, 3.38), (0.18, 3.38), (0.3, 3.8), (0.22, 4.4), (0.1, 4.6), (0.0, 4.55)], 14, "ceramic",
                 M=Matrix.Translation((0.2 * face, 1.0 * face, 0)))
    return finish(mb)


# =========================================================================================================== assemblies
# name: parts [(master, (dx, dy, dz), rot_z_deg)], role, cover class, collision boxes [(lo, hi) Blender, rel. pivot]
LOW, TALL, NONE = "LOW 3.4", "TALL 8.0", "none (dressing)"
ASM = [
    ("H_Sofa_Sectional", [("H_Sofa_Sectional", (0, 0, 0), 0)], "living room sectional, back to the room", LOW,
     [((-6, -1.8, 0), (6, 1.8, 3.4)), ((2.2, -5.4, 0), (6, -1.8, 1.8))]),
    ("H_Armchair", [("H_Armchair", (0, 0, 0), 0)], "living room armchair", LOW, [((-2.1, -2.0, 0), (2.1, 2.0, 3.4))]),
    ("H_KitchenIsland", [("H_KitchenIsland", (0, 0, 0), 0)], "kitchen island, seating side +Y (Studio -Z)", LOW, [((-5, -2.3, 0), (5, 2.3, 3.4))]),
    ("H_DiningSet", [("H_DiningTable", (0, 0, 0), 0)] + [("H_DiningChair", (x, sy * 2.35, 0), 0 if sy > 0 else 180) for x in (-2.1, 0, 2.1) for sy in (-1, 1)],
     "dining table + 6 chairs pushed in; boxes: table 2.6 + a 3.4 box per chair row (union = 8 x 6.7)", LOW,
     [((-4.0, -2.0, 0), (4.0, 2.0, 2.6)), ((-3.05, -3.35, 0), (3.05, -1.4, 3.4)), ((-3.05, 1.4, 0), (3.05, 3.35, 3.4))]),
    ("H_DiningTable", [("H_DiningTable", (0, 0, 0), 0)], "dining table alone (top 2.6)", "low obstacle 2.6", [((-4, -2, 0), (4, 2, 2.6))]),
    ("H_DiningChair", [("H_DiningChair", (0, 0, 0), 0)], "dining chair alone", NONE, []),
    ("H_Bed_Double", [("H_Bed_Double", (0, 0, 0), 0)], "master bed, head at +Y (Studio -Z) against the wall", LOW,
     [((-3.85, 4.4, 0), (3.85, 5.0, 3.4)), ((-3.7, -5.0, 0), (3.7, 4.45, 2.4))]),
    ("H_Bed_Single", [("H_Bed_Single", (0, 0, 0), 0)], "kid's bed, head at +Y against the wall", LOW,
     [((-2.35, 3.75, 0), (2.35, 4.3, 3.4)), ((-2.2, -4.3, 0), (2.2, 3.8, 2.4))]),
    ("H_Dresser", [("H_Dresser", (0, 0, 0), 0)], "bedroom dresser", LOW, [((-3, -1.1, 0), (3, 1.1, 3.4))]),
    ("H_Bathtub", [("H_Bathtub", (0, 0, 0), 0)], "freestanding tub on a tiled plinth", LOW, [((-3.5, -1.8, 0), (3.5, 1.8, 3.4))]),
    ("H_TVConsole", [("H_TVConsole", (0, 0, 0), 0)], "media sideboard (the TV stands on it)", LOW, [((-4, -1.0, 0), (4, 1.0, 3.4))]),
    ("H_TVConsole_WithTV", [("H_TVConsole", (0, 0, 0), 0), ("H_TV", (0, 0.2, 3.4), 0), ("H_TV_Screen", (0, 0.2, 3.4), 0)],
     "media sideboard with the TV on it", LOW, [((-4, -1.0, 0), (4, 1.0, 3.4))]),
    ("H_KitchenBase", [("H_KitchenBase", (0, 0, 0), 0)], "kitchen wall-run base module 4 wide (tile them side by side)", LOW, [((-2, -1.25, 0), (2, 1.2, 3.4))]),
    ("H_KitchenSink", [("H_KitchenSink", (0, 0, 0), 0)], "kitchen base with sink and tap", LOW, [((-2, -1.25, 0), (2, 1.2, 3.4))]),
    ("H_KitchenHob", [("H_KitchenHob", (0, 0, 0), 0)], "kitchen base with hob and oven", LOW, [((-2, -1.25, 0), (2, 1.2, 3.4))]),
    ("H_Bookcase", [("H_Bookcase", (0, 0, 0), 0)], "living-room / study bookcase", TALL, [((-3, -0.8, 0), (3, 0.8, 8.0))]),
    ("H_Fridge", [("H_Fridge", (0, 0, 0), 0)], "French-door fridge", TALL, [((-1.8, -1.3, 0), (1.8, 1.3, 8.0))]),
    ("H_Wardrobe", [("H_Wardrobe", (0, 0, 0), 0)], "bedroom wardrobe", TALL, [((-3, -1.2, 0), (3, 1.2, 8.0))]),
    ("H_TallCabinet", [("H_TallCabinet", (0, 0, 0), 0)], "tall linen / hall cabinet", TALL, [((-1.5, -1.0, 0), (1.5, 1.0, 8.0))]),
    ("H_Pantry", [("H_Pantry", (0, 0, 0), 0)], "tall kitchen pantry", TALL, [((-2, -1.2, 0), (2, 1.2, 8.0))]),
    ("H_ShelfWall", [("H_ShelfWall", (0, 0, 0), 0)], "open bookshelf wall dressed on both faces (team A spawn wall)", TALL, [((-6, -1, 0), (6, 1, 8))]),
    ("H_OvenWall", [("H_OvenWall", (0, 0, 0), 0)], "tall oven + pantry bank, both faces finished (team B spawn wall); ovens on -Y", TALL, [((-6, -1, 0), (6, 1, 8))]),
    ("H_SlatScreen", [("H_SlatScreen", (0, 0, 0), 0)], "timber slat screen on a storage base (inside the hall arches)", TALL, [((-3, -1, 0), (3, 1, 8))]),
    ("H_HeadboardWall", [("H_HeadboardWall", (0, 0, 0), 0)], "freestanding headboard wall, upholstered side -Y (bed side)", TALL, [((-7, -0.75, 0), (7, 0.75, 8))]),
    ("H_KitchenBench", [("H_KitchenBench", (0, 0, 0), 0)], "kitchen banquette, seat faces -Y", LOW, [((-5, -1.75, 0), (5, 1.75, 3.4))]),
    ("H_HallBench_3", [("H_HallBench_3", (0, 0, 0), 0)], "hall bench 3.5 wide, seat faces -Y", LOW, [((-1.75, -1, 0), (1.75, 1, 3.4))]),
    ("H_HallBench_8", [("H_HallBench_8", (0, 0, 0), 0)], "hall / mudroom bench 8 wide, seat faces -Y", LOW, [((-4, -1, 0), (4, 1, 3.4))]),
    ("H_Planter", [("H_Planter", (0, 0, 0), 0), ("H_Planter_Tree", (0, 0, 0), 0)], "concrete planter (cover 3.4) + fiddle tree above as art (no collision)", LOW, [((-1.5, -1.5, 0), (1.5, 1.5, 3.4))]),
    ("H_DisplayColumn", [("H_DisplayColumn", (0, 0, 0), 0)], "column wrapped in walnut with display niches on -Y and +Y", TALL, [((-1.5, -1.5, 0), (1.5, 1.5, 8))]),
    # dressing
    ("H_KitchenUpper", [("H_KitchenUpper", (0, 0, 0), 0)], "wall cabinet, bottom 5.8 above the floor", NONE, []),
    ("H_RangeHood", [("H_RangeHood", (0, 0, 0), 0)], "hood over the hob, bottom 5.8 above the floor", NONE, []),
    ("H_BarStool", [("H_BarStool", (0, 0, 0), 0)], "island stool", NONE, []),
    ("H_Nightstand", [("H_Nightstand", (0, 0, 0), 0)], "bedside table", NONE, []),
    ("H_CoffeeTable", [("H_CoffeeTable", (0, 0, 0), 0)], "coffee table with books and a bowl", NONE, []),
    ("H_SideTable", [("H_SideTable", (0, 0, 0), 0)], "round side table", NONE, []),
    ("H_Desk", [("H_Desk", (0, 0, 0), 0)], "kid's / study desk", NONE, []),
    ("H_DeskChair", [("H_DeskChair", (0, 0, 0), 0)], "swivel desk chair", NONE, []),
    ("H_WashingMachine", [("H_WashingMachine", (0, 0, 0), 0)], "laundry / utility", NONE, []),
    ("H_FruitBowl", [("H_FruitBowl", (0, 0, 0), 0)], "fruit bowl for the island / counter", NONE, []),
    ("H_Microwave", [("H_Microwave", (0, 0, 0), 0)], "counter appliance", NONE, []),
    ("H_CoffeeMachine", [("H_CoffeeMachine", (0, 0, 0), 0)], "counter appliance", NONE, []),
    ("H_Kettle", [("H_Kettle", (0, 0, 0), 0)], "counter appliance", NONE, []),
    ("H_TV", [("H_TV", (0, 0, 0), 0), ("H_TV_Screen", (0, 0, 0), 0)], "flat TV on feet; screen is its own mesh", NONE, []),
    ("H_Laptop", [("H_Laptop", (0, 0, 0), 0)], "open laptop for the desk", NONE, []),
    ("H_FloorLamp", [("H_FloorLamp", (0, 0, 0), 0), ("H_FloorLamp_Shade", (0, 0, 0), 0)], "floor lamp; PointLight in the shade at z 5.3", NONE, []),
    ("H_TableLamp", [("H_TableLamp", (0, 0, 0), 0), ("H_TableLamp_Shade", (0, 0, 0), 0)], "bedside lamp; PointLight at z 1.6", NONE, []),
    ("H_PendantLamp", [("H_PendantLamp", (0, 0, 0), 0), ("H_PendantLamp_Bulb", (0, 0, 0), 0)], "pendant: origin = ceiling point, bulb 3.4 below (SpotLight down)", NONE, []),
    ("H_Frame_Abstract", [("H_Frame_Abstract", (0, 0, 0), 0)], "wall art 4 x 4", NONE, []),
    ("H_Frame_Landscape", [("H_Frame_Landscape", (0, 0, 0), 0)], "wall art 5.4 x 3.6", NONE, []),
    ("H_Frame_Botanical", [("H_Frame_Botanical", (0, 0, 0), 0)], "wall art 2.6 x 3.4", NONE, []),
    ("H_Frame_Geometric", [("H_Frame_Geometric", (0, 0, 0), 0)], "wall art 3 x 3", NONE, []),
    ("H_Rug_Living", [("H_Rug_Living", (0, 0, 0), 0)], "rug 12 x 8", NONE, []),
    ("H_Rug_Runner", [("H_Rug_Runner", (0, 0, 0), 0)], "runner 4 x 10", NONE, []),
    ("H_PlantFiddle", [("H_PlantFiddle", (0, 0, 0), 0)], "tall plant", NONE, []),
    ("H_PlantSnake", [("H_PlantSnake", (0, 0, 0), 0)], "small plant", NONE, []),
    ("H_Toilet", [("H_Toilet", (0, 0, 0), 0)], "toilet, back to the wall (+Y)", NONE, []),
    ("H_Vanity", [("H_Vanity", (0, 0, 0), 0)], "floating vanity: back on the wall at +Y 0.9", NONE, []),
    ("H_Mirror", [("H_Mirror", (0, 0, 0), 0)], "bathroom mirror, back on y = 0, hang bottom at 3.9", NONE, []),
    ("H_ShowerSet", [("H_ShowerSet", (0, 0, 0), 0)], "rain shower head + valve, back on y = 0", NONE, []),
    ("H_ShowerGlass", [("H_ShowerGlass", (0, 0, 0), 0), ("H_ShowerGlassProfile", (0, 0, 0), 0)], "glass screen (Transparency 0.7) + black wall profile", "glass: CanCollide on, box 3 x 6.6 x 0.1", []),
    ("H_TowelRail", [("H_TowelRail", (0, 0, 0), 0)], "towel rail with towels, back on y = 0", NONE, []),
    ("H_ToyBlocks", [("H_ToyBlocks", (0, 0, 0), 0)], "toy blocks", NONE, []),
    ("H_ToyBall", [("H_ToyBall", (0, 0, 0), 0)], "ball", NONE, []),
    ("H_ToyCar", [("H_ToyCar", (0, 0, 0), 0)], "toy car", NONE, []),
    ("H_Teddy", [("H_Teddy", (0, 0, 0), 0)], "teddy bear", NONE, []),
]


def layout(by_name):
    kitc = coll("Kit")
    placed, pivots, used = {}, {}, set()
    x = 0.0
    rowy = 0.0
    for name, parts, *_ in ASM:
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


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for d in (TEX, FBXD):
        os.makedirs(d, exist_ok=True)
    obs = [sofa_sectional(), armchair()]
    obs.append(bed("H_Bed_Double", 7.4, 10.0, "fabric_charcoal", "fabric_charcoal", "linen_grey", "linen_blue",
                   ["linen_white", "linen_white", "fabric_slate"]))
    obs.append(bed("H_Bed_Single", 4.4, 8.6, "oak", "oak", "linen_blue", "fabric_cream", ["linen_white"]))
    obs += [dresser(), nightstand(), tv_console(), coffee_table(), side_table(), desk(), desk_chair()]
    obs += [dining_table(), dining_chair(), bar_stool(), island(), fruit_bowl(), kitchen_base("plain"), kitchen_base("sink"), kitchen_base("hob"),
            kitchen_upper(), range_hood(), pantry()]
    obs += [fridge(), microwave(), coffee_machine(), kettle(), washing_machine()]
    obs += [bathtub(), toilet(), vanity(), mirror(), shower_set(), shower_glass(), shower_glass_profile(), towel_rail()]
    obs += [bookcase(), wardrobe(), tall_cabinet()]
    obs += floor_lamp() + table_lamp() + pendant_lamp() + tv() + [laptop()]
    obs += [frame("H_Frame_Abstract", 4.0, 4.0, "gen/art_abstract"), frame("H_Frame_Landscape", 5.4, 3.6, "gen/art_landscape", "oak"),
            frame("H_Frame_Botanical", 2.6, 3.4, "gen/art_botanical", "oak"), frame("H_Frame_Geometric", 3.0, 3.0, "gen/art_geometric")]
    obs += [rug("H_Rug_Living", 12.0, 8.0, "gen/rug_geo"), rug("H_Rug_Runner", 4.0, 10.0, "gen/rug_stripe")]
    obs += [plant_fiddle(), plant_snake()] + toys()
    obs += [shelf_wall(), oven_wall(), slat_screen(), headboard_wall(), kitchen_bench(), hall_bench("H_HallBench_3", 3.5),
            hall_bench("H_HallBench_8", 8.0), display_column()] + planter()
    by_name = {o.name: o for o in obs}
    x = 0.0
    for o in obs:   # spread the masters so AO bakes don't see neighbours
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
            groups.setdefault(o["atlas"], []).append(o)
        for atl, objs in groups.items():
            imgs = bake_atlas(atl, objs)
            finalize(objs, atlas_material(atl, imgs))
            atl_files[atl] = {p: f"tex/{PREFIX}{atl}_{p}.png" for p in imgs}
            bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    for o in obs:
        o.location = (0, 0, 0)
    placed, pivots = layout(by_name)
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
    manifest = []
    for name, parts, role, cover, boxes in ASM:
        objs = placed[name]
        piv = pivots[name]
        lo, hi = bbox(objs)
        e = dict(assembly=name, role=role, cover=cover, objects=[o.name for o in objs], fbx=f"fbx/{name}.fbx")
        if len(boxes) == 1 and name not in ("H_DiningSet",):   # footprint = the art's footprint (handles, fronts), height = the cover height
            (bl, bh) = boxes[0]
            boxes = [((lo.x - piv.x, lo.y - piv.y, bl[2]), (hi.x - piv.x, hi.y - piv.y, bh[2]))]
            if name in ("H_KitchenSink", "H_Bathtub", "H_TVConsole_WithTV", "H_Planter"):
                e["above_box"] = "thin tap / the TV stands above the 3.4 box: no collision needed"
        if boxes:   # pivot = bottom centre of the union of the collision boxes (= the layout's COLP box)
            ul = Vector([min(Vector(b[0])[i] for b in boxes) for i in range(3)]); uh = Vector([max(Vector(b[1])[i] for b in boxes) for i in range(3)])
            c = Vector(((ul.x + uh.x) / 2, (ul.y + uh.y) / 2, 0.0))
            if c.length > 1e-4:
                piv = piv + c
                pivots[name] = piv
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
        # cover art must stay inside its collision boxes' union bbox
        if boxes:
            ul = Vector([min(Vector(b[0])[i] for b in boxes) for i in range(3)]); uh = Vector([max(Vector(b[1])[i] for b in boxes) for i in range(3)])
            over = max(max((ul - (lo - piv))[i], ((hi - piv) - uh)[i]) for i in range(3 if "above_box" not in e else 2))
            e["art_outside_box"] = round(max(0.0, over), 3)
        manifest.append(e)
    allobjs = [o for objs in placed.values() for o in objs]
    if not NOBAKE:
        export_fbx(os.path.join(FBXD, "H_Furniture_kit.fbx"), allobjs + [cube, mk])
        for e in manifest:
            objs = placed[e["assembly"]]
            off = pivots[e["assembly"]]
            for o in objs:
                o.location -= off
            bpy.context.view_layer.update()
            export_fbx(os.path.join(FBXD, e["assembly"] + ".fbx"), objs)
            for o in objs:
                o.location += off
        bpy.context.view_layer.update()
    man = dict(note="Blender (x, y, z) -> Studio (-x, z, y). 1 unit = 1 stud. Pivot = bottom centre of the collision box (the per-assembly "
                    "FBX has it at the origin). Kit FBX has K_ScaleCube (10 studs) and K_Marker (long arm +X, upright +Z, short arm +Y). "
                    "Every visual mesh: CanCollide/CanQuery/CanTouch off; collision = the listed boxes as invisible Parts.",
               cover_heights=dict(low=3.4, tall="8.0 (the final layout boxes every tall piece at 8.0)", source="notes/warehouse_study/movement_configs.txt CoverConfig"),
               atlases=atl_files, assemblies=manifest, unique_tris=sum(tris(o) for o in obs))
    json.dump(man, open(os.path.join(ROOT, "house_furniture.json"), "w"), indent=1)
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    bpy.ops.file.make_paths_relative(); bpy.ops.wm.save_mainfile()
    log("DONE", len(allobjs), "objects;", man["unique_tris"], "unique tris")


main()
